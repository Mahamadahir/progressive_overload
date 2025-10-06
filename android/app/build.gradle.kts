// android/app/build.gradle.kts (APP-level)
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mahamad.fitness.progressive_overload"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.mahamad.fitness.progressive_overload"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ✅ Desugared JDK APIs (java.time, etc.)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // NOTE: Do NOT pin connect-client here to a version that conflicts with plugin.
    // Pinning is controlled project-wide in android/build.gradle.kts via resolutionStrategy.force(...).
    //
    // If you prefer to pin here instead, ensure it matches the project forced version:
    // implementation("androidx.health.connect:connect-client:1.1.0-alpha11")
}

flutter {
    source = "../.."
}
