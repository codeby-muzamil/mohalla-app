plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mohalla.app"
    // 37: flutter_local_notifications (and androidx.core 1.19.0) require
    // compileSdk >= 37 (checked 2026-11-16). targetSdk stays 36 —
    // compileSdk can be raised without opting into new runtime behaviour.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (core library desugaring).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.mohalla.app"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        // AGP 9's bundled lint crashes on JDK 17 (NoSuchMethodError:
        // List.removeLast in its JavaDoc parser) while analysing
        // plugin code. Lint is only a static-analysis check —
        // skipping it for release builds does not change the APK.
        checkReleaseBuilds = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
