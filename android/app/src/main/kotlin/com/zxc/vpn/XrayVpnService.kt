package com.zxc.vpn

import android.app.*
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
        const val EXTRA_STATUS = "status"

        const val STATUS_CONNECTING = "connecting"
        const val STATUS_CONNECTED = "connected"
        const val STATUS_DISCONNECTED = "disconnected"
        const val STATUS_ERROR = "error"

        private const val NOTIFICATION_CHANNEL_ID = "vpn_xray_channel"
        private const val NOTIFICATION_ID = 101
        private const val SOCKS_PORT = 10808

        @JvmStatic var instance: XrayVpnService? = null ; private set
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    val isServiceRunning get() = isRunning

    override fun onCreate() {
        super.onCreate()
        instance = this
        registerXrayDialer()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                startForegroundCompat(buildNotification("Установка соединения..."))
                broadcastStatus(STATUS_CONNECTING)
                Thread { executeConnection(config) }.start()
            }
            ACTION_DISCONNECT -> stopTunnel()
        }
        return START_STICKY
    }

    private fun executeConnection(configData: String) {
        try {
            if (isRunning) teardown()

            // 1. Добавляем системный inbound к конфигу из Dart
            val xrayConfig = finalizeConfig(configData)
            Log.d(TAG, "Final Xray Config: $xrayConfig")

            // 2. Запуск xray
            val requestB64 = LibXray.newXrayRunFromJSONRequest(filesDir.absolutePath, "", xrayConfig)
            val resultB64 = LibXray.runXrayFromJSON(requestB64)
            val resultJson = JSONObject(String(Base64.decode(resultB64, Base64.DEFAULT)))

            if (!resultJson.optBoolean("success") || !LibXray.getXrayState()) {
                throw Exception("Xray error: ${resultJson.optString("error")}")
            }

            // 3. TUN интерфейс
            tunInterface = establishTunInterface() ?: throw Exception("TUN failed")
            val fd = tunInterface!!.detachFd()

            // 4. tun2socks
            startTun2Socks(fd)

            isRunning = true
            broadcastStatus(STATUS_CONNECTED)
            updateNotification("VPN активен", true)
        } catch (e: Exception) {
            Log.e(TAG, "Connection failed", e)
            handleFatalError()
        }
    }

    private fun finalizeConfig(dartJson: String): String {
        val config = JSONObject(dartJson)
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
        return config.toString()
    }

    private fun establishTunInterface(): ParcelFileDescriptor? {
        return Builder()
            .setSession("XrayVPN")
            .setMtu(1500)
            .addAddress("10.0.0.2", 30)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .addDnsServer("1.1.1.1")
            .addDisallowedApplication(packageName)
            .establish()
    }

    private fun startTun2Socks(fd: Int) {
        val key = Key().apply {
            setDevice("fd://$fd")
            setProxy("socks5://127.0.0.1:$SOCKS_PORT")
            setLogLevel("warning")
            setMTU(1500L)
        }
        Thread { T2s.start(key) }.apply { isDaemon = true; start() }
    }

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

    private fun teardown() {
        if (isRunning) {
            isRunning = false
            try { T2s.stop() } catch (e: Exception) {}
            try { LibXray.stopXray() } catch (e: Exception) {}
        }
        tunInterface = null
    }

    private fun registerXrayDialer() {
        val controller = object : DialerController {
            override fun protectFd(fd: Long): Boolean = protect(fd.toInt())
        }
        LibXray.registerDialerController(controller)
        LibXray.registerListenerController(controller)
    }

    // --- Уведомления ---
    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else startForeground(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(text: String, showStopwatch: Boolean = false): Notification {
        val contentIntent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val disconnectPendingIntent = PendingIntent.getService(this, 1, Intent(this, XrayVpnService::class.java).apply { action = ACTION_DISCONNECT }, PendingIntent.FLAG_IMMUTABLE)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, "VPN статус", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Защищённое соединение").setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock).setOngoing(true)
            .setContentIntent(contentIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Отключить", disconnectPendingIntent)
            .setUsesChronometer(showStopwatch).build()
    }

    private fun updateNotification(text: String, stopwatch: Boolean = false) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION_ID, buildNotification(text, stopwatch))
    }

    private fun broadcastStatus(status: String) {
        LocalBroadcastManager.getInstance(this).sendBroadcast(Intent(BROADCAST_STATUS).putExtra(EXTRA_STATUS, status))
    }

    override fun onDestroy() { instance = null; super.onDestroy() }
}