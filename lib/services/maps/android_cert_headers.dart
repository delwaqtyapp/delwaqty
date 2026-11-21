import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// SHA-1 of the release signing certificate used for the OTA APKs.
///
/// Google Maps webservice calls (Directions / Places / Geocoding / Static)
/// travel over plain HTTPS, so an Android-app restriction on the API key
/// only authorises them when the app identity is sent explicitly via the
/// `X-Android-Package` / `X-Android-Cert` headers.
const String kAndroidReleaseCertSha1 =
    'F12D4D9E5393AA7EF35B9865DDF48785F4689CD0';

Map<String, String>? _cachedHeaders;

/// Returns the Android app-identity headers for Maps webservice calls, or an
/// empty map on non-Android platforms. The package name is read at runtime so
/// every flavor (customer / admin / driver / provider) reports its own
/// applicationId.
Future<Map<String, String>> androidMapsCertHeaders() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const {};
  }
  final cached = _cachedHeaders;
  if (cached != null) return cached;
  final info = await PackageInfo.fromPlatform();
  final headers = <String, String>{
    'X-Android-Package': info.packageName,
    'X-Android-Cert': kAndroidReleaseCertSha1,
  };
  _cachedHeaders = headers;
  return headers;
}
