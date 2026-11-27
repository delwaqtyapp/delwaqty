# R8 keep rules for release builds (minify + shrink enabled).
# Flutter's own rules ship with the Flutter Gradle plugin; the rules below
# cover the reflection-heavy libraries this app uses.

# Firebase / Crashlytics: keep line numbers so stack traces stay readable.
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }

# Kotlin / coroutines metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# Play Core deferred components (referenced by Flutter, not bundled)
-dontwarn com.google.android.play.core.**

# MainActivity method channels (OTA / install helpers)
-keep class com.delwaqty.app.MainActivity { *; }
