package com.contextvault.app.contextvault

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.text.Editable
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

class FloatingBubbleService : Service() {

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var panelView: View? = null

    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panelParams: WindowManager.LayoutParams? = null

    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f

    private var isExpandedSize = false
    private var allSnippets = mutableListOf<SnippetItem>()
    private var filteredSnippets = mutableListOf<SnippetItem>()
    private var snippetListContainer: LinearLayout? = null

    data class SnippetItem(val title: String, val content: String)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForegroundServiceNotification()
        createBubbleView()
        createPanelView()
    }

    private fun startForegroundServiceNotification() {
        val channelId = "contextvault_bubble_service"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Floating Assistant Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = notificationBuilder
            .setContentTitle("ContextVault Floating Assistant")
            .setContentText("Edge panel active on screen")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .build()

        startForeground(9991, notification)
    }

    private fun createBubbleView() {
        val density = resources.displayMetrics.density
        val sizePx = (52 * density).toInt()

        val imageView = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_search)
            setColorFilter(Color.parseColor("#58A6FF"))
            padding(12 * density)

            val shape = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#0D1117"))
                setStroke((1.5 * density).toInt(), Color.parseColor("#30363D"))
            }
            background = shape
            elevation = 10f
        }

        bubbleView = imageView

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        bubbleParams = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 20
            y = 400
        }

        imageView.setOnTouchListener(object : View.OnTouchListener {
            private var isClick = false

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                val currentParams = bubbleParams ?: return false
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isClick = true
                        initialX = currentParams.x
                        initialY = currentParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()

                        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                            isClick = false
                        }

                        currentParams.x = initialX - dx
                        currentParams.y = initialY + dy

                        windowManager?.updateViewLayout(bubbleView, currentParams)
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (isClick) {
                            v.performClick()
                            showPanel()
                        }
                        return true
                    }
                }
                return false
            }
        })

        try {
            windowManager?.addView(bubbleView, bubbleParams)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createPanelView() {
        val density = resources.displayMetrics.density
        val defaultWidthPx = (320 * density).toInt()
        val defaultHeightPx = (420 * density).toInt()

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        panelParams = WindowManager.LayoutParams(
            defaultWidthPx,
            defaultHeightPx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        // Root container for Panel
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            padding(14 * density)

            val shape = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 16 * density
                setColor(Color.parseColor("#0D1117"))
                setStroke((1.5 * density).toInt(), Color.parseColor("#30363D"))
            }
            background = shape
            elevation = 16f
        }

        // Header Row
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val boltIcon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_compass)
            setColorFilter(Color.parseColor("#58A6FF"))
            layoutParams = LinearLayout.LayoutParams((20 * density).toInt(), (20 * density).toInt())
        }

        val titleText = TextView(this).apply {
            text = "⚡ ContextVault Quick"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                setMargins((8 * density).toInt(), 0, 0, 0)
            }
        }

        // Resize Toggle Button
        val resizeBtn = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_crop)
            setColorFilter(Color.parseColor("#8B949E"))
            padding(4 * density)
            layoutParams = LinearLayout.LayoutParams((28 * density).toInt(), (28 * density).toInt())
            setOnClickListener {
                togglePanelSize()
            }
        }

        // Close Button
        val closeBtn = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.parseColor("#8B949E"))
            padding(4 * density)
            layoutParams = LinearLayout.LayoutParams((28 * density).toInt(), (28 * density).toInt()).apply {
                setMargins((6 * density).toInt(), 0, 0, 0)
            }
            setOnClickListener {
                hidePanel()
            }
        }

        headerRow.addView(boltIcon)
        headerRow.addView(titleText)
        headerRow.addView(resizeBtn)
        headerRow.addView(closeBtn)

        // Search Input
        val searchEdit = EditText(this).apply {
            hint = "Search snippets..."
            setHintTextColor(Color.parseColor("#484F58"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setSingleLine(true)
            padding(10 * density)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, (12 * density).toInt(), 0, (10 * density).toInt())
            }

            val editShape = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 10 * density
                setColor(Color.parseColor("#161B22"))
                setStroke((1 * density).toInt(), Color.parseColor("#30363D"))
            }
            background = editShape
        }

        searchEdit.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                filterSnippets(s.toString())
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        // Snippet List Scroll View
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
            isVerticalScrollBarEnabled = true
        }

        snippetListContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }

        scrollView.addView(snippetListContainer)

        rootLayout.addView(headerRow)
        rootLayout.addView(searchEdit)
        rootLayout.addView(scrollView)

        rootLayout.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE) {
                hidePanel()
                true
            } else {
                false
            }
        }

        panelView = rootLayout
    }

    private fun showPanel() {
        if (panelView == null || windowManager == null) return

        loadSnippetsFromStorage()
        filterSnippets("")

        try {
            if (bubbleView?.windowToken != null) {
                windowManager?.removeView(bubbleView)
            }
            windowManager?.addView(panelView, panelParams)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hidePanel() {
        if (panelView?.windowToken != null && windowManager != null) {
            try {
                windowManager?.removeView(panelView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        if (bubbleView?.windowToken == null && windowManager != null) {
            try {
                windowManager?.addView(bubbleView, bubbleParams)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun togglePanelSize() {
        val density = resources.displayMetrics.density
        val pParams = panelParams ?: return

        if (isExpandedSize) {
            pParams.width = (320 * density).toInt()
            pParams.height = (420 * density).toInt()
            isExpandedSize = false
        } else {
            pParams.width = (360 * density).toInt()
            pParams.height = (520 * density).toInt()
            isExpandedSize = true
        }

        if (panelView?.windowToken != null) {
            windowManager?.updateViewLayout(panelView, pParams)
        }
    }

    private fun loadSnippetsFromStorage() {
        allSnippets.clear()
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val rawJson = prefs.getString("flutter.quick_dock_snippets", null)

            if (!rawJson.isNullOrEmpty()) {
                val jsonArray = JSONArray(rawJson)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val title = obj.optString("title", "Untitled")
                    val content = obj.optString("content", "")
                    allSnippets.add(SnippetItem(title, content))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (allSnippets.isEmpty()) {
            allSnippets.add(SnippetItem("Welcome Snippet", "Tap to copy this instant snippet context."))
            allSnippets.add(SnippetItem("Email Response", "Thanks for reaching out! I'll get back to you shortly."))
            allSnippets.add(SnippetItem("Meeting Notes Template", "Agenda:\n1. Key Updates\n2. Action Items"))
        }
    }

    private fun filterSnippets(query: String) {
        val q = query.trim().lowercase()
        filteredSnippets = if (q.isEmpty()) {
            allSnippets.toList().toMutableList()
        } else {
            allSnippets.filter {
                it.title.lowercase().contains(q) || it.content.lowercase().contains(q)
            }.toMutableList()
        }

        renderSnippetList()
    }

    private fun renderSnippetList() {
        val container = snippetListContainer ?: return
        container.removeAllViews()
        val density = resources.displayMetrics.density

        if (filteredSnippets.isEmpty()) {
            val emptyTv = TextView(this).apply {
                text = "No snippets found"
                setTextColor(Color.parseColor("#8B949E"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                gravity = Gravity.CENTER
                padding(20 * density)
            }
            container.addView(emptyTv)
            return
        }

        for (snippet in filteredSnippets.take(15)) {
            val itemCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                padding(10 * density)
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    setMargins(0, 0, 0, (8 * density).toInt())
                }

                val cardShape = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 10 * density
                    setColor(Color.parseColor("#161B22"))
                    setStroke((1 * density).toInt(), Color.parseColor("#30363D"))
                }
                background = cardShape
            }

            val itemTitle = TextView(this).apply {
                text = snippet.title
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
                maxLines = 1
            }

            val itemContent = TextView(this).apply {
                text = snippet.content
                setTextColor(Color.parseColor("#8B949E"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                maxLines = 1
            }

            itemCard.addView(itemTitle)
            itemCard.addView(itemContent)

            itemCard.setOnClickListener {
                copySnippetAndClose(snippet)
            }

            container.addView(itemCard)
        }
    }

    private fun copySnippetAndClose(snippet: SnippetItem) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("ContextVault Snippet", snippet.content)
        clipboard.setPrimaryClip(clip)

        // Trigger haptic vibration
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(50)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        Toast.makeText(this, "⚡ Copied: ${snippet.title}", Toast.LENGTH_SHORT).show()
        hidePanel()
    }

    private fun View.padding(px: Float) {
        val pad = px.toInt()
        setPadding(pad, pad, pad, pad)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (bubbleView?.windowToken != null && windowManager != null) {
            try {
                windowManager?.removeView(bubbleView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        if (panelView?.windowToken != null && windowManager != null) {
            try {
                windowManager?.removeView(panelView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
