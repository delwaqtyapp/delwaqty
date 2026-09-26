import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';

/// OTA update channel backed by GitHub Releases.
///
/// Strategy (cache-proof): the app first asks the GitHub API for the LATEST
/// release tag (an API response, never cached), then downloads the manifest and
/// APK from the immutable per-tag URL `/releases/download/<tag>/...`. Because a
/// brand-new tag is generated on every publish, there is deliberately no shared
/// "latest" redirect whose CDN cache could serve a stale file.
const kOtaRepoOwner = 'delwaqtyapp';
const kOtaRepoName = 'delwaqty';
const kOtaApiLatest = 'https://api.github.com/repos/delwaqtyapp/delwaqty/releases/latest';
const kOtaDownloadBaseUrl =
    'https://github.com/delwaqtyapp/delwaqty/releases/download/';
const kOtaFallbackInterval = Duration(hours: 8);

class OtaChannelConfig {
  const OtaChannelConfig({
    required this.version,
    required this.versionName,
    required this.apk,
    required this.notes,
  });

  final int version;
  final String versionName;
  final String apk;
  final String notes;
}

class OtaManifest {
  const OtaManifest({
    required this.channels,
    required this.checkedAt,
  });

  factory OtaManifest.fromJson(Map<String, dynamic> json) {
    final channels = <String, OtaChannelConfig>{};
    final rawChannels = json['channels'];
    if (rawChannels is Map<String, dynamic>) {
      rawChannels.forEach((key, value) {
        final v = value as Map<String, dynamic>;
        channels[key] = OtaChannelConfig(
          version: (v['version'] as num?)?.toInt() ?? 0,
          versionName: v['versionName'] as String? ?? '',
          apk: v['apk'] as String? ?? '',
          notes: v['notes'] as String? ?? '',
        );
      });
    }
    return OtaManifest(
      channels: channels,
      checkedAt: DateTime.now(),
    );
  }

  final Map<String, OtaChannelConfig> channels;
  final DateTime checkedAt;

  OtaChannelConfig? forFlavor(AppFlavor flavor) {
    return channels[flavor.name];
  }
}

class OtaCheckResult {
  const OtaCheckResult({
    required this.current,
    required this.latest,
    required this.needsUpdate,
  });

  final int current;
  final int latest;
  final bool needsUpdate;
}

const _otaMethodChannel = MethodChannel('com.delwaqty.app/ota');

/// Finds the latest release tag via the GitHub API (never cached).
Future<String?> _fetchLatestTag() async {
  try {
    final response = await http
        .get(Uri.parse(kOtaApiLatest))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    final tag = json['tag_name'];
    return tag is String && tag.isNotEmpty ? tag : null;
  } catch (_) {
    return null;
  }
}

/// Fetches the OTA manifest for the LATEST release. Returns null when
/// unreachable or invalid.
Future<OtaManifest?> fetchOtaManifest() async {
  final tag = await _fetchLatestTag();
  if (tag == null) return null;
  return fetchOtaManifestForTag(tag);
}

/// Fetches the OTA manifest pinned to a specific release tag.
Future<OtaManifest?> fetchOtaManifestForTag(String tag) async {
  try {
    final uri = Uri.parse('$kOtaDownloadBaseUrl$tag/versions.json');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) return null;
    return OtaManifest.fromJson(json);
  } catch (_) {
    return null;
  }
}

/// Compares the installed build against the latest channel config.
Future<OtaCheckResult> checkForOtaUpdate(AppFlavor flavor) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final current = int.tryParse(packageInfo.buildNumber) ?? 0;
  final manifest = await fetchOtaManifest();
  if (manifest == null) {
    return OtaCheckResult(current: current, latest: current, needsUpdate: false);
  }
  final channel = manifest.forFlavor(flavor);
  final latest = channel?.version ?? current;
  return OtaCheckResult(
    current: current,
    latest: latest,
    needsUpdate: latest > current,
  );
}

/// Downloads the latest APK for [flavor] into app cache, then asks the native
/// side to launch Android's package installer. Returns the download file's
/// size, or null on failure — the second element surfaces the native error
/// code (e.g. `needs_install_permission`) when installation could not start.
///
/// [onProgress] reports the actual download fraction (0..1) as chunks arrive.
Future<(int?, String?)> downloadAndInstallLatest(
  AppFlavor flavor, {
  void Function(double fraction)? onProgress,
}) async {
  try {
    final tag = await _fetchLatestTag();
    if (tag == null) return (null, null);
    final manifest = await fetchOtaManifestForTag(tag);
    final channel = manifest?.forFlavor(flavor);
    if (channel == null || channel.apk.isEmpty) return (null, null);

    final dir = await getApplicationCacheDirectory();
    final target = File('${dir.path}/${channel.apk}');
    if (!target.existsSync() || target.lengthSync() == 0) {
      final uri = Uri.parse('$kOtaDownloadBaseUrl$tag/${channel.apk}');
      final streamed = await http.Client()
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (streamed.statusCode != 200) {
        streamed.stream.drain<void>();
        return (null, null);
      }

      final total = streamed.contentLength;
      final sink = target.openWrite();
      var received = 0;
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0 && onProgress != null) {
            onProgress((received / total).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    }

    final size = target.lengthSync();
    onProgress?.call(1.0);
    try {
      await _otaMethodChannel.invokeMethod('installApk', {'path': target.path});
    } on PlatformException catch (e) {
      return (null, e.code);
    }
    return (size, null);
  } catch (_) {
    return (null, null);
  }
}