package com.contextvault.app.contextvault

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.contextvault.app/quick_access"
    private val NOTIFICATION_ID = 8881
    private val CHANNEL_ID = "contextvault_quick_access_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
            .setContentTitle("ContextVault Quick Access")
            .setContentText("Tap an action to instantly search or paste snippets.")
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
