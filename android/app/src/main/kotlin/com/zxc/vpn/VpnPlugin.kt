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
import android.os.Build

class VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware, PluginRegistry.ActivityResultListener {

    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingConfigData: String? = null

    private val VPN_REQUEST_CODE = 2026

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val status = intent?.getStringExtra(XrayVpnService.EXTRA_STATUS)
            status?.let { eventSink?.success(it) }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        MethodChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_service").setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_status").setStreamHandler(this)

        LocalBroadcastManager.getInstance(context!!).registerReceiver(
            statusReceiver, IntentFilter(XrayVpnService.BROADCAST_STATUS)
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                checkNotificationPermission()
                val config = call.argument<String>("config")
                if (config.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Config is empty", null)
                    return
                }
                initiateConnection(config, result)
            }
            "disconnect" -> {
                context?.startService(Intent(context, XrayVpnService::class.java).apply {
                    action = XrayVpnService.ACTION_DISCONNECT
                })
                result.success(true)
            }
            "isActive" -> {
                result.success(XrayVpnService.instance?.isServiceRunning == true)
            }
            else -> result.notImplemented()
        }
    }

    private fun initiateConnection(config: String, result: MethodChannel.Result) {
        val vpnIntent = VpnService.prepare(context)
        if (vpnIntent != null) {
            pendingConfigData = config
            activity?.startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
        } else {
            startVpnService(config)
        }
        result.success(true)
    }

    private fun startVpnService(config: String) {
        val intent = Intent(context, XrayVpnService::class.java).apply {
            action = XrayVpnService.ACTION_CONNECT
            putExtra(XrayVpnService.EXTRA_CONFIG, config)
        }
        context?.startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingConfigData?.let { startVpnService(it) }
            } else {
                eventSink?.success(XrayVpnService.STATUS_ERROR)
            }
            pendingConfigData = null
            return true
        }
        return false
    }

    private fun checkNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val permission = android.Manifest.permission.POST_NOTIFICATIONS
            if (context?.checkSelfPermission(permission) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                activity?.requestPermissions(arrayOf(permission), 102)
            }
        }
    }

    override fun onListen(args: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(args: Any?) { eventSink = null }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivity() { activity = null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context?.let { LocalBroadcastManager.getInstance(it).unregisterReceiver(statusReceiver) }
        context = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
}