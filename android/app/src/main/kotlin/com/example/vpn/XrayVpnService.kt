package com.zxc.vpn

import android.util.Base64
import org.json.JSONObject

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import libXray.LibXray

class XrayVpnService : VpnService() {

    companion object {
        const val TAG = "XrayVpnService"

        const val ACTION_CONNECT = "com.zxc.vpn.CONNECT"
        const val ACTION_DISCONNECT = "com.zxc.vpn.DISCONNECT"
        const val EXTRA_CONFIG = "config_json"

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

    // ── lifecycle ─────────────────────────────────────────────────────────────

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val configJson = intent.getStringExtra(EXTRA_CONFIG) ?: run {
                    Log.e(TAG, "No config JSON in Intent")
                    broadcastStatus(STATUS_DISCONNECTED)
                    stopSelf()
                    return START_NOT_STICKY
                }
                startTunnel(configJson)
            }

            ACTION_DISCONNECT -> stopTunnel()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    // ── tunnel ────────────────────────────────────────────────────────────────

    private fun startTunnel(configJson: String) {
        if (isRunning) stopTunnel()

        broadcastStatus(STATUS_CONNECTING)
        startForeground(NOTIFICATION_ID, buildNotification("Connecting…"))

        try {
            tunInterface = buildTunInterface() ?: throw Exception("Failed to establish TUN")

            // Подготовка запроса
            val requestJson = LibXray.newXrayRunFromJSONRequest(
                filesDir.absolutePath,
                "",
                configJson
            )

            val rawResponse = LibXray.runXrayFromJSON(requestJson)

            // ВАЖНО: Декодируем ответ всегда, если он не пустой
            val isSuccess = if (!rawResponse.isNullOrEmpty()) {
                val decoded = String(Base64.decode(rawResponse, Base64.DEFAULT), Charsets.UTF_8)
                JSONObject(decoded).optBoolean("success", false)
            } else {
                false
            }

            if (!isSuccess) {
                Log.e(TAG, "LibXray failed to start (check config or logs)")
                fail()
                return
            }

            isRunning = true
            broadcastStatus(STATUS_CONNECTED)
            updateNotification("Connected")

        } catch (e: Exception) {
            Log.e(TAG, "Critical start error", e)
            fail()
        }
    }

    private fun stopTunnel() {
        if (!isRunning && tunInterface == null) return

        try {
            val error = LibXray.stopXray()
            if (!error.isNullOrEmpty()) {
                Log.w(TAG, "stopXray: $error")
            }
        } catch (e: Exception) {
            Log.w(TAG, "stopXray exception (ignored)", e)
        }

        tunInterface?.close()
        tunInterface = null
        isRunning = false

        broadcastStatus(STATUS_DISCONNECTED)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.d(TAG, "Tunnel stopped")
    }

    private fun fail() {
        tunInterface?.close()
        tunInterface = null
        broadcastStatus(STATUS_ERROR)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ── TUN interface ─────────────────────────────────────────────────────────

    private fun buildTunInterface(): ParcelFileDescriptor? =
        Builder()
            .setSession("Xray VPN")
            .addAddress("10.0.0.1", 32)
            .addAddress("fd00::1", 128)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .addDnsServer("8.8.8.8")
            .addDnsServer("8.8.4.4")
            .setMtu(1500)
            .addDisallowedApplication(packageName)
            .establish()

    // ── status broadcast ──────────────────────────────────────────────────────

    private fun broadcastStatus(status: String) {
        LocalBroadcastManager.getInstance(this)
            .sendBroadcast(Intent(BROADCAST_STATUS).putExtra(EXTRA_STATUS, status))
    }

    // ── notification ──────────────────────────────────────────────────────────

    private fun buildNotification(text: String): Notification {
        ensureNotificationChannel()
        val pi = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("VPN")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW,
            )
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }
}