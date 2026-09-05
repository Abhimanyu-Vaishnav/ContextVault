package com.contextvault.app.contextvault

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class QuickSnippetActivity : FlutterActivity() {
    private val CHANNEL = "com.contextvault.app/quick_access"

    override fun getCachedEngineId(): String? = "quick_vault_engine"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun getInitialRoute(): String {
        return "quick_bubble_dialog"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchIntentAction" -> {
                    result.success("quick_bubble_dialog")
                }
                else -> result.notImplemented()
            }
        }
    }
}
