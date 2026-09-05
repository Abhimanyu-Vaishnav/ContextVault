# ContextVault Custom ProGuard / R8 Rules for Production Hardening

# Flutter & Native MethodChannels
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# ContextVault Native Services & Activities
-keep class com.contextvault.app.contextvault.FloatingBubbleService { *; }
-keep class com.contextvault.app.contextvault.QuickTileService { *; }
-keep class com.contextvault.app.contextvault.MainActivity { *; }

# RevenueCat & Billing
-dontwarn com.amazon.**
-keep class com.amazon.** {*;}
-keepattributes *Annotation*
-keep class androidx.lifecycle.DefaultLifecycleObserver
-keep class com.revenuecat.purchases.** { *; }

# SQLite & Data Serialization
-keep class com.tekartik.sqflite.** { *; }
-keep class com.it_ne.flutter_secure_storage.** { *; }

# Obfuscate internal ContextVault classes, feature gates & models
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Ignore missing Google Play Core references in Flutter engine (deferred components)
-dontwarn com.google.android.play.core.**

# Preserve native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
