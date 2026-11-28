import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/domain/usecases/profile/profile_usecases.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Picks a photo (gallery or camera), uploads it and saves it as the user's
/// avatar. [onBusy] reports the upload state so the caller can show progress.
Future<void> pickAndUploadAvatar({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required AppLocalizations l10n,
  required ValueChanged<bool> onBusy,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusSheet),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorScheme.outlineVariant,
              borderRadius: AppSpacing.borderRadiusFull,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.chooseFromGallery),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.takePhoto),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  try {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (file == null || !context.mounted) return;

    onBusy(true);
    final bytes = await file.readAsBytes();
    final url = await ref
        .read(uploadAvatarUseCaseProvider)
        .call(
          userId: userId,
          bytes: bytes,
          fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
    if (!context.mounted) return;
    await ref
        .read(updateProfileUseCaseProvider)
        .call(userId: userId, data: {'avatar_url': url});
    if (context.mounted) {
      context.showAppSnackBar(l10n.success);
    }
  } catch (e) {
    if (context.mounted) {
      context.showAppSnackBar(appErrorText(context, e));
    }
  } finally {
    onBusy(false);
  }
}
