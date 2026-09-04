# ContextVault Custom ProGuard / R8 Rules for Production Hardening

# Preserve Flutter Engine JNI entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }

# Preserve SQLite & Secure Storage Native Bridges
-keep class com.tekartik.sqflite.** { *; }
-keep class com.it_ne.flutter_secure_storage.** { *; }

# Preserve RevenueCat Purchases SDK
-keep class com.revenuecat.purchases.** { *; }

# Obfuscate internal ContextVault classes, feature gates & models
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Preserve native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
