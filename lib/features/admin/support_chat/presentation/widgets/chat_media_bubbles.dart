import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ChatAttachmentImage extends ConsumerStatefulWidget {
  const ChatAttachmentImage({
    super.key,
    required this.path,
    required this.fgColor,
    required this.bgColor,
  });

  final String path;
  final Color fgColor;
  final Color bgColor;

  @override
  ConsumerState<ChatAttachmentImage> createState() => _ChatAttachmentImageState();
}

class _ChatAttachmentImageState extends ConsumerState<ChatAttachmentImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final url = await repo.signedUrl(widget.path);
      if (mounted) setState(() => _url = url);
    } catch (_) {}
  }

  Future<void> _openFullscreen(String url) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImageViewerPage(url: url, bgColor: widget.bgColor),
      ),
    );
  }

  Future<void> _download(String url) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final dir = await getApplicationDocumentsDirectory();
      final name = widget.path.split('/').last;
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(response.bodyBytes);
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.imageDownloaded}: ${file.path}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final border = BorderRadius.circular(12);
    if (_url == null) {
      return Container(
        width: 200,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: border,
          color: cs.surfaceContainerHighest,
        ),
        child: const Center(child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
      );
    }
    return GestureDetector(
      onTap: () => _openFullscreen(_url!),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: border,
            child: Image.network(
              _url!,
              width: 200,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (context, e, _) => Container(
                width: 200,
                height: 140,
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _glassIconButton(
                  icon: Icons.download_rounded,
                  color: widget.fgColor,
                  tooltip: l10n.downloadImage,
                  onTap: () => _download(_url!),
                ),
                const SizedBox(width: 4),
                _glassIconButton(
                  icon: Icons.zoom_in_rounded,
                  color: widget.fgColor,
                  tooltip: l10n.openImage,
                  onTap: () => _openFullscreen(_url!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.url, required this.bgColor});

  final String url;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.openImage),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, e, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatAttachmentVideo extends StatelessWidget {
  const ChatAttachmentVideo({
    super.key,
    required this.path,
    required this.isMe,
  });

  final String path;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = isMe ? cs.onPrimary : cs.onSurface;
    final fileName = path.split('/').last;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.videocam_rounded, color: fg),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fileName,
            style: TextStyle(color: fg, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Each voice bubble owns its own AudioPlayer so play states never bleed.
class ChatAudioMessage extends ConsumerStatefulWidget {
  const ChatAudioMessage({
    super.key,
    required this.path,
    required this.isMe,
  });

  final String path;
  final bool isMe;

  @override
  ConsumerState<ChatAudioMessage> createState() => _ChatAudioMessageState();
}

class _ChatAudioMessageState extends ConsumerState<ChatAudioMessage> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  String? _url;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _loadUrl();
    _sub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    final repo = ref.read(chatRepositoryProvider);
    try {
      final url = await repo.signedUrl(widget.path);
      if (mounted) setState(() => _url = url);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    if (_url == null) return;
    await _player.stop();
    await _player.play(UrlSource(_url!));
    setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = widget.isMe ? cs.onPrimary : cs.onSurface;
    final l10n = AppLocalizations.of(context);
    final canPlay = _url != null;
    return InkWell(
      onTap: canPlay ? _toggle : null,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _playing ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded,
            color: canPlay ? fg : fg.withValues(alpha: 0.4),
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            _playing ? l10n.tapToStop : l10n.tapToPlay,
            style: TextStyle(color: canPlay ? fg : fg.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}