import java.util.Properties
import java.io.FileInputStream

// Load keystore properties (Kotlin DSL)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.versant_event_app.versant_event2"
  //  namespace = "com.versant_event_app.versant_event"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Add signing configurations (Kotlin DSL)
    signingConfigs {
        create("release") {
            val alias = keystoreProperties["keyAlias"] as String?
            val keyPwd = keystoreProperties["keyPassword"] as String?
            val storePath = keystoreProperties["storeFile"] as String?
            val storePwd = keystoreProperties["storePassword"] as String?

            if (alias != null) keyAlias = alias
            if (keyPwd != null) keyPassword = keyPwd
            if (storePath != null) storeFile = file(storePath)
            if (storePwd != null) storePassword = storePwd
        }
    }

    defaultConfig {
      //  applicationId = "com.versant_event_app.versant_event"
        applicationId = "com.versant_event_app.versant_event2"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Use Flutter-managed versioning from pubspec.yaml (e.g., version: x.y.z+code)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use proper signing for release builds
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}