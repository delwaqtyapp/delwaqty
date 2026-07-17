import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_icons.dart';
import 'package:delwaqty/shared/widgets/app_snackbar.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    required this.targetId,
    required this.type,
    this.size = 28,
    super.key,
  });

  final String targetId;
  final FavoriteType type;
  final double size;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _isFav = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  @override
  void didUpdateWidget(FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId ||
        oldWidget.type != widget.type) {
      _checkFavorite();
    }
  }

  Future<void> _checkFavorite() async {
    try {
      final auth = ref.read(authStateProvider);
      if (auth is! AuthAuthenticated && auth is! AuthGuest) {
        setState(() {
          _isFav = false;
          _loading = false;
        });
        return;
      }
      final repo = ref.read(favoriteRepositoryProvider);
      final result = await repo.isFavorite(widget.targetId, widget.type);
      if (mounted) setState(() { _isFav = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _isFav = false; _loading = false; });
    }
  }

  Future<void> _toggle() async {
    try {
      final auth = ref.read(authStateProvider);
      if (auth is! AuthAuthenticated && auth is! AuthGuest) {
        if (mounted) {
          AppSnackbar.info(
            context,
            message: AppLocalizations.of(context).login,
          );
        }
        return;
      }

      final l10n = AppLocalizations.of(context);
      setState(() => _isFav = !_isFav);

      final repo = ref.read(favoriteRepositoryProvider);
      await repo.toggleFavorite(targetId: widget.targetId, type: widget.type);
      if (mounted) {
        AppSnackbar.success(
          context,
          message: _isFav ? l10n.addedToFavorites : l10n.removedFromFavorites,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isFav = !_isFav);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isFav ? AppIcons.actionFavouriteFilled : AppIcons.actionFavourite,
          key: ValueKey(_isFav),
          size: widget.size,
          color: _isFav
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
