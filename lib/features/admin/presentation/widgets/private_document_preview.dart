import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Private bytes stay inside the app. No signed or external URL is created.
class PrivateDocumentPreview extends StatefulWidget {
  const PrivateDocumentPreview({
    super.key,
    required this.path,
    required this.load,
    this.onReady,
  });
  final VoidCallback? onReady;
  final String path;
  final Future<Uint8List> Function(String path) load;

  @override
  State<PrivateDocumentPreview> createState() => _PrivateDocumentPreviewState();
}

class _PrivateDocumentPreviewState extends State<PrivateDocumentPreview> {
  late Future<Uint8List> _bytes;
  bool _reportedReady = false;

  void _ready() {
    if (_reportedReady) return;
    _reportedReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    _bytes = Future.sync(() => widget.load(widget.path));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 190,
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _bytes = Future.sync(() => widget.load(widget.path)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retry),
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null)
            return const Center(child: CircularProgressIndicator());
          final isPdf =
              bytes.length > 4 &&
              bytes[0] == 37 &&
              bytes[1] == 80 &&
              bytes[2] == 68 &&
              bytes[3] == 70;
          if (isPdf)
            return PdfViewer.data(
              bytes,
              sourceName: widget.path,
              params: PdfViewerParams(
                onViewerReady: (_, _) => _ready(),
                linkHandlerParams: PdfLinkHandlerParams(
                  onLinkTap: (_) {},
                  enableAutoLinkDetection: false,
                ),
              ),
            );
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              frameBuilder: (_, child, frame, synchronouslyLoaded) {
                if (synchronouslyLoaded || frame != null) _ready();
                return child;
              },
              errorBuilder: (_, _, _) => Center(child: Text(l10n.errorLoading)),
            ),
          );
        },
      ),
    );
  }
}
