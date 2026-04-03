package com.zxc.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Base64
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import libXray.LibXray
import org.json.JSONArray
import org.json.JSONObject
import libXray.DialerController

class XrayVpnService : VpnService() {

    companion object {
        const val TAG = "XrayVpnService"
        const val ACTION_CONNECT = "com.zxc.vpn.CONNECT"
        const val ACTION_CONNECT_URL = "com.zxc.vpn.CONNECT_URL"
        const val ACTION_DISCONNECT = "com.zxc.vpn.DISCONNECT"
        const val EXTRA_CONFIG = "config_json"
        const val EXTRA_URL = "config_url"

        const val BROADCAST_STATUS = "com.zxc.vpn.STATUS"
        const val EXTRA_STATUS = "status"
        const val STATUS_CONNECTING = "connecting"
        const val STATUS_CONNECTED = "connected"
        const val STATUS_DISCONNECTED = "disconnected"
        const val STATUS_ERROR = "error"

        private const val NOTIFICATION_CHANNEL_ID = "vpn_service"
        private const val NOTIFICATION_ID = 1
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        // Регистрируем контроллер для защиты сокетов Go-слоя от петли трафика
        val controller = object : DialerController {
            override fun protectFd(fd: Long): Boolean { // Обратите внимание на тип Long
                // В некоторых версиях gomobile int из Go превращается в Long в Kotlin
                return protect(fd.toInt())
            }
        }

        LibXray.registerDialerController(controller)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: return START_NOT_STICKY
                startTunnel(config)
            }
            ACTION_CONNECT_URL -> {
                val url = intent.getStringExtra(EXTRA_URL) ?: return START_NOT_STICKY
                startTunnelFromUrl(url)
            }
            ACTION_DISCONNECT -> stopTunnel()
        }
        return START_NOT_STICKY
    }

    private fun startTunnelFromUrl(url: String) {
        broadcastStatus(STATUS_CONNECTING)
        try {
            Log.w(TAG, "Starting tunnel from url")

            // 1. Создаем интерфейс сразу, чтобы получить FD
            tunInterface = buildTunInterface() ?: throw Exception("FD fail")

            // 2. Конвертируем ссылку через libXray
            val urlBase64 = Base64.encodeToString(url.toByteArray(), Base64.NO_WRAP)
            val responseB64 = LibXray.convertShareLinksToXrayJson(urlBase64)
            val decoded = String(Base64.decode(responseB64, Base64.DEFAULT))
            val jsonRes = JSONObject(decoded)

            if (!jsonRes.optBoolean("success")) throw Exception("Convert fail")

            val config = jsonRes.getJSONObject("data")

            // 3. Инъекция TUN настроек v26.1.23
            val tunInbound = JSONObject().apply {
                put("type", "tun")
                put("tag", "tun-in")
                put("fd", tunInterface!!.fd) // Прямая передача дескриптора в ядро
                put("sniffing", JSONObject().apply {
                    put("enabled", true)
                    put("destOverride", JSONArray(listOf("http", "tls", "quic")))
                })
            }
            config.put("inbounds", JSONArray(listOf(tunInbound)))

            // Добавляем mark для исключения исходящего трафика из VPN
            val outbounds = config.getJSONArray("outbounds")
            for (i in 0 until outbounds.length()) {
                val out = outbounds.getJSONObject(i)
                val ss = out.optJSONObject("streamSettings") ?: JSONObject()
                val so = ss.optJSONObject("sockopt") ?: JSONObject()
                so.put("mark", 255)
                ss.put("sockopt", so)
                out.put("streamSettings", ss)
            }

            Log.w(TAG, "got xray config from url: $config")
            startTunnel(config.toString(), alreadyHasTun = true)
        } catch (e: Exception) {
            Log.e(TAG, "URL Start error", e)
            fail()
        }
    }

    private fun startTunnel(configJson: String, alreadyHasTun: Boolean = false) {
        if (isRunning) stopTunnel()
        if (!alreadyHasTun) {
            broadcastStatus(STATUS_CONNECTING)
            tunInterface = buildTunInterface()
        }

        startForeground(NOTIFICATION_ID, buildNotification("Connecting..."))

        try {
            val request = LibXray.newXrayRunFromJSONRequest(filesDir.absolutePath, "", configJson)
            val resB64 = LibXray.runXrayFromJSON(request)
            val resDecoded = String(Base64.decode(resB64, Base64.DEFAULT))

            if (JSONObject(resDecoded).optBoolean("success") && LibXray.getXrayState()) {
                isRunning = true
                broadcastStatus(STATUS_CONNECTED)
                updateNotification("Connected")
            } else {
                fail()
            }
        } catch (e: Exception) {
            fail()
        }
    }

    private fun buildTunInterface(): ParcelFileDescriptor? = Builder()
        .setSession("Xray VPN")
        .addAddress("10.0.0.1", 32)
        .addRoute("0.0.0.0", 0)
        .addDnsServer("8.8.8.8")
        .addDisallowedApplication(packageName)
        .establish()

    private fun stopTunnel() {
        LibXray.stopXray()
        tunInterface?.close()
        tunInterface = null
        isRunning = false
        broadcastStatus(STATUS_DISCONNECTED)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun fail() {
        stopTunnel()
        broadcastStatus(STATUS_ERROR)
    }

    private fun broadcastStatus(status: String) {
        LocalBroadcastManager.getInstance(this)
            .sendBroadcast(Intent(BROADCAST_STATUS).putExtra(EXTRA_STATUS, status))
    }

    private fun buildNotification(text: String): Notification {
        ensureNotificationChannel()
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Xray VPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(NOTIFICATION_CHANNEL_ID, "VPN", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        }
    }

    private fun updateNotification(text: String) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(NOTIFICATION_ID, buildNotification(text))
    }
}