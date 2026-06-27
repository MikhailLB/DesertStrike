import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin
    // Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// google-services is applied lazily — only when google-services.json is
// present in android/app/. This lets the project build and run without
// Firebase credentials during early scaffolding; drop the real JSON in and
// the next build will pick it up with no additional gradle edits.
val googleServicesJson = file("google-services.json")
if (googleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release keystore is loaded from android/key.properties (NOT committed).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // Keep the namespace tied to the Kotlin package layout (MainActivity is at
    // com/desertstrike/desert_strike/). Only the applicationId — the Play
    // Store identity — uses the chaosdesert vendor slug.
    namespace = "com.desertstrike.desert_strike"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring is required by flutter_local_notifications
        // 18.x (gray_part_pitfalls.md §5).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.chaosdesert.desertstrike"
        minSdk = 30
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasKeystore) {
        signingConfigs {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// AGP 9.0 deprecated kotlinOptions { jvmTarget = ... }. Use the
// compilerOptions DSL instead.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
