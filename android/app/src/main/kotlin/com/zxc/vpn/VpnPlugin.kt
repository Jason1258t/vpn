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

    private var pendingConfigData: String? = null
    private var pendingIsUrl: Boolean = false

    private val VPN_REQUEST_CODE = 2026

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val status = intent?.getStringExtra(XrayVpnService.EXTRA_STATUS)
            if (status != null) {
                eventSink?.success(status)
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        MethodChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_service").setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, "com.zxc.vpn/vpn_status").setStreamHandler(this)

        LocalBroadcastManager.getInstance(context!!).registerReceiver(
            statusReceiver,
            IntentFilter(XrayVpnService.BROADCAST_STATUS)
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val config = call.argument<String>("config")
                if (config.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Конфигурация не может быть пустой", null)
                    return
                }

                val isUrl = config.startsWith("vless://") || config.startsWith("vmess://") || config.startsWith("ss://")
                initiateConnection(config, isUrl, result)
            }
            "disconnect" -> {
                val intent = Intent(context, XrayVpnService::class.java).apply {
                    action = XrayVpnService.ACTION_DISCONNECT
                }
                context?.startService(intent)
                result.success(true)
            }
            "ping" -> {
                val config = call.argument<String>("configJson")
                val isUrl = config?.startsWith("vless://") ?: false

                // Создаем интенс для выполнения пинга в контексте сервиса
                val intent = Intent(context, XrayVpnService::class.java).apply {
                    action = XrayVpnService.ACTION_PING
                    putExtra(XrayVpnService.EXTRA_CONFIG, config)
                    putExtra(XrayVpnService.EXTRA_IS_URL, isUrl)
                }

                // Мы не можем использовать startService для получения результата напрямую,
                // поэтому для мгновенного пинга (без задействования жизненного цикла сервиса)
                // лучше вызвать статический метод или синглтон, если сервис запущен.
                // Но самый чистый путь для текущей структуры — добавить метод в сам сервис.

                Thread {
                    val delay = XrayVpnService.calculatePing(context!!, config ?: "", isUrl)
                    activity?.runOnUiThread {
                        result.success(delay.toString())
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun initiateConnection(config: String, isUrl: Boolean, result: MethodChannel.Result) {
        val vpnIntent = VpnService.prepare(context)
        if (vpnIntent != null) {
            pendingConfigData = config
            pendingIsUrl = isUrl
            activity?.startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
        } else {
            startVpnService(config, isUrl)
        }
        result.success(true)
    }

    private fun startVpnService(config: String, isUrl: Boolean) {
        val intent = Intent(context, XrayVpnService::class.java).apply {
            action = XrayVpnService.ACTION_CONNECT
            putExtra(XrayVpnService.EXTRA_CONFIG, config)
            putExtra(XrayVpnService.EXTRA_IS_URL, isUrl)
        }
        context?.startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingConfigData?.let { config ->
                    startVpnService(config, pendingIsUrl)
                }
            } else {
                eventSink?.success(XrayVpnService.STATUS_ERROR)
            }
            pendingConfigData = null
            return true
        }
        return false
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context?.let {
            LocalBroadcastManager.getInstance(it).unregisterReceiver(statusReceiver)
        }
        context = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}