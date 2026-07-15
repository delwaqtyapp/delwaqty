/// Source from which to pick an image or video.
enum MediaSource {
  /// Device camera.
  camera,

  /// Device photo gallery.
  gallery,
}

/// Result of an image pick operation.
class ImageResult {
  /// Creates an [ImageResult].
  const ImageResult({
    required this.path,
    required this.width,
    required this.height,
    this.fileSize,
    this.mimeType,
  });

  /// Local file path of the selected image.
  final String path;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// File size in bytes.
  final int? fileSize;

  /// MIME type of the image (e.g. "image/jpeg").
  final String? mimeType;
}

/// Result of a video pick operation.
class VideoResult {
  /// Creates a [VideoResult].
  const VideoResult({
    required this.path,
    required this.duration,
    this.fileSize,
    this.mimeType,
  });

  /// Local file path of the selected video.
  final String path;

  /// Duration of the video.
  final Duration duration;

  /// File size in bytes.
  final int? fileSize;

  /// MIME type of the video (e.g. "video/mp4").
  final String? mimeType;
}

/// Abstract interface for image picking, compression, upload, and caching.
///
/// Provides a unified API for camera/gallery image selection, compression,
/// cloud upload, and local caching.
abstract interface class ImageService {
  /// Opens a picker for the user to select an image from [source].
  ///
  /// Returns null if the user cancels. Optionally constrains the picked
  /// image to [maxWidth] and [maxHeight] pixels.
  Future<ImageResult?> pickImage(
    MediaSource source, {
    int? maxWidth,
    int? maxHeight,
  });

  /// Opens a picker for the user to select a video from [source].
  ///
  /// Returns null if the user cancels.
  Future<VideoResult?> pickVideo(MediaSource source);

  /// Compresses the image at [path] to the given JPEG [quality] (1-100).
  ///
  /// Returns the local file path of the compressed image.
  Future<String> compressImage(String path, {int quality = 80});

  /// Uploads the image at [path] to the specified cloud [folder].
  ///
  /// Returns the public URL of the uploaded image.
  Future<String> uploadImage(String path, String folder);

  /// Deletes the image at the given cloud [url].
  Future<void> deleteImage(String url);

  /// Returns the full URL for the image at the given storage [path].
  String getImageUrl(String path);

  /// Caches the image at the given [url] locally for offline access.
  void cacheImage(String url);

  /// Returns the local file path of the cached image for [url], or null
  /// if not cached.
  String? getCachedImage(String url);
}
