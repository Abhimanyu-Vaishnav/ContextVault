package com.contextvault.app.contextvault

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
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
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.regex.Pattern

class FloatingBubbleService : Service() {

    companion object {
        var instance: FloatingBubbleService? = null
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var panelView: View? = null

    private var bubbleParams: WindowManager.LayoutParams? = null
    private var panelParams: WindowManager.LayoutParams? = null

    // Bubble touch/drag state
    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f

    // Panel touch/drag state
    private var panelInitialX: Int = 0
    private var panelInitialY: Int = 0
    private var panelInitialTouchX: Float = 0f
    private var panelInitialTouchY: Float = 0f

    private var isExpandedSize = false
    private var isHiddenByForeground = false

    private var allSnippets = mutableListOf<SnippetItem>()
    private var filteredSnippets = mutableListOf<SnippetItem>()

    // Containers inside Panel
    private var snippetListContainer: LinearLayout? = null
    private var snippetListViewGroup: LinearLayout? = null
    private var tokenInputViewGroup: LinearLayout? = null
    private var tokenFieldsContainer: LinearLayout? = null
    private var currentActiveSnippet: SnippetItem? = null
    private var dynamicInputMap = mutableMapOf<String, EditText>()

    data class SnippetItem(val title: String, val content: String)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForegroundServiceNotification()
        createBubbleView()
        createPanelView()
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        removeFloatingViews()
    }

    fun setAppForegroundState(isForeground: Boolean) {
        if (isForeground) {
            isHiddenByForeground = true
            removeFloatingViews()
        } else {
            isHiddenByForeground = false
            restoreFloatingBubble()
        }
    }

    private fun removeFloatingViews() {
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

    private fun restoreFloatingBubble() {
        if (isHiddenByForeground) return
        if (bubbleView?.windowToken == null && panelView?.windowToken == null && windowManager != null) {
            try {
                windowManager?.addView(bubbleView, bubbleParams)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
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
                            showPanelWithAnimation()
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
        val defaultWidthPx = (330 * density).toInt()
        val defaultHeightPx = (440 * density).toInt()

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

        // Header Row (Free Drag Movement Handle)
        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            padding(4 * density)
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

        // Open Full Vault Activity CTA Button
        val openAppBtn = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_send)
            setColorFilter(Color.parseColor("#58A6FF"))
            padding(4 * density)
            layoutParams = LinearLayout.LayoutParams((28 * density).toInt(), (28 * density).toInt())
            setOnClickListener {
                openFullApp()
            }
        }

        // Resize Toggle Button
        val resizeBtn = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_crop)
            setColorFilter(Color.parseColor("#8B949E"))
            padding(4 * density)
            layoutParams = LinearLayout.LayoutParams((28 * density).toInt(), (28 * density).toInt()).apply {
                setMargins((4 * density).toInt(), 0, 0, 0)
            }
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
                setMargins((4 * density).toInt(), 0, 0, 0)
            }
            setOnClickListener {
                hidePanelWithAnimation()
            }
        }

        headerRow.addView(boltIcon)
        headerRow.addView(titleText)
        headerRow.addView(openAppBtn)
        headerRow.addView(resizeBtn)
        headerRow.addView(closeBtn)

        // Free Drag Listener on Header
        headerRow.setOnTouchListener(object : View.OnTouchListener {
            override fun onTouch(v: View, event: MotionEvent): Boolean {
                val currentParams = panelParams ?: return false
                val displayMetrics = resources.displayMetrics
                val screenWidth = displayMetrics.widthPixels
                val screenHeight = displayMetrics.heightPixels

                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        panelInitialX = currentParams.x
                        panelInitialY = currentParams.y
                        panelInitialTouchX = event.rawX
                        panelInitialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - panelInitialTouchX).toInt()
                        val dy = (event.rawY - panelInitialTouchY).toInt()

                        var newX = panelInitialX + dx
                        var newY = panelInitialY + dy

                        // Clamp within screen bounds
                        val maxClampX = (screenWidth / 2) - 50
                        val maxClampY = (screenHeight / 2) - 50
                        newX = newX.coerceIn(-maxClampX, maxClampX)
                        newY = newY.coerceIn(-maxClampY, maxClampY)

                        currentParams.x = newX
                        currentParams.y = newY

                        windowManager?.updateViewLayout(panelView, currentParams)
                        return true
                    }
                }
                return false
            }
        })

        // VIEW 1: Snippet List View Group
        snippetListViewGroup = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        }

        val searchEdit = EditText(this).apply {
            hint = "Search snippets..."
            setHintTextColor(Color.parseColor("#484F58"))
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setSingleLine(true)
            padding(10 * density)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, (10 * density).toInt(), 0, (10 * density).toInt())
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

        val listScrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
            isVerticalScrollBarEnabled = true
        }

        snippetListContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }

        listScrollView.addView(snippetListContainer)
        snippetListViewGroup?.addView(searchEdit)
        snippetListViewGroup?.addView(listScrollView)

        // VIEW 2: Dynamic Token Input Form View Group
        tokenInputViewGroup = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        }

        val tokenFormScrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)
        }

        tokenFieldsContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }
        tokenFormScrollView.addView(tokenFieldsContainer)

        // Token Action Buttons Row
        val tokenActionRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                setMargins(0, (10 * density).toInt(), 0, 0)
            }
        }

        val backBtn = Button(this).apply {
            text = "Back"
            setTextColor(Color.parseColor("#8B949E"))
            setBackgroundColor(Color.TRANSPARENT)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            setOnClickListener {
                switchToListView()
            }
        }

        val submitTokenBtn = Button(this).apply {
            text = "⚡ Copy & Paste Ready"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                setMargins((8 * density).toInt(), 0, 0, 0)
            }

            val btnShape = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 8 * density
                setColor(Color.parseColor("#238636"))
            }
            background = btnShape

            setOnClickListener {
                processAndCopyTokenTemplate()
            }
        }

        tokenActionRow.addView(backBtn)
        tokenActionRow.addView(submitTokenBtn)

        tokenInputViewGroup?.addView(tokenFormScrollView)
        tokenInputViewGroup?.addView(tokenActionRow)

        rootLayout.addView(headerRow)
        rootLayout.addView(snippetListViewGroup)
        rootLayout.addView(tokenInputViewGroup)

        rootLayout.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE) {
                hidePanelWithAnimation()
                true
            } else {
                false
            }
        }

        panelView = rootLayout
    }

    private fun openFullApp() {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            if (launchIntent != null) {
                startActivity(launchIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        hidePanelWithAnimation()
    }

    private fun showPanelWithAnimation() {
        if (panelView == null || windowManager == null) return

        loadSnippetsFromStorage()
        switchToListView()
        filterSnippets("")

        try {
            if (bubbleView?.windowToken != null) {
                // Animate Bubble out
                bubbleView?.animate()
                    ?.scaleX(0.5f)
                    ?.scaleY(0.5f)
                    ?.alpha(0f)
                    ?.setDuration(150)
                    ?.setListener(object : AnimatorListenerAdapter() {
                        override fun onAnimationEnd(animation: Animator) {
                            try {
                                if (bubbleView?.windowToken != null) {
                                    windowManager?.removeView(bubbleView)
                                }
                            } catch (e: Exception) {}
                        }
                    })?.start()
            }

            panelView?.scaleX = 0.8f
            panelView?.scaleY = 0.8f
            panelView?.alpha = 0f
            windowManager?.addView(panelView, panelParams)

            panelView?.animate()
                ?.scaleX(1f)
                ?.scaleY(1f)
                ?.alpha(1f)
                ?.setDuration(200)
                ?.setInterpolator(DecelerateInterpolator())
                ?.setListener(null)
                ?.start()

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hidePanelWithAnimation() {
        if (panelView?.windowToken != null && windowManager != null) {
            panelView?.animate()
                ?.scaleX(0.8f)
                ?.scaleY(0.8f)
                ?.alpha(0f)
                ?.setDuration(180)
                ?.setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        try {
                            if (panelView?.windowToken != null) {
                                windowManager?.removeView(panelView)
                            }
                        } catch (e: Exception) {}

                        if (bubbleView?.windowToken == null && windowManager != null && !isHiddenByForeground) {
                            try {
                                bubbleView?.scaleX = 0.5f
                                bubbleView?.scaleY = 0.5f
                                bubbleView?.alpha = 0f
                                windowManager?.addView(bubbleView, bubbleParams)

                                bubbleView?.animate()
                                    ?.scaleX(1f)
                                    ?.scaleY(1f)
                                    ?.alpha(1f)
                                    ?.setDuration(150)
                                    ?.setListener(null)
                                    ?.start()
                            } catch (e: Exception) {}
                        }
                    }
                })?.start()
        }
    }

    private fun switchToListView() {
        tokenInputViewGroup?.visibility = View.GONE
        snippetListViewGroup?.visibility = View.VISIBLE
    }

    private fun switchToTokenView(snippet: SnippetItem, tokenFields: List<String>) {
        currentActiveSnippet = snippet
        dynamicInputMap.clear()

        val container = tokenFieldsContainer ?: return
        container.removeAllViews()
        val density = resources.displayMetrics.density

        // Title Header
        val titleTv = TextView(this).apply {
            text = "Fill Template Tokens"
            setTextColor(Color.parseColor("#58A6FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            padding(4 * density)
        }
        container.addView(titleTv)

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())

        for (field in tokenFields) {
            val fieldLabel = TextView(this).apply {
                text = field.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString() }
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                padding(2 * density)
                layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    setMargins(0, (6 * density).toInt(), 0, (2 * density).toInt())
                }
            }

            val fieldEdit = EditText(this).apply {
                setHintTextColor(Color.parseColor("#484F58"))
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                setSingleLine(true)
                padding(8 * density)

                val editShape = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadius = 8 * density
                    setColor(Color.parseColor("#161B22"))
                    setStroke((1 * density).toInt(), Color.parseColor("#30363D"))
                }
                background = editShape

                if (field.equals("date", ignoreCase = true)) {
                    setText(dateFormat)
                } else if (field.equals("time", ignoreCase = true)) {
                    setText(timeFormat)
                } else {
                    hint = "Enter $field..."
                }
            }

            dynamicInputMap[field] = fieldEdit
            container.addView(fieldLabel)
            container.addView(fieldEdit)
        }

        snippetListViewGroup?.visibility = View.GONE
        tokenInputViewGroup?.visibility = View.VISIBLE
    }

    private fun processAndCopyTokenTemplate() {
        val snippet = currentActiveSnippet ?: return
        var content = snippet.content

        // Replace {date} and {time}
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        content = content.replace("{date}", dateFormat, ignoreCase = true)
        content = content.replace("{time}", timeFormat, ignoreCase = true)

        // Replace dynamic inputs {input:Label}
        for ((field, edit) in dynamicInputMap) {
            val valText = edit.text.toString()
            content = content.replace("{input:$field}", valText, ignoreCase = true)
            content = content.replace("{$field}", valText, ignoreCase = true)
        }

        copyToClipboardAndFinish(snippet.title, content)
    }

    private fun togglePanelSize() {
        val density = resources.displayMetrics.density
        val pParams = panelParams ?: return

        if (isExpandedSize) {
            pParams.width = (330 * density).toInt()
            pParams.height = (440 * density).toInt()
            isExpandedSize = false
        } else {
            pParams.width = (370 * density).toInt()
            pParams.height = (540 * density).toInt()
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
            allSnippets.add(SnippetItem("Welcome Snippet", "Hello {input:name}, meeting scheduled for {date} at {time}."))
            allSnippets.add(SnippetItem("Email Response", "Thanks for reaching out {input:client_name}! I'll get back to you by {date}."))
            allSnippets.add(SnippetItem("Quick Status", "Status update for {date}: All systems operational."))
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
                handleSnippetTap(snippet)
            }

            container.addView(itemCard)
        }
    }

    private fun handleSnippetTap(snippet: SnippetItem) {
        val tokenFields = extractTokenFields(snippet.content)
        if (tokenFields.isEmpty()) {
            copyToClipboardAndFinish(snippet.title, snippet.content)
        } else {
            switchToTokenView(snippet, tokenFields)
        }
    }

    private fun extractTokenFields(content: String): List<String> {
        val tokens = mutableListOf<String>()

        val inputMatcher = Pattern.compile("\\{input:([^\\}]+)\\}").matcher(content)
        while (inputMatcher.find()) {
            inputMatcher.group(1)?.let {
                if (!tokens.contains(it)) tokens.add(it)
            }
        }

        if (content.contains("{date}", ignoreCase = true) && !tokens.contains("date")) {
            tokens.add("date")
        }
        if (content.contains("{time}", ignoreCase = true) && !tokens.contains("time")) {
            tokens.add("time")
        }

        return tokens
    }

    private fun copyToClipboardAndFinish(title: String, text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("ContextVault Snippet", text)
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

        Toast.makeText(this, "⚡ Copied: $title", Toast.LENGTH_SHORT).show()
        hidePanelWithAnimation()
    }

    private fun View.padding(px: Float) {
        val pad = px.toInt()
        setPadding(pad, pad, pad, pad)
    }
}
