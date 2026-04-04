package com.zxc.vpn

import android.app.Notification
import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import libXray.DialerController
import libXray.LibXray
import org.json.JSONArray
import org.json.JSONObject
import t2s.Key
import t2s.T2s

class XrayVpnService : VpnService() {

    companion object {
        const val TAG = "XrayVpnService"

        const val ACTION_CONNECT = "com.zxc.vpn.CONNECT"
        const val ACTION_DISCONNECT = "com.zxc.vpn.DISCONNECT"

        const val BROADCAST_STATUS = "com.zxc.vpn.STATUS"
        const val EXTRA_CONFIG = "config_data"
        const val EXTRA_IS_URL = "is_url"
        const val EXTRA_STATUS = "status"

        const val STATUS_CONNECTING = "connecting"
        const val STATUS_CONNECTED = "connected"
        const val STATUS_DISCONNECTED = "disconnected"
        const val STATUS_ERROR = "error"

        private const val NOTIFICATION_CHANNEL_ID = "vpn_xray_channel"
        private const val NOTIFICATION_ID = 101
        private const val SOCKS_PORT = 10808

        @JvmStatic
        var instance: XrayVpnService? = null
            private set
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    // ── lifecycle ────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        instance = this
        registerXrayDialer()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                val isUrl = intent.getBooleanExtra(EXTRA_IS_URL, false)
                startForegroundCompat(buildNotification("Установка соединения..."))
                broadcastStatus(STATUS_CONNECTING)
                Thread { executeConnection(config, isUrl) }.start()
            }
            ACTION_DISCONNECT -> stopTunnel()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }


    // ── connection ───────────────────────────────────────────────────────────

    private fun executeConnection(configData: String, isUrl: Boolean) {
        try {
            // Останавливаем предыдущую сессию если она была
            if (isRunning) teardown()

            // 1. Собираем конфиг xray с socks inbound
            val xrayConfig = if (isUrl) buildXrayConfigFromUrl(configData)
            else buildXrayConfigFromJson(configData)
            Log.w(TAG, "Xray config: $xrayConfig")

            // 2. Запускаем xray — он начнёт слушать SOCKS на 127.0.0.1:SOCKS_PORT
            val requestB64 = LibXray.newXrayRunFromJSONRequest(
                filesDir.absolutePath, "", xrayConfig
            )
            val resultB64 = LibXray.runXrayFromJSON(requestB64)
            val resultDecoded = String(Base64.decode(resultB64, Base64.DEFAULT))
            val resultJson = JSONObject(resultDecoded)
            Log.d(TAG, "Xray result: $resultDecoded")

            if (!resultJson.optBoolean("success") || !LibXray.getXrayState()) {
                throw Exception("Xray rejected config: ${resultJson.optString("error")}")
            }

            // 3. Создаём TUN интерфейс — после этого Android рисует VPN-иконку
            tunInterface = establishTunInterface()
                ?: throw Exception("Failed to establish TUN interface")
            val fd = tunInterface!!.detachFd()
            Log.d(TAG, "TUN fd: ${fd}")

            // 4. tun2socks читает IP-пакеты из TUN fd и проксирует через xray SOCKS
            startTun2Socks(fd)

            isRunning = true
            broadcastStatus(STATUS_CONNECTED)
            updateNotification("VPN активен", true)

        } catch (e: Exception) {
            Log.e(TAG, "Connection failed: ${e.message}", e)
            handleFatalError()
        }
    }

    // ── tun ──────────────────────────────────────────────────────────────────

    private fun establishTunInterface(): ParcelFileDescriptor? {
        return Builder()
            .setSession("XrayVPN")
            .setMtu(1500)
            .addAddress("10.0.0.2", 30)
            .addRoute("0.0.0.0", 0)       // весь IPv4 через тоннель
            .addRoute("::", 0)             // весь IPv6 через тоннель
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
            // Само приложение выводим из тоннеля —
            // иначе SOCKS-трафик xray попадёт обратно в TUN → петля
            .addDisallowedApplication(packageName)
            .establish()
    }

    // ── tun2socks ────────────────────────────────────────────────────────────

    private fun startTun2Socks(fd: Int) {
        // protect() нужен чтобы tun2socks→xray соединения
        // шли через физический интерфейс, а не обратно в TUN
//        protect(fd)

        val key = Key().apply {
            setDevice("fd://$fd")
            setProxy("socks5://127.0.0.1:$SOCKS_PORT")
            setLogLevel("warning")
            setMTU(1500L)
        }

        // start() блокирующий — запускаем в отдельном потоке
        Thread {
            T2s.start(key)
        }.apply {
            name = "tun2socks"
            isDaemon = true
            start()
        }
    }

    private fun stopTun2Socks() {
        try {
            T2s.stop()
        } catch (e: Exception) {
            Log.w(TAG, "tun2socks stop error: ${e.message}")
        }
    }

    // ── xray config builders ─────────────────────────────────────────────────

    private fun buildXrayConfigFromUrl(url: String): String {
        val urlB64 = Base64.encodeToString(url.toByteArray(), Base64.NO_WRAP)
        val responseB64 = LibXray.convertShareLinksToXrayJson(urlB64)
        val decoded = String(Base64.decode(responseB64, Base64.DEFAULT))
        val response = JSONObject(decoded)

        if (!response.optBoolean("success")) {
            throw Exception("Link conversion failed: ${response.optString("error")}")
        }

        return injectSocksInbound(response.getJSONObject("data"))
    }

    private fun buildXrayConfigFromJson(rawJson: String): String {
        return injectSocksInbound(JSONObject(rawJson))
    }

    /**
     * Заменяет inbounds на socks для tun2socks, чистит outbound от мусора
     * который генерирует convertShareLinksToXrayJson, фиксирует vnext/reality.
     */
    private fun injectSocksInbound(config: JSONObject): String {
        // Socks inbound — точка входа для tun2socks
        val socksInbound = JSONObject().apply {
            put("tag", "socks-in")
            put("protocol", "socks")
            put("listen", "127.0.0.1")
            put("port", SOCKS_PORT)
            put("settings", JSONObject().apply {
                put("auth", "noauth")
                put("udp", true)
            })
            put("sniffing", JSONObject().apply {
                put("enabled", true)
                put("destOverride", JSONArray(listOf("http", "tls", "quic")))
            })
        }
        config.put("inbounds", JSONArray().apply { put(socksInbound) })

        val outbounds = config.optJSONArray("outbounds") ?: JSONArray()

        // Чистим первый outbound (proxy)
        if (outbounds.length() > 0) {
            val proxy = outbounds.getJSONObject(0)

            // Фиксируем tag и убираем мусорные поля
            proxy.put("tag", "proxy")
            proxy.remove("sendThrough")

            // Фикс vnext: null — optJSONArray вернёт null и если поля нет,
            // и если оно явно null, в отличие от has()
            if (proxy.optString("protocol") == "vless") {
                val settings = proxy.optJSONObject("settings") ?: JSONObject()
                if (settings.optJSONArray("vnext") == null) {
                    val user = JSONObject().apply {
                        put("id", settings.optString("id"))
                        put("flow", settings.optString("flow").ifEmpty { "xtls-rprx-vision" })
                        put("encryption", "none")
                        put("level", 0)
                    }
                    val server = JSONObject().apply {
                        put("address", settings.optString("address"))
                        put("port", settings.optInt("port"))
                        put("users", JSONArray().apply { put(user) })
                    }
                    proxy.put("settings", JSONObject().apply {
                        put("vnext", JSONArray().apply { put(server) })
                    })
                }
            }

            // Чистим realitySettings — убираем серверные поля, оставляем клиентские
            val streamSettings = proxy.optJSONObject("streamSettings")
            val oldReality = streamSettings?.optJSONObject("realitySettings")
            if (oldReality != null) {
                val pubKey = oldReality.optString("publicKey")
                    .ifEmpty { oldReality.optString("password") }
                    .ifEmpty { oldReality.optString("pbk") }
                val sni = oldReality.optString("serverName")
                    .ifEmpty { oldReality.optString("sni") }

                streamSettings.put("realitySettings", JSONObject().apply {
                    put("show", false)
                    put("fingerprint", oldReality.optString("fingerprint").ifEmpty { "chrome" })
                    put("serverName", sni)
                    put("publicKey", pubKey)
                    put("shortId", oldReality.optString("shortId"))
                    put("spiderX", "/")
                })
                streamSettings.put("security", "reality")
            }
        }

        // Гарантируем наличие freedom и blackhole
        val existingTags = (0 until outbounds.length())
            .map { outbounds.getJSONObject(it).optString("tag") }
            .toSet()

        if ("direct" !in existingTags) {
            outbounds.put(JSONObject().apply {
                put("tag", "direct")
                put("protocol", "freedom")
                put("settings", JSONObject())
            })
        }
        if ("block" !in existingTags) {
            outbounds.put(JSONObject().apply {
                put("tag", "block")
                put("protocol", "blackhole")
                put("settings", JSONObject())
            })
        }
        config.put("outbounds", outbounds)

        config.put("routing", JSONObject().apply {
            put("domainStrategy", "IPIfNonMatch")
            put("rules", JSONArray())
        })
        config.put("log", JSONObject().apply { put("loglevel", "warning") })

        // Убираем null-поля которые xray не понимает
        listOf("dns", "transport", "policy", "api", "metrics", "stats",
            "reverse", "fakeDns", "observatory", "burstObservatory", "version")
            .forEach { config.remove(it) }

        return config.toString()
    }

    // ── stop / error ─────────────────────────────────────────────────────────

    private fun stopTunnel() {
        teardown()
        broadcastStatus(STATUS_DISCONNECTED)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun handleFatalError() {
        teardown()
        broadcastStatus(STATUS_ERROR)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /** Останавливает xray и tun2socks, закрывает TUN fd. */
    private fun teardown() {
        if (isRunning) {
            isRunning = false
            // 1. Сначала останавливаем tun2socks.
            // engine.go сам вызовет Close() для дескриптора.
            stopTun2Socks()

            // 2. Останавливаем Xray
            try { LibXray.stopXray() } catch (e: Exception) { }
        }
        // tunInterface.close() вызывать не нужно, если был сделан detachFd
        tunInterface = null
    }

    // ── xray dialer protection ────────────────────────────────────────────────

    /**
     * Регистрируем protect() для xray — без этого исходящие соединения xray
     * пойдут обратно в TUN и создадут петлю.
     */
    private fun registerXrayDialer() {
        val controller = object : DialerController {
            override fun protectFd(fd: Long): Boolean = protect(fd.toInt())
        }
        LibXray.registerDialerController(controller)
        LibXray.registerListenerController(controller)
    }

    // ── notification ─────────────────────────────────────────────────────────

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(text: String, showStopwatch: Boolean = false): Notification {
        // 1. Намерение для открытия приложения
        // Мы создаем Intent, который указывает на твой MainActivity
        val contentIntent = Intent(this, MainActivity::class.java).let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        // 2. Намерение для кнопки "Отключить"
        // Мы шлем ACTION_DISCONNECT в этот же сервис
        val disconnectIntent = Intent(this, XrayVpnService::class.java).apply {
            action = ACTION_DISCONNECT
        }
        val disconnectPendingIntent = PendingIntent.getService(
            this, 1, disconnectIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Создаем канал (для Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID, "VPN статус",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false) // Убираем точку на иконке приложения
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Защищённое соединение")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true) // Нельзя смахнуть
            .setOnlyAlertOnce(true)
            .setContentIntent(contentIntent) // Клик по уведомлению -> Открыть приложение
            .setAutoCancel(false)

        // Добавляем кнопку "Отключить"
        // android.R.drawable.ic_menu_close_clear_cancel - системная иконка крестика
        builder.addAction(
            android.R.drawable.ic_menu_close_clear_cancel,
            "Отключить",
            disconnectPendingIntent
        )

        if (showStopwatch) {
            builder.setUsesChronometer(true)
            builder.setWhen(System.currentTimeMillis())
        }

        return builder.build()
    }

    private fun updateNotification(text: String, stopwatch: Boolean = false) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification(text, stopwatch))
    }

    private fun broadcastStatus(status: String) {
        LocalBroadcastManager.getInstance(this).sendBroadcast(
            Intent(BROADCAST_STATUS).putExtra(EXTRA_STATUS, status)
        )
    }
}