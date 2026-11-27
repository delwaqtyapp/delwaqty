import 'package:flutter/material.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/domain/entities/app_notification.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Shared localization, icon, color, and relative-time helpers for notifications
/// across both [GlassNotificationsMenuController] and [NotificationCenterPage].
class NotificationLocalizer {
  NotificationLocalizer._();

  static String title(BuildContext context, AppNotification n) {
    final l10n = AppLocalizations.of(context);
    final raw = n.title.trim();
    final lower = raw.toLowerCase();

    if (lower == 'new support message') return l10n.notifNewSupportMessageTitle;
    if (lower == 'new customer message')
      return l10n.notifNewCustomerMessageTitle;
    if (lower == 'support chat escalated')
      return l10n.notifSupportEscalatedTitle;
    if (lower == 'emergency support request')
      return l10n.notifEmergencySupportTitle;
    if (lower == 'new complaint') return l10n.notifNewComplaintTitle;
    if (lower == 'complaint update') return l10n.notifComplaintUpdateTitle;
    if (lower.contains('verification') && lower.contains('approved')) {
      return l10n.notifVerificationApprovedTitle;
    }
    if (lower.contains('verification') &&
        (lower.contains('rejected') || lower.contains('declined'))) {
      return l10n.notifVerificationRejectedTitle;
    }
    if (lower.contains('top-up') && lower.contains('approved')) {
      return l10n.notifTopupApprovedTitle;
    }
    if (lower.contains('wallet') &&
        (lower.contains('credited') || lower.contains('top-up'))) {
      return l10n.notifWalletCreditedTitle;
    }
    if (lower.contains('service') && lower.contains('approved')) {
      return l10n.notifServiceApprovedTitle;
    }
    if (lower.contains('service') && lower.contains('rejected')) {
      return l10n.notifServiceRejectedTitle;
    }

    return raw;
  }

  static String body(BuildContext context, AppNotification n) {
    final l10n = AppLocalizations.of(context);
    final raw = n.body.trim();
    final lower = raw.toLowerCase();

    if (lower == 'you have a new reply in support chat') {
      return l10n.notifNewSupportMessageBody;
    }
    if (lower == 'a customer replied in support chat') {
      return l10n.notifNewCustomerMessageBody;
    }
    if (lower == 'your chat has been escalated to the next support level.') {
      return l10n.notifSupportEscalatedBody;
    }
    if (lower == 'immediate assistance required.') {
      return l10n.notifEmergencySupportBody;
    }
    if (lower == 'a new complaint requires review') {
      return l10n.notifNewComplaintBody;
    }
    if (lower.startsWith('your complaint status changed to')) {
      return l10n.notifComplaintUpdateBody;
    }
    if (lower.contains('verification') && lower.contains('approved')) {
      return l10n.notifVerificationApprovedBody;
    }
    if (lower.contains('top-up') && lower.contains('approved')) {
      return l10n.notifTopupApprovedBody;
    }

    return raw;
  }

  static String formatRelativeTime(DateTime dateTime, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgoShort(diff.inMinutes);
    if (diff.inHours < 24) return l10n.hoursAgoShort(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgoShort(diff.inDays);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  static Color typeColor(NotificationType type, ColorScheme colorScheme) {
    switch (type) {
      case NotificationType.otaUpdate:
      case NotificationType.system:
      case NotificationType.info:
        return colorScheme.primary;
      case NotificationType.order:
      case NotificationType.reward:
        return AppColors.brandPurple;
      case NotificationType.payment:
      case NotificationType.success:
      case NotificationType.topupApproved:
      case NotificationType.adminTopup:
        return AppColors.successLight;
      case NotificationType.promotion:
      case NotificationType.warning:
      case NotificationType.complaint:
      case NotificationType.complaintNote:
      case NotificationType.complaintEscalated:
      case NotificationType.complaintAssigned:
        return AppColors.warningLight;
      case NotificationType.service:
        return AppColors.serviceRestaurant;
      case NotificationType.account:
      case NotificationType.adminManagement:
      case NotificationType.moderation:
      case NotificationType.approval:
      case NotificationType.providerProfile:
        return colorScheme.tertiary;
      case NotificationType.security:
      case NotificationType.emergency:
      case NotificationType.emergencyAlert:
      case NotificationType.emergencyResolved:
        return AppColors.errorLight;
      case NotificationType.message:
      case NotificationType.chatReply:
      case NotificationType.chatAssigned:
      case NotificationType.chatEscalated:
      case NotificationType.chatClosed:
        return colorScheme.secondary;
      case NotificationType.reminder:
        return AppColors.orderPreparing;
    }
  }

  static IconData typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.otaUpdate:
        return Icons.system_update_alt_rounded;
      case NotificationType.system:
      case NotificationType.info:
        return Icons.info_outline_rounded;
      case NotificationType.order:
        return Icons.shopping_bag_outlined;
      case NotificationType.payment:
      case NotificationType.topupApproved:
      case NotificationType.adminTopup:
        return Icons.payment_rounded;
      case NotificationType.promotion:
        return Icons.local_offer_outlined;
      case NotificationType.service:
        return Icons.home_repair_service_outlined;
      case NotificationType.account:
        return Icons.person_outline_rounded;
      case NotificationType.security:
        return Icons.shield_outlined;
      case NotificationType.message:
      case NotificationType.chatReply:
      case NotificationType.chatAssigned:
      case NotificationType.chatEscalated:
      case NotificationType.chatClosed:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.success:
        return Icons.check_circle_outline_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.reward:
        return Icons.card_giftcard_rounded;
      case NotificationType.complaint:
      case NotificationType.complaintNote:
      case NotificationType.complaintEscalated:
      case NotificationType.complaintAssigned:
        return Icons.report_outlined;
      case NotificationType.emergency:
      case NotificationType.emergencyAlert:
      case NotificationType.emergencyResolved:
        return Icons.emergency_rounded;
      case NotificationType.adminManagement:
      case NotificationType.moderation:
      case NotificationType.approval:
      case NotificationType.providerProfile:
        return Icons.admin_panel_settings_outlined;
    }
  }
}
