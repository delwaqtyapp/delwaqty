import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/localization/locale_provider.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/core/module/feature_registry.dart';
import 'package:delwaqty/core/theme/theme_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'app_shell.dart';

/// Opens the customer side menu as a floating, frosted-glass bubble that bursts
/// from the tapped menu button (anchor rect) instead of sliding from the edge.
///
/// The overlay is fully transparent: the page behind stays bright and the only
/// visual is the small floating panel (iPhone-style glass).
class GlassSideMenuController {
  GlassSideMenuController._();

  static OverlayEntry? _entry;

  static bool get isOpen => _entry != null;

  @visibleForTesting
  static void resetForTesting() {
    _entry?.remove();
    _entry = null;
  }

  static void open(
    BuildContext context,
    WidgetRef ref, {
    Rect? anchor,
    List<DrawerEntry>? drawerEntries,
  }) {
    if (_entry != null) return;

    final l10n = AppLocalizations.of(context);
    final authState = ref.read(authStateProvider);
    final themeMode = ref.read(themeModeProvider);
    final locale = ref.read(localeProvider);
    final entries = drawerEntries ?? FeatureRegistry.instance.allDrawerEntries;

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => GlassSideMenuOverlay(
        authState: authState,
        l10n: l10n,
        themeMode: themeMode,
        locale: locale,
        ref: ref,
        drawerEntries: entries,
        anchor: anchor,
        onDismiss: () {
          entry.remove();
          _entry = null;
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }
}

class GlassSideMenuOverlay extends StatefulWidget {
  const GlassSideMenuOverlay({
    super.key,
    required this.authState,
    required this.l10n,
    required this.themeMode,
    required this.locale,
    required this.ref,
    required this.drawerEntries,
    this.anchor,
    required this.onDismiss,
  });

  final AuthState authState;
  final AppLocalizations l10n;
  final ThemeMode themeMode;
  final Locale locale;
  final WidgetRef ref;
  final List drawerEntries;
  final Rect? anchor;
  final VoidCallback onDismiss;

  @override
  State<GlassSideMenuOverlay> createState() => _GlassSideMenuOverlayState();
}

class _GlassSideMenuOverlayState extends State<GlassSideMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _pop;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pop = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _controller.reverse().whenComplete(widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safeTop = MediaQuery.paddingOf(context).top;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final panelWidth = (size.width * 0.66).clamp(204.0, 244.0);
    const margin = 12.0;

    final anchor = widget.anchor;
    double left, top;
    if (anchor != null) {
      left = isRtl
          ? (anchor.right - panelWidth).clamp(
              margin,
              size.width - margin - panelWidth,
            )
          : anchor.left.clamp(margin, size.width - margin - panelWidth);
      top = (anchor.bottom + 4).clamp(safeTop + 8, size.height * 0.55);
    } else {
      left = isRtl ? size.width - margin - panelWidth : margin;
      top = safeTop + 8;
    }

    final maxPanelHeight = (size.height - top - size.height * 0.14).clamp(
      240.0,
      size.height,
    );

    final anchorCenterX = anchor?.center.dx;
    final alignX = anchorCenterX == null
        ? (isRtl ? 1.0 : -0.6)
        : (((anchorCenterX - left) / panelWidth) * 2 - 1).clamp(-1.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          AnimatedBuilder(
            animation: _pop,
            child: GlassMenuPanel(
              authState: widget.authState,
              l10n: widget.l10n,
              themeMode: widget.themeMode,
              locale: widget.locale,
              ref: widget.ref,
              drawerEntries: widget.drawerEntries,
              width: panelWidth,
              maxHeight: maxPanelHeight,
              onRequestClose: _close,
            ),
            builder: (_, child) {
              final t = _pop.value;
              return Positioned(
                left: left,
                top: top,
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: FractionalTranslation(
                    translation: Offset(
                      (isRtl ? 0.06 : -0.06) * (1 - t),
                      -0.05 * (1 - t),
                    ),
                    child: Transform.scale(
                      scale: 0.35 + 0.65 * t,
                      alignment: Alignment(alignX, -0.9),
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}