import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: System.getenv("KEYSTORE_PASSWORD").orEmpty()
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: System.getenv("KEY_ALIAS").orEmpty()
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: System.getenv("KEY_PASSWORD").orEmpty()
            }
        }
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        val mapsApiKey = System.getenv("MAPS_API_KEY")
            ?: project.findProperty("MAPS_API_KEY") as? String
            ?: ""
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    packaging {
        jniLibs {
            // Vulkan validation layer is a DEBUG-ONLY diagnostic shipped by the
            // Flutter/NDK toolchain. It is never needed at runtime; excluding it
            // removes ~15 MB from every debug APK.
            excludes += setOf("**/libVkLayer_khronos_validation.so")
            // Store native libs compressed (extract-at-install) instead of
            // uncompressed/mmap path. Removes ~24MB and allows a tight repack.
            useLegacyPackaging = true
        }
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
            val storePass = keystoreProperties.getProperty("storePassword")
                ?: System.getenv("KEYSTORE_PASSWORD").orEmpty()
            val hasReleaseKey = keystoreFile.exists() && storePass.isNotEmpty()
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
