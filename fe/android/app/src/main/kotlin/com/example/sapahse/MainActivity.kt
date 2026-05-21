package com.example.sapahse

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val deepLinkChannelName = "sapahse/deep_link"
    private var deepLinkChannel: MethodChannel? = null
    private var pendingInitialLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingInitialLink = intent?.dataString
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deepLinkChannelName
        )
        deepLinkChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialLink") {
                result.success(pendingInitialLink)
                pendingInitialLink = null
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val link = intent.dataString ?: return
        if (deepLinkChannel == null) {
            pendingInitialLink = link
            return
        }

        deepLinkChannel?.invokeMethod("onDeepLink", link)
    }
}
