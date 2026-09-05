package com.contextvault.app.contextvault

import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class QuickTileService : TileService() {
    override fun onClick() {
        super.onClick()
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra("route", "quick_access")
            action = "ACTION_QUICK_SEARCH"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (intent != null) {
            startActivityAndCollapse(intent)
        }
    }
}
