package com.zxc.vpn

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import libXray.LibXray
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import android.util.Base64

class VpnPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val TAG = "VpnPlugin"
        private const val VPN_PERMISSION_REQUEST = 7890
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingConfigJson: String? = null

    // ── FlutterPlugin ─────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_service")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_status")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        context = null
    }

    // ── ActivityAware ─────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() { activity = null }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    // ── MethodChannel ─────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val configJson = call.argument<String>("config")
                    ?: return result.error("INVALID_ARG", "Missing 'config'", null)
                handleConnect(configJson, result)
            }
            "disconnect" -> {
                handleDisconnect()
                result.success(null)
            }
            "ping" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("INVALID_ARG", "Missing 'url'", null)
                handlePing(url, result)
            }
            else -> result.notImplemented()
        }
    }

    // ── connect ───────────────────────────────────────────────────────────────

    private fun handleConnect(configJson: String, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("NO_CONTEXT", "Plugin not attached", null)
        val permissionIntent = VpnService.prepare(ctx)
        if (permissionIntent != null) {
            pendingConfigJson = configJson
            activity?.startActivityForResult(permissionIntent, VPN_PERMISSION_REQUEST)
                ?: result.error("NO_ACTIVITY", "No activity for VPN dialog", null)
        } else {
            startService(ctx, configJson)
        }
        result.success(null)
    }

    private fun handleDisconnect() {
        context?.startService(
            Intent(context, XrayVpnService::class.java)
                .setAction(XrayVpnService.ACTION_DISCONNECT)
        )
    }

    // ── ping via LibXray.ping ─────────────────────────────────────────────────
    //
    // LibXray.ping(String) принимает JSON-строку и возвращает JSON-строку.
    // Формат входа:  {"url":"https://address:port","timeout":5000}
    // Формат выхода: {"delay":123}  или  {"error":"..."}

    private fun handlePing(configJson: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // LibXray.ping обычно ожидает структуру, содержащую конфиг и параметры теста
                val request = JSONObject().apply {
                    put("datDir", context?.filesDir?.absolutePath)
                    put("config", configJson) // Сама VLESS ссылка или JSON
                    put("timeout", 5)          // В секундах, как в Go коде
                    put("url", "https://www.google.com")
                }

                val responseBase64 = LibXray.ping(request.toString())

                // Декодируем ответ, так как либа все шлет в Base64
                val decodedBytes = Base64.decode(responseBase64, Base64.DEFAULT)
                val jsonResponse = JSONObject(String(decodedBytes, Charsets.UTF_8))

                if (jsonResponse.optBoolean("success", false)) {
                    val delay = jsonResponse.optLong("delay", -1L)
                    launch(Dispatchers.Main) { result.success(delay.toString()) }
                } else {
                    launch(Dispatchers.Main) { result.success("-1") }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Ping failed", e)
                launch(Dispatchers.Main) { result.success("-1") }
            }
        }
    }

    // ── ActivityResult (VPN permission) ───────────────────────────────────────

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != VPN_PERMISSION_REQUEST) return false
        val configJson = pendingConfigJson.also { pendingConfigJson = null }
        if (resultCode == Activity.RESULT_OK && configJson != null) {
            context?.let { startService(it, configJson) }
        } else {
            Log.w(TAG, "VPN permission denied")
            eventSink?.success(XrayVpnService.STATUS_DISCONNECTED)
        }
        return true
    }

    private fun startService(ctx: Context, configJson: String) {
        ctx.startService(
            Intent(ctx, XrayVpnService::class.java)
                .setAction(XrayVpnService.ACTION_CONNECT)
                .putExtra(XrayVpnService.EXTRA_CONFIG, configJson)
        )
    }

    // ── EventChannel ──────────────────────────────────────────────────────────

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val status = intent?.getStringExtra(XrayVpnService.EXTRA_STATUS) ?: return
            Log.d(TAG, "Status: $status")
            eventSink?.success(status)
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        eventSink = sink
        context?.let {
            LocalBroadcastManager.getInstance(it)
                .registerReceiver(statusReceiver, IntentFilter(XrayVpnService.BROADCAST_STATUS))
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        context?.let {
            LocalBroadcastManager.getInstance(it).unregisterReceiver(statusReceiver)
        }
    }
}