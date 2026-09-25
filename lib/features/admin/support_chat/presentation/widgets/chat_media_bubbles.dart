import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:delwaqty/features/admin/support_chat/presentation/chat_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ChatAttachmentImage extends ConsumerStatefulWidget {
  const ChatAttachmentImage({
    super.key,
    required this.path,
    required this.isMe,
  });

  final String path;
  final bool isMe;

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

  @override
  Widget build(BuildContext context) {
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
    return ClipRRect(
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

class ChatAudioMessage extends ConsumerStatefulWidget {
  const ChatAudioMessage({
    super.key,
    required this.path,
    required this.isMe,
    required this.audioPlayer,
  });

  final String path;
  final bool isMe;
  final AudioPlayer audioPlayer;

  @override
  ConsumerState<ChatAudioMessage> createState() => _ChatAudioMessageState();
}

class _ChatAudioMessageState extends ConsumerState<ChatAudioMessage> {
  bool _playing = false;
  String? _url;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _loadUrl();
    _sub = widget.audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    widget.audioPlayer.stop();
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
      await widget.audioPlayer.pause();
      setState(() => _playing = false);
      return;
    }
    if (_url == null) return;
    await widget.audioPlayer.stop();
    await widget.audioPlayer.play(UrlSource(_url!));
    setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = widget.isMe ? cs.onPrimary : cs.onSurface;
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: _url == null ? null : _toggle,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _playing ? Icons.stop_circle_outlined : Icons.play_circle_fill_rounded,
            color: _url == null ? fg.withValues(alpha: 0.4) : fg,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            _url == null ? l10n.tapToPlay : l10n.tapToPlay,
            style: TextStyle(color: fg, fontSize: 12),
          ),
        ],
      ),
    );
  }
}