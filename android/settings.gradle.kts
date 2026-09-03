pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

gradle.beforeProject {
    if (this.name == "isar_flutter_libs") {
        this.afterEvaluate {
            val androidExt = this.extensions.findByName("android")
            if (androidExt != null) {
                val setNamespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                setNamespaceMethod.invoke(androidExt, "dev.isar.isar_flutter_libs")
            }
        }
    }
}


include(":app")
