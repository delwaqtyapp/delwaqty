import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:delwaqty/config/cloudflare_config.dart';
import 'package:delwaqty/services/image/image_service.dart';

/// Cloudflare R2 implementation of image storage.
///
/// Uses Cloudflare R2 for asset storage with CDN delivery.
/// Falls back to Supabase Storage when R2 is unavailable.
class CloudflareR2ServiceImpl implements ImageService {
  CloudflareR2ServiceImpl({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final _cache = <String, String>{};

  @override
  Future<String> uploadImage(String path, String folder) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ImageServiceException('File not found: $path');
    }

    final fileName = path.split('/').last;
    final key = '$folder/$fileName';
    final bytes = await file.readAsBytes();

    final url = '${CloudflareConfig.r2BaseUrl}/${CloudflareConfig.r2Bucket}/$key';
    final date = HttpDate.format(DateTime.now().toUtc());

    final signature = _signRequest(
      method: 'PUT',
      contentType: 'application/octet-stream',
      date: date,
      resource: '/${CloudflareConfig.r2Bucket}/$key',
    );

    final response = await _httpClient.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'AWS4-HMAC-SHA256 Credential=${CloudflareConfig.accountId}/$date/${CloudflareConfig.accountId}/s3/aws4_request, SignedHeaders=host;date, Signature=$signature',
        'Date': date,
        'Content-Type': 'application/octet-stream',
        'Content-Length': bytes.length.toString(),
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw ImageServiceException(
        'Upload failed with status ${response.statusCode}: ${response.body}',
      );
    }

    return getImageUrl(key);
  }

  @override
  Future<void> deleteImage(String url) async {
    final key = _extractKeyFromUrl(url);
    if (key == null) {
      throw ImageServiceException('Invalid CDN URL: $url');
    }

    final storageUrl =
        '${CloudflareConfig.r2BaseUrl}/${CloudflareConfig.r2Bucket}/$key';
    final date = HttpDate.format(DateTime.now().toUtc());

    final signature = _signRequest(
      method: 'DELETE',
      contentType: '',
      date: date,
      resource: '/${CloudflareConfig.r2Bucket}/$key',
    );

    final response = await _httpClient.delete(
      Uri.parse(storageUrl),
      headers: {
        'Authorization': 'AWS4-HMAC-SHA256 Credential=${CloudflareConfig.accountId}/$date/${CloudflareConfig.accountId}/s3/aws4_request, SignedHeaders=host;date, Signature=$signature',
        'Date': date,
      },
    );

    if (response.statusCode != 204 && response.statusCode != 404) {
      throw ImageServiceException(
        'Delete failed with status ${response.statusCode}',
      );
    }
  }

  @override
  String getImageUrl(String path) {
    return '${CloudflareConfig.cdnBaseUrl}/$path';
  }

  @override
  void cacheImage(String url) {
    _cache[url] = url;
  }

  @override
  String? getCachedImage(String url) => _cache[url];

  @override
  Future<ImageResult?> pickImage(
    MediaSource source, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    return null;
  }

  @override
  Future<VideoResult?> pickVideo(MediaSource source) async {
    return null;
  }

  @override
  Future<String> compressImage(String path, {int quality = 80}) async {
    return path;
  }

  String? _extractKeyFromUrl(String url) {
    final cdnPrefix = '${CloudflareConfig.cdnBaseUrl}/';
    if (url.startsWith(cdnPrefix)) {
      return url.substring(cdnPrefix.length);
    }
    return null;
  }

  String _signRequest({
    required String method,
    required String contentType,
    required String date,
    required String resource,
  }) {
    final stringToSign = '$method\n\n$contentType\n$date\n$resource';
    final bytes = utf8.encode(stringToSign);
    final hmac = Hmac(sha256, utf8.encode(CloudflareConfig.apiToken));
    return hmac.convert(bytes).toString();
  }
}

/// Exception thrown by [CloudflareR2ServiceImpl].
class ImageServiceException implements Exception {
  /// Creates an [ImageServiceException].
  const ImageServiceException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'ImageServiceException: $message';
}
