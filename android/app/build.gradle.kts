import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Read signing config from key.properties if it exists (CI / release builds).
// Falls back to debug signing for local development.
val keystorePropertiesFile = rootProject.file("key.properties")
val useKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (useKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.yuklore.spendflux"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (useKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    // Declare the model asset pack as a dynamic feature.
    dynamicFeatures += setOf(":model_delivery")

    defaultConfig {
        applicationId = "com.yuklore.spendflux"
        minSdk = 29  // Flux AI / MediaPipe LLM minimum
        targetSdk = flutter.targetSdkVersion

        // ── App version ────────────────────────────────────────────────
        // These values are sourced from the `version:` line at the top
        // of pubspec.yaml (e.g. `version: 1.1.0+4`). The Flutter Gradle
        // plugin exposes them as `flutter.versionName` and
        // `flutter.versionCode`, so updating the pubspec is enough —
        // no need to edit this file when bumping the version.
        versionCode = 7
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (useKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.mediapipe:tasks-genai:0.10.27")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    // Play Asset Delivery — provides AssetPackManager for model delivery.
    implementation("com.google.android.play:asset-delivery:2.2.2")
}
