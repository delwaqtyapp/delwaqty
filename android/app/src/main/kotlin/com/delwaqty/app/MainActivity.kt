package com.delwaqty.app

import android.annotation.SuppressLint
import android.content.Intent
import android.location.Address
import android.location.Geocoder
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.delwaqty.app/geocoder"
        private const val OTA_CHANNEL = "com.delwaqty.app/ota"
    }

    @SuppressLint("MissingPermission")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "reverseGeocode") {
                    val lat = call.argument<Double>("lat") ?: run {
                        result.error("bad_args", "lat required", null); return@setMethodCallHandler
                    }
                    val lng = call.argument<Double>("lng") ?: run {
                        result.error("bad_args", "lng required", null); return@setMethodCallHandler
                    }
                    val language = call.argument<String>("language") ?: "ar"
                    val maxResults = call.argument<Int>("maxResults") ?: 1
                    try {
                        val geocoder = Geocoder(this, Locale(language))
                        val addresses: List<Address> =
                            geocoder.getFromLocation(lat, lng, maxResults) ?: emptyList()
                        val first = addresses.firstOrNull()
                        if (first == null) {
                            result.success(null)
                        } else {
                            val lines = first.getAddressLine(0)?.let { listOf(it) } ?: emptyList()
                            result.success(mapOf(
                                "addressLine" to first.getAddressLine(0),
                                "featureName" to first.featureName,
                                "subLocality" to first.subLocality,
                                "locality" to first.locality,
                                "subAdminArea" to first.subAdminArea,
                                "adminArea" to first.adminArea,
                                "countryName" to first.countryName,
                                "postalCode" to first.postalCode,
                                "lines" to lines,
                            ))
                        }
                    } catch (e: Exception) {
                        result.error("geocoder_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "canRequestPackageInstalls") {
                    result.success(packageManager.canRequestPackageInstalls())
                } else if (call.method == "getInstalledVersionCode") {
                    val pkg = call.argument<String>("packageName")
                    if (pkg == null) {
                        result.error("bad_args", "packageName required", null); return@setMethodCallHandler
                    }
                    try {
                        val info = packageManager.getPackageInfo(pkg, 0)
                        val code = if (android.os.Build.VERSION.SDK_INT >= 28) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION") info.versionCode.toLong()
                        }
                        result.success(code)
                    } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("query_failed", e.message, null)
                    }
                } else if (call.method == "launchApp") {
                    val pkg = call.argument<String>("packageName")
                    if (pkg == null) {
                        result.error("bad_args", "packageName required", null); return@setMethodCallHandler
                    }
                    val intent = packageManager.getLaunchIntentForPackage(pkg)
                    if (intent == null) {
                        result.success(false)
                    } else {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                } else if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path required", null); return@setMethodCallHandler
                    }
                    // Defense in depth: the Play build removes
                    // REQUEST_INSTALL_PACKAGES from the manifest, so refuse to
                    // install anything when it is not declared.
                    val declaresInstall = try {
                        val info = packageManager.getPackageInfo(
                            packageName, android.content.pm.PackageManager.GET_PERMISSIONS)
                        info.requestedPermissions?.contains(
                            android.Manifest.permission.REQUEST_INSTALL_PACKAGES) == true
                    } catch (e: Exception) { false }
                    if (!declaresInstall) {
                        result.error("disabled_in_play_build", "install not available", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val apkFile = java.io.File(path)
                        if (!apkFile.exists()) {
                            result.error("missing_file", "apk not found", null); return@setMethodCallHandler
                        }
                        // If the app is not yet allowed to install unknown apps,
                        // route the user to the system settings page directly.
                        if (!packageManager.canRequestPackageInstalls()) {
                            val settingsIntent = Intent(
                                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(settingsIntent)
                            result.error(
                                "needs_install_permission",
                                "user must allow unknown app sources",
                                null,
                            ); return@setMethodCallHandler
                        }
                        val apkUri: Uri = androidx.core.content.FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            apkFile,
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}