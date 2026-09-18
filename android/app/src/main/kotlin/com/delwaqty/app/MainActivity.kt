package com.delwaqty.app

import android.annotation.SuppressLint
import android.location.Address
import android.location.Geocoder
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "com.delwaqty.app/geocoder"
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
    }
}