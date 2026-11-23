import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';

import 'dart:async';

/// OTA update channel backed by GitHub Releases.
///
/// The development release keeps one stable tag. Manifest requests bypass
/// caches, while each build uses new APK asset names and a verified SHA-256.
const kOtaRepoOwner = 'delwaqtyapp';
const kOtaRepoName = 'delwaqty';
const kOtaApiLatest =
    'https://api.github.com/repos/delwaqtyapp/delwaqty/releases/latest';
const kOtaDownloadBaseUrl =
    'https://github.com/delwaqtyapp/delwaqty/releases/download/';
const kOtaFallbackInterval = Duration(hours: 8);

class OtaChannelConfig {
  const OtaChannelConfig({
    required this.version,
    required this.versionName,
    required this.apk,
    required this.notes,
    this.sha256,
  });

  final int version;
  final String versionName;
  final String apk;
  final String notes;

  /// SHA-256 of the published APK, hex-encoded. Optional so an older
  /// manifest without the field still parses, but [downloadAndInstallLatest]
  /// refuses to install when it is absent.
  final String? sha256;
}

class OtaManifest {
  const OtaManifest({required this.channels, required this.checkedAt});

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
          sha256: v['sha256'] as String?,
        );
      });
    }
    return OtaManifest(channels: channels, checkedAt: DateTime.now());
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

/// Mutable release metadata must not reuse a cached response. APK assets use
/// build-specific names instead, so a download remains pinned to its manifest.
Uri otaFreshUri(String url, {int? requestId}) {
  final uri = Uri.parse(url);
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'ota': '${requestId ?? DateTime.now().microsecondsSinceEpoch}',
    },
  );
}

/// Finds the latest release tag via the GitHub API (never cached).
Future<String?> _fetchLatestTag() async {
  try {
    final response = await http
        .get(otaFreshUri(kOtaApiLatest))
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
    final uri = otaFreshUri('$kOtaDownloadBaseUrl$tag/versions.json');
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
    return OtaCheckResult(
      current: current,
      latest: current,
      needsUpdate: false,
    );
  }
  final channel = manifest.forFlavor(flavor);
  final latest = channel?.version ?? current;
  return OtaCheckResult(
    current: current,
    latest: latest,
    needsUpdate: latest > current,
  );
}

/// Result of [downloadLatestApk]: either a verified APK on disk or an error
/// code (`missing_checksum`, `checksum_mismatch`, or null for a plain
/// network failure).
class OtaDownloadResult {
  const OtaDownloadResult({this.file, this.error});

  final File? file;
  final String? error;

  bool get ok => file != null;
}

/// Downloads the latest APK for [flavor] into the app cache and verifies its
/// SHA-256. It does NOT start the installer, so the caller can keep the file
/// and offer an "Install" button. An already-downloaded, verified file is
/// reused instead of being fetched again.
///
/// [onProgress] reports the actual download fraction (0..1) as chunks arrive.
Future<OtaDownloadResult> downloadLatestApk(
  AppFlavor flavor, {
  void Function(double fraction)? onProgress,
}) async {
  try {
    final tag = await _fetchLatestTag();
    if (tag == null) return const OtaDownloadResult();
    final manifest = await fetchOtaManifestForTag(tag);
    final channel = manifest?.forFlavor(flavor);
    if (channel == null || channel.apk.isEmpty) {
      return const OtaDownloadResult();
    }

    final dir = await getApplicationCacheDirectory();
    final target = File('${dir.path}/${channel.apk}');
    final expectedHash = channel.sha256?.trim().toLowerCase() ?? '';
    if (expectedHash.isEmpty) {
      // A release without a published digest cannot be trusted: installing
      // it would let anyone who can poison the CDN or the release asset run
      // code inside this app.
      return const OtaDownloadResult(error: 'missing_checksum');
    }
    if (!target.existsSync() || target.lengthSync() == 0) {
      final uri = Uri.parse('$kOtaDownloadBaseUrl$tag/${channel.apk}');
      final streamed = await http.Client()
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (streamed.statusCode != 200) {
        unawaited(streamed.stream.drain<void>());
        return const OtaDownloadResult();
      }

      // Write to a temp file and rename, so an interrupted download is never
      // mistaken for a finished one on the next attempt.
      final partial = File('${target.path}.part');
      final total = streamed.contentLength;
      final sink = partial.openWrite();
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
      await partial.rename(target.path);
    }

    if (!await verifyArtifactChecksum(target, expectedHash)) {
      // Tampered or truncated artifact: delete it and refuse.
      if (target.existsSync()) {
        try {
          await target.delete();
        } catch (_) {}
      }
      return const OtaDownloadResult(error: 'checksum_mismatch');
    }

    onProgress?.call(1.0);
    return OtaDownloadResult(file: target);
  } catch (_) {
    return const OtaDownloadResult();
  }
}

/// Whether Android currently lets this app install packages
/// ("install unknown apps"). Assumed true if the platform cannot answer.
Future<bool> canRequestPackageInstalls() async {
  try {
    final allowed = await _otaMethodChannel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return allowed ?? true;
  } catch (_) {
    return true;
  }
}

/// Asks the native side to launch Android's package installer for an
/// already-downloaded [file]. Returns null on success or the native error
/// code. `needs_install_permission` means the system settings page for
/// "install unknown apps" was opened; wait for the user to come back and call
/// this again, the file is kept.
Future<String?> installDownloadedApk(File file) async {
  try {
    await _otaMethodChannel.invokeMethod('installApk', {'path': file.path});
    return null;
  } on PlatformException catch (e) {
    return e.code;
  } catch (_) {
    return 'install_failed';
  }
}

/// Convenience: download then install in one go. Returns the file size, or
/// null on failure with the error code as the second element.
Future<(int?, String?)> downloadAndInstallLatest(
  AppFlavor flavor, {
  void Function(double fraction)? onProgress,
}) async {
  final download = await downloadLatestApk(flavor, onProgress: onProgress);
  final file = download.file;
  if (file == null) return (null, download.error);
  final error = await installDownloadedApk(file);
  if (error != null) return (null, error);
  return (file.lengthSync(), null);
}

/// Streams [file] through SHA-256 and compares it with [expected].
///
/// The OTA channel downloads an APK over the network and hands it to the
/// platform installer. Without this check a compromised CDN, release asset
/// or man-in-the-middle could execute code inside the app, so the digest
/// published alongside the release must match before installation.
Future<bool> verifyArtifactChecksum(File file, String expected) async {
  if (expected.length != 64) return false;
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString().toLowerCase() == expected;
}
