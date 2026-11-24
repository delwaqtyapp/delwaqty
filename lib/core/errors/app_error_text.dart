import 'package:delwaqty/core/errors/exceptions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// The single place where an exception becomes text a person reads.
///
/// Data and domain layers are allowed to stringify the original failure -
/// `ServerException(message: e.toString())` keeps the Postgres text and the
/// PostgREST code, which is genuinely useful in a log. Nothing above the display
/// boundary may render it. `appErrorMessage` therefore never returns the raw
/// error: it classifies the failure and returns a localized sentence, so an
/// operator is told what went wrong for them ("no connection", "not allowed")
/// instead of being handed SQL.
///
/// The classifier is deliberately duck-typed rather than importing
/// `postgrest`/`dart:io`: it must compile for the Flutter-web admin target as
/// well as Android, so `dart:io` is out and the concrete transport types are
/// recognised by name.
enum AppErrorKind {
  network,
  timeout,
  unauthenticated,
  forbidden,
  notFound,
  conflict,
  server,
  location,
  unknown,
}

const Map<String, AppErrorKind> _transportNames = <String, AppErrorKind>{
  'SocketException': AppErrorKind.network,
  'HttpException': AppErrorKind.network,
  'ClientException': AppErrorKind.network,
  'HandshakeException': AppErrorKind.network,
  'TlsException': AppErrorKind.network,
  'TimeoutException': AppErrorKind.timeout,
};

AppErrorKind classifyAppError(Object? error) {
  if (error is NetworkException) return AppErrorKind.network;
  if (error is TimeoutException) return AppErrorKind.timeout;
  if (error is RateLimitException) return AppErrorKind.server;
  if (error is AuthException) {
    return error.statusCode == 403
        ? AppErrorKind.forbidden
        : AppErrorKind.unauthenticated;
  }
  if (error is ServerException || error is CacheException) {
    return AppErrorKind.server;
  }
  if (error is UnexpectedException) return AppErrorKind.server;

  final typeName = error.runtimeType.toString();
  for (final entry in _transportNames.entries) {
    if (typeName == entry.key || typeName.endsWith('.${entry.key}')) {
      return entry.value;
    }
  }

  // PostgREST and raw Postgres both carry a machine code we can act on without
  // importing their packages.
  final code = _readStringField(error, 'code');
  if (code != null && code.isNotEmpty) {
    if (code == '42501') return AppErrorKind.forbidden;
    if (code == 'PGRST116') return AppErrorKind.notFound;
    if (code == 'PGRST301') return AppErrorKind.unauthenticated;
    if (code == '23505' || code.startsWith('23')) return AppErrorKind.conflict;
    if (code == '57014' || code == '55P03' || code == '53300') {
      return AppErrorKind.timeout;
    }
    if (code == 'PGRST' || code.startsWith('42')) return AppErrorKind.server;
  }

  final message = _readStringField(error, 'message') ?? error.toString();
  final lowered = message.toLowerCase();
  if (lowered.contains('failed to fetch') ||
      lowered.contains('network') ||
      lowered.contains('connection') ||
      lowered.contains('socket')) {
    return AppErrorKind.network;
  }
  if (lowered.contains('timeout') || lowered.contains('timed out')) {
    return AppErrorKind.timeout;
  }
  if (lowered.contains('jwt') || lowered.contains('not authenticated')) {
    return AppErrorKind.unauthenticated;
  }
  // Driver location States (DriverPositionSource) must be recognised before
  // the generic 'permission' substring below routes them to forbidden.
  if (lowered.contains('location_permission_required') ||
      lowered.contains('location_unavailable') ||
      lowered.contains('stale_location')) {
    return AppErrorKind.location;
  }
  if (lowered.contains('row-level security') ||
      lowered.contains('permission')) {
    return AppErrorKind.forbidden;
  }
  return AppErrorKind.unknown;
}

dynamic _readStringField(Object? error, String name) {
  if (error == null) return null;
  try {
    final dynamic value = error as dynamic;
    final Object? field = name == 'code' ? value.code : value.message;
    return field is String ? field : null;
  } on NoSuchMethodError {
    return null;
  }
}

/// Localized, user-safe text for [error]. Never contains the raw exception.
String appErrorMessage(AppLocalizations l10n, Object? error) {
  switch (classifyAppError(error)) {
    case AppErrorKind.network:
      return l10n.noConnection;
    case AppErrorKind.timeout:
      return l10n.errorTimeout;
    case AppErrorKind.unauthenticated:
      return l10n.errorUnauthenticated;
    case AppErrorKind.forbidden:
      return l10n.errorForbidden;
    case AppErrorKind.notFound:
      return l10n.errorNotFound;
    case AppErrorKind.conflict:
      return l10n.errorConflict;
    case AppErrorKind.server:
      return l10n.errorServerIssue;
    case AppErrorKind.location:
      return l10n.locationPermissionRequired;
    case AppErrorKind.unknown:
      return l10n.somethingWentWrong;
  }
}

/// Checkout (create_order RPC) errors arrive as P0001 with a machine code and
/// an optional detail ("INSUFFICIENT_STOCK <product>", "BELOW_MIN_ORDER 100").
/// Map them to actionable localized sentences instead of the generic
/// "something went wrong" (UI review: the snackbar hid the real cause).
String checkoutErrorMessage(AppLocalizations l10n, Object? error) {
  final raw = (_readStringField(error, 'message') ?? error.toString());
  final match = RegExp(
    r'(INSUFFICIENT_STOCK|PRODUCT_UNAVAILABLE|PRODUCT_NOT_FOUND|MERCHANT_NOT_FOUND|EMPTY_CART|TOO_MANY_ITEMS|INVALID_QUANTITY|BELOW_MIN_ORDER|COUPON_[A-Z_]+|MISSING_DELIVERY_LOCATION|DELIVERY_OUT_OF_ZONE|ACCOUNT_SUSPENDED|INVALID_PAYMENT_METHOD|REQUIRED_MODIFIER_MISSING|MODIFIER_MAX_EXCEEDED|WALLET_PAYMENT_NOT_AVAILABLE|CARD_PAYMENT_NOT_AVAILABLE)\b\s*([^\n]*)',
  ).firstMatch(raw);
  if (match == null) return appErrorMessage(l10n, error);
  final code = match.group(1)!;
  final detail = (match.group(2) ?? '').trim();
  switch (code) {
    case 'INSUFFICIENT_STOCK':
      return detail.isNotEmpty
          ? l10n.checkoutOutOfStock(detail)
          : l10n.checkoutItemOutOfStock;
    case 'PRODUCT_UNAVAILABLE':
    case 'PRODUCT_NOT_FOUND':
      return detail.isNotEmpty
          ? l10n.checkoutProductUnavailable(detail)
          : l10n.checkoutMerchantUnavailable;
    case 'MERCHANT_NOT_FOUND':
      return l10n.checkoutMerchantUnavailable;
    case 'EMPTY_CART':
      return l10n.checkoutEmptyCartError;
    case 'BELOW_MIN_ORDER':
      return l10n.checkoutBelowMinOrder(detail);
    case 'MISSING_DELIVERY_LOCATION':
      return l10n.checkoutMissingDeliveryLocation;
    case 'DELIVERY_OUT_OF_ZONE':
      return l10n.checkoutDeliveryOutOfZone;
    case 'ACCOUNT_SUSPENDED':
      return l10n.checkoutAccountSuspended;
    case 'WALLET_PAYMENT_NOT_AVAILABLE':
      return l10n.checkoutWalletNotAvailable;
    case 'CARD_PAYMENT_NOT_AVAILABLE':
      return l10n.checkoutCardNotAvailable;
    case 'REQUIRED_MODIFIER_MISSING':
      return l10n.checkoutRequiredModifier(detail);
    case 'MODIFIER_MAX_EXCEEDED':
      return l10n.checkoutModifierMaxExceeded(detail);
    default:
      if (code.startsWith('COUPON_')) return l10n.checkoutCouponInvalid;
      return appErrorMessage(l10n, error);
  }
}

/// Convenience wrapper for call sites that hold a [BuildContext].
String checkoutErrorText(BuildContext context, Object? error) =>
    checkoutErrorMessage(AppLocalizations.of(context), error);

/// Ask-anything courier (436) errors: the RPCs answer
/// `{ok: false, reason: CODE}` and the data source throws
/// `DeliveryException(code)`. Map every code the 436 migration can raise
/// (plus the two lowercase cancel/start guards) to a specific localized
/// sentence instead of the generic "something went wrong" (#215).
String courierErrorMessage(AppLocalizations l10n, Object? error) {
  final raw = _readStringField(error, 'message') ?? error.toString();
  final match = RegExp(
    r'(BELOW_BASELINE|QUOTE_CAP|GOODS_CAP|SHOP_CAP|ITEM_CAP|THROTTLED|INVALID_AMOUNT|INVALID_ITEMS|INVALID_INPUT|INVALID_STATE|ITEMS_PENDING|ITEM_NOT_PENDING|NO_QUOTE_TO_COUNTER|QUOTE_ALREADY_LOCKED|QUOTE_NOT_LOCKED|QUOTE_NOT_PENDING|REJECTED_ITEMS_OPEN|DRIVER_CHANGED|RIDER_CHANGED|TOO_MANY_OPEN_RIDES|ask_anything_cash_only|ask_anything_goods_in_progress|shopping_not_finished)\b',
  ).firstMatch(raw);
  if (match == null) return appErrorMessage(l10n, error);
  switch (match.group(1)!) {
    case 'BELOW_BASELINE':
      return l10n.courierErrBelowBaseline;
    case 'QUOTE_CAP':
      return l10n.courierErrQuoteCap;
    case 'GOODS_CAP':
      return l10n.courierErrGoodsCap;
    case 'SHOP_CAP':
      return l10n.courierErrShopCap;
    case 'ITEM_CAP':
      return l10n.courierItemsLimit;
    case 'THROTTLED':
      return l10n.courierErrThrottled;
    case 'INVALID_AMOUNT':
      return l10n.courierErrInvalidAmount;
    case 'INVALID_ITEMS':
      return l10n.courierErrInvalidItems;
    case 'INVALID_STATE':
      return l10n.courierErrInvalidState;
    case 'ITEMS_PENDING':
      return l10n.courierErrItemsPending;
    case 'ITEM_NOT_PENDING':
      return l10n.courierErrItemNotPending;
    case 'NO_QUOTE_TO_COUNTER':
      return l10n.courierErrNoQuoteToCounter;
    case 'QUOTE_ALREADY_LOCKED':
      return l10n.courierErrQuoteAlreadyLocked;
    case 'QUOTE_NOT_LOCKED':
      return l10n.courierErrQuoteNotLocked;
    case 'QUOTE_NOT_PENDING':
      return l10n.courierErrQuoteNotPending;
    case 'REJECTED_ITEMS_OPEN':
      return l10n.courierErrRejectedItemsOpen;
    case 'DRIVER_CHANGED':
    case 'RIDER_CHANGED':
      return l10n.courierErrPartyChanged;
    case 'TOO_MANY_OPEN_RIDES':
      return l10n.courierErrTooManyOpenRides;
    case 'ask_anything_cash_only':
      return l10n.courierErrCashOnly;
    case 'ask_anything_goods_in_progress':
      return l10n.courierErrGoodsInProgress;
    case 'shopping_not_finished':
      return l10n.courierErrShoppingNotFinished;
    default:
      // INVALID_INPUT and anything unlisted.
      return match.group(1) == 'INVALID_INPUT'
          ? l10n.courierErrInvalidInput
          : appErrorMessage(l10n, error);
  }
}

/// Convenience wrapper for call sites that hold a [BuildContext].
String courierErrorText(BuildContext context, Object? error) =>
    courierErrorMessage(AppLocalizations.of(context), error);

/// Convenience wrapper for call sites that hold a [BuildContext].
String appErrorText(BuildContext context, Object? error) =>
    appErrorMessage(AppLocalizations.of(context), error);

/// The technical text, for logs only. Never render this in the UI.
String appErrorDetail(Object? error) => error?.toString() ?? '';
