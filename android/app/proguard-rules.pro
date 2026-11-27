# R8 keep rules for release builds (minify + shrink enabled).
# Flutter's own rules ship with the Flutter Gradle plugin. This file is
# deliberately conservative: it keeps every plugin package the app uses whole,
# so the size win comes from unused libraries and resources, not from risky
# renaming of anything a plugin reaches by reflection or JNI.

-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions

# Crashlytics: readable stack traces
-keep public class * extends java.lang.Exception

# Firebase (core, messaging, crashlytics) and Google Play services / Maps
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Flutter plugin packages (reflection / JNI / registrant)
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }   # flutter_local_notifications (Gson models)
-keep class com.llfbandit.record.** { *; }                      # record
-keep class xyz.luan.audioplayers.** { *; }                     # audioplayers
-keep class com.baseflow.geolocator.** { *; }                   # geolocator
-keep class com.baseflow.permissionhandler.** { *; }            # permission_handler
-keep class dev.steenbakker.mobile_scanner.** { *; }            # mobile_scanner
-keep class com.google.mlkit.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }        # flutter_secure_storage
-keep class com.google.crypto.tink.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class androidx.biometric.** { *; }                        # local_auth
-keep class io.flutter.plugins.localauth.** { *; }
-keep class jp.espresso3389.pdfrx.** { *; }                     # pdfrx (pdfium JNI)
-keep class net.jonhanson.flutter_native_splash.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.crypto.tink.**

# Gson (used by flutter_local_notifications): keep generic type info
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# App code reached over method channels (OTA install, version lookup)
-keep class com.delwaqty.app.** { *; }

# Kotlin / coroutines
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# Play Core deferred components (referenced by Flutter, not bundled)
-dontwarn com.google.android.play.core.**
