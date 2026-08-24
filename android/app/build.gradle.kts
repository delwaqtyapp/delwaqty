plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.delwaqty.app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val keystoreFile = rootProject.file("keystore/release.jks")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
                keyAlias = System.getenv("KEY_ALIAS") ?: ""
                keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            }
        }
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val mapsApiKey = System.getenv("MAPS_API_KEY")
            ?: project.findProperty("MAPS_API_KEY") as? String
            ?: ""
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    flavorDimensions += "app"

    productFlavors {
        create("customer") {
            dimension = "app"
            applicationId = "com.delwaqty.app"
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.delwaqty.admin"
        }
        create("driver") {
            dimension = "app"
            applicationId = "com.delwaqty.driver"
        }
        create("provider") {
            dimension = "app"
            applicationId = "com.delwaqty.provider"
        }
    }

    buildTypes {
        release {
            val keystoreFile = rootProject.file("keystore/release.jks")
            val hasReleaseKey = keystoreFile.exists() && !System.getenv("KEYSTORE_PASSWORD").isNullOrEmpty()
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = false
        }
    }
}

tasks.configureEach {
    if (name.startsWith("uploadCrashlyticsMappingFile")) {
        onlyIf { System.getenv("CRASHLYTICS_UPLOAD") != "false" }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
