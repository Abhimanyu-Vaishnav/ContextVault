package com.contextvault.app.contextvault

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.contextvault.app/quick_access"
    private val NOTIFICATION_ID = 8881
    private val CHANNEL_ID = "contextvault_quick_access_channel"

    override fun onResume() {
        super.onResume()
        FloatingBubbleService.instance?.setAppForegroundState(true)
    }

    override fun onPause() {
        super.onPause()
        FloatingBubbleService.instance?.setAppForegroundState(false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Pre-warm the secondary engine for instant floating access
        try {
            if (io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("quick_vault_engine") == null) {
                val quickEngine = io.flutter.embedding.engine.FlutterEngine(this).apply {
                    navigationChannel.pushRoute("quick_bubble_dialog")
                    dartExecutor.executeDartEntrypoint(
                        io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint.createDefault()
                    )
                }
                io.flutter.embedding.engine.FlutterEngineCache.getInstance().put("quick_vault_engine", quickEngine)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchIntentAction" -> {
                    val route = intent?.getStringExtra("route") ?: intent?.action
                    result.success(route)
                }
                "startQuickAccessNotification" -> {
                    try {
                        showPersistentNotification()
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "stopQuickAccessNotification" -> {
                    try {
                        stopPersistentNotification()
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                "notifySnippetsUpdated" -> {
                    try {
                        val intent = Intent("com.contextvault.app.SNIPPETS_UPDATED").apply {
                            setPackage(packageName)
                        }
                        sendBroadcast(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.contextvault.app/overlay").setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        android.provider.Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(canDraw)
                }
                "startBubble" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !android.provider.Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(false)
                    } else {
                        val intent = Intent(this, FloatingBubbleService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                }
                "stopBubble" -> {
                    val intent = Intent(this, FloatingBubbleService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun showPersistentNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ContextVault Quick Access",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Ongoing notification for quick snippet search and copy"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Quick Search Action Intent
        val searchIntent = Intent(this, MainActivity::class.java).apply {
            action = "ACTION_QUICK_SEARCH"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val searchPendingIntent = PendingIntent.getActivity(
            this, 1, searchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Recent Copied Action Intent
        val recentIntent = Intent(this, MainActivity::class.java).apply {
            action = "ACTION_RECENT_COPIED"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val recentPendingIntent = PendingIntent.getActivity(
            this, 2, recentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⚡ ContextVault Active")
            .setContentText("Tap to search snippets")
            .setSmallIcon(android.R.drawable.ic_menu_agenda)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(android.R.drawable.ic_menu_search, "Quick Search", searchPendingIntent)
            .addAction(android.R.drawable.ic_menu_recent_history, "Recent Copied", recentPendingIntent)
            .setContentIntent(searchPendingIntent)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun stopPersistentNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
