import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/category_visuals.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/admin/support_chat/domain/entities/chat_room.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Human-readable origin label for a chat room shown in the admin panel list
/// and at the top of every room page, so staff instantly know WHO opened the
/// chat (customer / driver / admin / provider + service type).
///
/// The DB stores [ChatRoom.originType] server-authoritatively (migration 099);
/// [ChatRoom.originLabel] carries the provider's service category or merchant
/// type string which we map to the current language.
String chatOriginLabel(AppLocalizations l10n, ChatRoom room) {
  switch (room.originType) {
    case 'driver':
      return l10n.chatOriginDriver;
    case 'admin':
      return l10n.chatOriginAdmin;
    case 'provider':
      final detail = _providerDetailLabel(l10n, room.originLabel);
      return detail == null
          ? l10n.chatOriginProvider
          : '${l10n.chatOriginProvider} · $detail';
    case 'customer':
    default:
      return l10n.chatOriginCustomer;
  }
}

String? _providerDetailLabel(AppLocalizations l10n, String? originLabel) {
  if (originLabel == null || originLabel.isEmpty) return null;
  final service = _parseServiceCategoryType(originLabel);
  if (service != null) return serviceTypeLabel(service, l10n);
  final merchant = _parseMerchantType(originLabel);
  if (merchant != null) return merchantTypeLabel(merchant, l10n);
  return originLabel;
}

ServiceCategoryType? _parseServiceCategoryType(String name) {
  for (final type in ServiceCategoryType.values) {
    if (type.name == name) return type;
  }
  return null;
}

MerchantType? _parseMerchantType(String name) {
  for (final type in MerchantType.values) {
    if (type.name == name) return type;
  }
  return null;
}