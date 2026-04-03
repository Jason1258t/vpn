package com.zxc.vpn

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware, PluginRegistry.ActivityResultListener {

    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingConfig: String? = null
    private var isUrlMode: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        MethodChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_service").setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_status").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val config = call.argument<String>("config") ?: return result.error("ERR", "No config", null)
                isUrlMode = config.startsWith("vless://") || config.startsWith("vmess://") || config.startsWith("ss://")
                handleConnect(config, result)
            }
            "disconnect" -> {
                context?.startService(Intent(context, XrayVpnService::class.java).setAction(XrayVpnService.ACTION_DISCONNECT))
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleConnect(config: String, result: MethodChannel.Result) {
        val intent = VpnService.prepare(context)
        if (intent != null) {
            pendingConfig = config
            activity?.startActivityForResult(intent, 7890)
        } else {
            executeStart(config)
        }
        result.success(null)
    }

    private fun executeStart(config: String) {
        val action = if (isUrlMode) XrayVpnService.ACTION_CONNECT_URL else XrayVpnService.ACTION_CONNECT
        val extra = if (isUrlMode) XrayVpnService.EXTRA_URL else XrayVpnService.EXTRA_CONFIG

        context?.startService(Intent(context, XrayVpnService::class.java).apply {
            this.action = action
            putExtra(extra, config)
        })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == 7890 && resultCode == Activity.RESULT_OK) {
            pendingConfig?.let { executeStart(it) }
            pendingConfig = null
            return true
        }
        return false
    }

    // Стандартные реализации EventChannel (onListen/onCancel) и ActivityAware...
    override fun onListen(args: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
    override fun onCancel(args: Any?) { eventSink = null }
    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity
        b.addActivityResultListener(this)
    }
    override fun onDetachedFromActivity() { activity = null }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {}
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() {}
}