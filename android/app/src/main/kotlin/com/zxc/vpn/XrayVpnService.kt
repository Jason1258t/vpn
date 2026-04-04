package com.zxc.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
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

class XrayVpnService : VpnService() {

    companion object {
        const val TAG = "XrayVpnService"
        const val ACTION_CONNECT = "com.zxc.vpn.CONNECT"
        const val ACTION_DISCONNECT = "com.zxc.vpn.DISCONNECT"
        const val ACTION_PING = "com.zxc.vpn.PING"
        const val EXTRA_CONFIG = "config_data"
        const val EXTRA_IS_URL = "is_url"

        const val BROADCAST_STATUS = "com.zxc.vpn.STATUS"
        const val EXTRA_STATUS = "status"

        const val STATUS_CONNECTING = "connecting"
        const val STATUS_CONNECTED = "connected"
        const val STATUS_DISCONNECTED = "disconnected"
        const val STATUS_ERROR = "error"

        private const val NOTIFICATION_CHANNEL_ID = "vpn_xray_channel"
        private const val NOTIFICATION_ID = 101

        // Синглтон для доступа к логике конфигов извне (для пинга)
        @JvmStatic
        var instance: XrayVpnService? = null
            private set

        /**
         * Статический метод пинга, вызываемый из VpnPlugin
         */
        fun calculatePing(context: Context, configData: String, isUrl: Boolean): Long {
            return try {
                // Пытаемся получить текущий инстанс или создаем временный для доступа к методам трансформации
                val service = instance ?: XrayVpnService()

                val finalJson = if (isUrl) {
                    service.buildConfigFromUrl(configData, 0)
                } else {
                    service.buildConfigFromJson(configData, 0)
                }

                if (finalJson.isEmpty()) return -1

                val pingRequest = JSONObject().apply {
                    put("datDir", context.filesDir.absolutePath)
                    put("configPath", "")
                    put("timeout", 5000)
                    put("url", "https://www.google.com/generate_204")
                    put("proxy", finalJson)
                }

                val requestB64 = Base64.encodeToString(pingRequest.toString().toByteArray(), Base64.NO_WRAP)
                val resultB64 = LibXray.ping(requestB64)

                val decodedResult = String(Base64.decode(resultB64, Base64.DEFAULT))
                val resultJson = JSONObject(decodedResult)

                if (resultJson.optBoolean("success")) {
                    resultJson.optLong("data", -1)
                } else {
                    -1
                }
            } catch (e: Exception) {
                Log.e("XrayPing", "Ping failed: ${e.message}")
                -1
            }
        }
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        instance = this

        val controller = object : DialerController {
            override fun protectFd(fd: Long): Boolean {
                return protect(fd.toInt())
            }
        }

        LibXray.registerDialerController(controller)
        LibXray.registerListenerController(controller)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        when (action) {
            ACTION_DISCONNECT -> stopTunnel()
            ACTION_CONNECT -> {
                val configData = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                val isUrl = intent.getBooleanExtra(EXTRA_IS_URL, false)

                startForeground(NOTIFICATION_ID, buildNotification("Установка соединения..."))
                broadcastStatus(STATUS_CONNECTING)

                Thread { executeConnection(configData, isUrl) }.start()
            }
        }
        return START_STICKY
    }

    private fun executeConnection(configData: String, isUrl: Boolean) {
        try {
            if (isRunning) {
                LibXray.stopXray()
                tunInterface?.close()
            }

            tunInterface = establishTunInterface() ?: throw Exception("Не удалось создать TUN интерфейс")

            val finalJsonConfig = if (isUrl) {
                buildConfigFromUrl(configData, tunInterface!!.fd)
            } else {
                buildConfigFromJson(configData, tunInterface!!.fd)
            }

            Log.w(TAG, "Конфигурация Xray: $finalJsonConfig")

            val requestB64 = LibXray.newXrayRunFromJSONRequest(
                filesDir.absolutePath,
                "",
                finalJsonConfig
            )

            val resultB64 = LibXray.runXrayFromJSON(requestB64)
            val resultDecoded = String(Base64.decode(resultB64, Base64.DEFAULT))
            val resultJson = JSONObject(resultDecoded)

            if (resultJson.optBoolean("success") && LibXray.getXrayState()) {
                isRunning = true
                broadcastStatus(STATUS_CONNECTED)
                updateNotification("VPN активен")
            } else {
                throw Exception("Ядро Xray отклонило конфигурацию: ${resultJson.optString("error")}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка при запуске туннеля", e)
            handleFatalError()
        }
    }

    private fun establishTunInterface(): ParcelFileDescriptor? {
        return Builder()
            .setSession("XrayVPN")
            .setMtu(1500)
            .addAddress("10.0.0.2", 32)
            .addAddress("fd00::2", 126)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .addDnsServer("8.8.8.8")
            .addDnsServer("2001:4860:4860::8888")
            .establish()
    }

    fun buildConfigFromUrl(url: String, fd: Int): String {
        val urlBase64 = Base64.encodeToString(url.toByteArray(), Base64.NO_WRAP)
        val responseB64 = LibXray.convertShareLinksToXrayJson(urlBase64)
        val decodedResponse = String(Base64.decode(responseB64, Base64.DEFAULT))

        val responseJson = JSONObject(decodedResponse)
        if (!responseJson.optBoolean("success")) {
            throw Exception("Ошибка конвертации ссылки в JSON")
        }

        val baseConfig = responseJson.getJSONObject("data")
        return injectTunAndRouting(baseConfig, fd)
    }

    fun buildConfigFromJson(rawJson: String, fd: Int): String {
        return injectTunAndRouting(JSONObject(rawJson), fd)
    }

    private fun injectTunAndRouting(config: JSONObject, fd: Int): String {
        val tunInbound = JSONObject().apply {
            put("protocol", "tun")
            put("tag", "tun-inbound")
            put("settings", JSONObject().apply {
                put("fd", fd)
                put("mtu", 1400)
            })
            put("sniffing", JSONObject().apply {
                put("enabled", true)
                put("destOverride", JSONArray(listOf("http", "tls", "quic")))
            })
        }

        val outboundsArray = config.optJSONArray("outbounds") ?: JSONArray()
        if (outboundsArray.length() > 0) {
            val proxy = outboundsArray.getJSONObject(0)
            proxy.put("tag", "proxy")
            proxy.remove("sendThrough")

            if (proxy.optString("protocol") == "vless") {
                val oldSettings = proxy.getJSONObject("settings")
                if (!oldSettings.has("vnext")) {
                    val user = JSONObject().apply {
                        put("id", oldSettings.optString("id"))
                        put("flow", oldSettings.optString("flow").ifEmpty { "xtls-rprx-vision" })
                        put("encryption", "none")
                        put("level", 0)
                    }
                    val server = JSONObject().apply {
                        put("address", oldSettings.optString("address"))
                        put("port", oldSettings.optInt("port"))
                        put("users", JSONArray().apply { put(user) })
                    }
                    proxy.put("settings", JSONObject().apply {
                        put("vnext", JSONArray().apply { put(server) })
                    })
                }
            }

            val streamSettings = proxy.optJSONObject("streamSettings")
            val oldReality = streamSettings?.optJSONObject("realitySettings")
            if (oldReality != null) {
                val pubKey = oldReality.optString("publicKey")
                    .ifEmpty { oldReality.optString("password") }
                    .ifEmpty { oldReality.optString("pbk") }
                val sni = oldReality.optString("serverName").ifEmpty { oldReality.optString("sni") }

                val cleanReality = JSONObject().apply {
                    put("show", false)
                    put("fingerprint", oldReality.optString("fingerprint").ifEmpty { "chrome" })
                    put("serverName", sni)
                    put("publicKey", pubKey)
                    put("shortId", oldReality.optString("shortId"))
                    put("spiderX", "/")
                }
                streamSettings.put("realitySettings", cleanReality)
                streamSettings.put("security", "reality")
            }
        }

        return JSONObject().apply {
            put("inbounds", JSONArray().apply { put(tunInbound) })
            put("outbounds", outboundsArray)
            put("routing", JSONObject().apply {
                put("domainStrategy", "AsIs")
                put("rules", JSONArray().apply {
                    put(JSONObject().apply {
                        put("type", "field")
                        put("inboundTag", JSONArray(listOf("tun-inbound")))
                        put("outboundTag", "proxy")
                    })
                })
            })
        }.toString()
    }

    private fun stopTunnel() {
        if (isRunning) {
            LibXray.stopXray()
            isRunning = false
        }
        tunInterface?.close()
        tunInterface = null
        broadcastStatus(STATUS_DISCONNECTED)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun handleFatalError() {
        stopTunnel()
        broadcastStatus(STATUS_ERROR)
    }

    private fun broadcastStatus(status: String) {
        LocalBroadcastManager.getInstance(this).sendBroadcast(
            Intent(BROADCAST_STATUS).putExtra(EXTRA_STATUS, status)
        )
    }

    private fun buildNotification(contentText: String): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, "Состояние VPN", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Защищенное соединение")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(contentText: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(contentText))
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}