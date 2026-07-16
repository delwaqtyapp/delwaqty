import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/image/image_service.dart';

final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageServiceImpl();
});

/// Mock implementation of [ImageService] for development.
///
/// Returns placeholder data for all image operations. No actual file I/O
/// or network calls are performed.
class ImageServiceImpl implements ImageService {
  final _cache = <String, String>{};
  static int _fileCounter = 0;

  @override
  Future<ImageResult?> pickImage(
    MediaSource source, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    _fileCounter++;
    return ImageResult(
      path: '/mock/images/pick_$_fileCounter.jpg',
      width: maxWidth ?? 1024,
      height: maxHeight ?? 768,
      fileSize: 204800,
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<VideoResult?> pickVideo(MediaSource source) async {
    _fileCounter++;
    return VideoResult(
      path: '/mock/videos/pick_$_fileCounter.mp4',
      duration: const Duration(seconds: 30),
      fileSize: 10485760,
      mimeType: 'video/mp4',
    );
  }

  @override
  Future<String> compressImage(String path, {int quality = 80}) async {
    return '${path}_compressed_q$quality.jpg';
  }

  @override
  Future<String> uploadImage(String path, String folder) async {
    return 'https://mock-storage.delwaqty.com/$folder/${path.split('/').last}';
  }

  @override
  Future<void> deleteImage(String url) async {}

  @override
  String getImageUrl(String path) {
    return 'https://mock-storage.delwaqty.com/$path';
  }

  @override
  void cacheImage(String url) {
    _cache[url] = '/mock/cache/${url.hashCode}';
  }

  @override
  String? getCachedImage(String url) {
    return _cache[url];
  }
}
