import 'package:flutter/material.dart';

/// Centralised icon registry for the Delwaqty platform.
///
/// Every [IconData] reference in the app should be sourced from this class
/// to guarantee a single source of truth. This also makes icon theming and
/// auditing straightforward.
abstract final class AppIcons {
  // ---------------------------------------------------------------------------
  // Navigation Icons
  // ---------------------------------------------------------------------------

  /// Home tab icon.
  static const IconData navHome = Icons.home_rounded;

  /// Discover / explore tab icon.
  static const IconData navDiscover = Icons.explore_rounded;

  /// Orders / history tab icon.
  static const IconData navOrders = Icons.receipt_long_rounded;

  /// Cart / basket tab icon.
  static const IconData navCart = Icons.shopping_cart_rounded;

  /// Profile / account tab icon.
  static const IconData navProfile = Icons.person_rounded;

  /// Wallet / payments tab icon.
  static const IconData navWallet = Icons.account_balance_wallet_rounded;

  /// Notifications bell icon.
  static const IconData navNotifications = Icons.notifications_outlined;

  /// Drawer menu icon.
  static const IconData navDrawer = Icons.menu_rounded;

  // ---------------------------------------------------------------------------
  // Merchant Type Icons
  // ---------------------------------------------------------------------------

  /// Icon for restaurant / food merchants.
  static const IconData merchantFood = Icons.restaurant_rounded;

  /// Icon for grocery merchants.
  static const IconData merchantGrocery = Icons.local_grocery_store_rounded;

  /// Icon for pharmacy merchants.
  static const IconData merchantPharmacy = Icons.local_pharmacy_rounded;

  /// Icon for electronics merchants.
  static const IconData merchantElectronics = Icons.devices_rounded;

  /// Icon for fashion merchants.
  static const IconData merchantFashion = Icons.checkroom_rounded;

  /// Icon for furniture merchants.
  static const IconData merchantFurniture = Icons.chair_rounded;

  /// Icon for flower / florist merchants.
  static const IconData merchantFlowers = Icons.local_florist_rounded;

  /// Icon for bakery merchants.
  static const IconData merchantBakery = Icons.bakery_dining_rounded;

  /// Icon for home-service merchants.
  static const IconData merchantHome = Icons.home_repair_service_rounded;

  /// Fallback icon for unknown merchant types.
  static const IconData merchantOther = Icons.store_rounded;

  // ---------------------------------------------------------------------------
  // Order Status Icons
  // ---------------------------------------------------------------------------

  /// Icon for a pending order.
  static const IconData orderPending = Icons.schedule_rounded;

  /// Icon for a confirmed order.
  static const IconData orderConfirmed = Icons.check_circle_outline_rounded;

  /// Icon for an order being prepared.
  static const IconData orderPreparing = Icons.restaurant_menu_rounded;

  /// Icon for an order that is ready.
  static const IconData orderReady = Icons.check_rounded;

  /// Icon for an order in transit.
  static const IconData orderInTransit = Icons.local_shipping_rounded;

  /// Icon for a delivered order.
  static const IconData orderDelivered = Icons.task_alt_rounded;

  /// Icon for a cancelled order.
  static const IconData orderCancelled = Icons.cancel_rounded;

  // ---------------------------------------------------------------------------
  // Action Icons
  // ---------------------------------------------------------------------------

  /// General search icon.
  static const IconData actionSearch = Icons.search_rounded;

  /// Clear / close icon.
  static const IconData actionClear = Icons.clear_rounded;

  /// Add / create icon.
  static const IconData actionAdd = Icons.add_rounded;

  /// Edit / pencil icon.
  static const IconData actionEdit = Icons.edit_rounded;

  /// Delete / trash icon.
  static const IconData actionDelete = Icons.delete_rounded;

  /// Close / dismiss icon.
  static const IconData actionClose = Icons.close_rounded;

  /// Share icon.
  static const IconData actionShare = Icons.share_rounded;

  /// Favourite / heart icon (outlined).
  static const IconData actionFavourite = Icons.favorite_border_rounded;

  /// Favourite / heart icon (filled).
  static const IconData actionFavouriteFilled = Icons.favorite_rounded;

  /// Filter icon.
  static const IconData actionFilter = Icons.filter_list_rounded;

  /// Sort icon.
  static const IconData actionSort = Icons.sort_rounded;

  /// Refresh / reload icon.
  static const IconData actionRefresh = Icons.refresh_rounded;

  /// Copy icon.
  static const IconData actionCopy = Icons.copy_rounded;

  /// Download icon.
  static const IconData actionDownload = Icons.download_rounded;

  /// Upload icon.
  static const IconData actionUpload = Icons.upload_rounded;

  /// Info / help icon.
  static const IconData actionInfo = Icons.info_outline_rounded;

  /// Warning icon.
  static const IconData actionWarning = Icons.warning_amber_rounded;

  /// Success / check icon.
  static const IconData actionSuccess = Icons.check_circle_rounded;

  /// Error icon.
  static const IconData actionError = Icons.error_outline_rounded;

  /// Arrow forward / chevron right.
  static const IconData actionArrowForward = Icons.chevron_right_rounded;

  /// Arrow back.
  static const IconData actionArrowBack = Icons.arrow_back_rounded;

  /// Expand more (chevron down).
  static const IconData actionExpandMore = Icons.expand_more_rounded;

  /// Expand less (chevron up).
  static const IconData actionExpandLess = Icons.expand_less_rounded;

  /// More options (three dots vertical).
  static const IconData actionMore = Icons.more_vert_rounded;

  // ---------------------------------------------------------------------------
  // Authentication Icons
  // ---------------------------------------------------------------------------

  /// Logout icon.
  static const IconData authLogout = Icons.logout_rounded;

  /// Login icon.
  static const IconData authLogin = Icons.login_rounded;

  /// Visibility on (password shown).
  static const IconData authVisibilityOn = Icons.visibility_rounded;

  /// Visibility off (password hidden).
  static const IconData authVisibilityOff = Icons.visibility_off_rounded;

  /// Email icon.
  static const IconData authEmail = Icons.email_rounded;

  /// Lock / password icon.
  static const IconData authLock = Icons.lock_rounded;

  /// Person / user icon.
  static const IconData authPerson = Icons.person_rounded;

  /// Google icon placeholder.
  static const IconData authGoogle = Icons.g_mobiledata_rounded;

  /// Phone icon.
  static const IconData authPhone = Icons.phone_rounded;

  // ---------------------------------------------------------------------------
  // Rating Icons
  // ---------------------------------------------------------------------------

  /// Filled star for ratings.
  static const IconData ratingStar = Icons.star_rounded;

  /// Half-filled star for ratings.
  static const IconData ratingStarHalf = Icons.star_half_rounded;

  /// Empty star for ratings.
  static const IconData ratingStarEmpty = Icons.star_border_rounded;

  // ---------------------------------------------------------------------------
  // Misc / Utility Icons
  // ---------------------------------------------------------------------------

  /// Dark mode icon.
  static const IconData themeDark = Icons.dark_mode_rounded;

  /// Light mode icon.
  static const IconData themeLight = Icons.light_mode_rounded;

  /// Language / globe icon.
  static const IconData language = Icons.language_rounded;

  /// Trending up icon.
  static const IconData trendUp = Icons.trending_up_rounded;

  /// Trending down icon.
  static const IconData trendDown = Icons.trending_down_rounded;

  /// Camera icon.
  static const IconData camera = Icons.camera_alt_rounded;

  /// Image / gallery icon.
  static const IconData image = Icons.image_rounded;

  /// Location pin icon.
  static const IconData location = Icons.location_on_rounded;

  /// Map icon.
  static const IconData map = Icons.map_rounded;

  /// Calendar icon.
  static const IconData calendar = Icons.calendar_today_rounded;

  /// Clock icon.
  static const IconData clock = Icons.access_time_rounded;

  /// Link icon.
  static const IconData link = Icons.link_rounded;

  /// Qr code icon.
  static const IconData qrCode = Icons.qr_code_rounded;

  /// Cart add icon.
  static const IconData cartAdd = Icons.add_shopping_cart_rounded;

  /// Cart remove icon.
  static const IconData cartRemove = Icons.remove_shopping_cart_rounded;

  /// Receipt icon.
  static const IconData receipt = Icons.receipt_rounded;

  /// Offer / discount icon.
  static const IconData offer = Icons.local_offer_rounded;

  /// Bookmark icon.
  static const IconData bookmark = Icons.bookmark_rounded;

  /// Bookmark border icon.
  static const IconData bookmarkBorder = Icons.bookmark_border_rounded;

  /// Attach file icon.
  static const IconData attachFile = Icons.attach_file_rounded;

  /// Send icon.
  static const IconData send = Icons.send_rounded;

  /// Chat / message icon.
  static const IconData chat = Icons.chat_rounded;

  /// Chat bubble outline icon.
  static const IconData chatBubbleOutline = Icons.chat_bubble_outline_rounded;

  /// Phone call icon.
  static const IconData phoneCall = Icons.call_rounded;

  /// Video call icon.
  static const IconData videoCall = Icons.videocam_rounded;

  /// Settings icon.
  static const IconData settings = Icons.settings_rounded;

  /// Help icon.
  static const IconData help = Icons.help_rounded;

  /// Shield / security icon.
  static const IconData shield = Icons.shield_rounded;

  /// Wallet icon.
  static const IconData wallet = Icons.account_balance_wallet_rounded;

  /// Credit card icon.
  static const IconData creditCard = Icons.credit_card_rounded;

  /// Bank icon.
  static const IconData bank = Icons.account_balance_rounded;

  /// Cash icon.
  static const IconData cash = Icons.payments_rounded;

  /// Star icon (alias).
  static const IconData star = Icons.star_rounded;

  /// Star outline icon.
  static const IconData starOutline = Icons.star_border_rounded;

  /// Local shipping icon.
  static const IconData shipping = Icons.local_shipping_rounded;

  /// Package icon.
  static const IconData package = Icons.inventory_2_rounded;

  /// Warehouse / inventory icon.
  static const IconData warehouse = Icons.warehouse_rounded;

  /// Categories icon.
  static const IconData categories = Icons.category_rounded;

  /// Grid view icon.
  static const IconData gridView = Icons.grid_view_rounded;

  /// List view icon.
  static const IconData listView = Icons.view_list_rounded;

  /// Play icon.
  static const IconData play = Icons.play_arrow_rounded;

  /// Pause icon.
  static const IconData pause = Icons.pause_rounded;

  /// Stop icon.
  static const IconData stop = Icons.stop_rounded;

  /// Check icon.
  static const IconData check = Icons.check_rounded;

  /// More horizontal dots icon.
  static const IconData moreHorizontal = Icons.more_horiz_rounded;

  /// Compare / swap icon.
  static const IconData swap = Icons.swap_horiz_rounded;

  /// Sync / reload alternate icon.
  static const IconData sync = Icons.sync_rounded;

  /// Scan / barcode icon.
  static const IconData scan = Icons.document_scanner_rounded;
}
