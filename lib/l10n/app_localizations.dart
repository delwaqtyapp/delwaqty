import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Delwaqty'**
  String get appTitle;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Delwaqty'**
  String get appName;

  /// No description provided for @appNameAr.
  ///
  /// In en, this message translates to:
  /// **'دلوقتي'**
  String get appNameAr;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Every service. One app.'**
  String get splashTagline;

  /// No description provided for @splashLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing your experience...'**
  String get splashLoading;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingDone;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'All your needs... in one app'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Order food, book services, shop online, and get anything delivered. Everything you need, right at your fingertips.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Order Food'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Browse restaurants, explore menus, customize your meal, and get it delivered fast to your door.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Book Services'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Cleaning, electrician, plumber, AC repair — book trusted professionals in seconds.'**
  String get onboardingDesc3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In en, this message translates to:
  /// **'Track Your Order'**
  String get onboardingTitle4;

  /// No description provided for @onboardingDesc4.
  ///
  /// In en, this message translates to:
  /// **'Real-time tracking, live map, driver ETA, and instant notifications for every order.'**
  String get onboardingDesc4;

  /// No description provided for @onboardingTitle5.
  ///
  /// In en, this message translates to:
  /// **'Start Now'**
  String get onboardingTitle5;

  /// No description provided for @onboardingDesc5.
  ///
  /// In en, this message translates to:
  /// **'Everything revolves around Delwaqty. Your super app for everyday life.'**
  String get onboardingDesc5;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Delwaqty'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Order. Shop. Move. Book. All in Delwaqty.'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeLoginButton.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get welcomeLoginButton;

  /// No description provided for @welcomeRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get welcomeRegisterButton;

  /// No description provided for @welcomeGuestButton.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get welcomeGuestButton;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link has been sent to your email.'**
  String get resetEmailSent;

  /// No description provided for @resetEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get resetEmailHint;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noConnection;

  /// No description provided for @connectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Internet connection restored'**
  String get connectionRestored;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants, shops, services...'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term or browse categories.'**
  String get searchNoResultsMessage;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortByDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get sortByDistance;

  /// No description provided for @sortByRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get sortByRating;

  /// No description provided for @sortByPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get sortByPrice;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @restaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurants;

  /// No description provided for @grocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get grocery;

  /// No description provided for @pharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get pharmacy;

  /// No description provided for @ride.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get ride;

  /// No description provided for @homeServices.
  ///
  /// In en, this message translates to:
  /// **'Home Services'**
  String get homeServices;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @recentOrders.
  ///
  /// In en, this message translates to:
  /// **'Recent Orders'**
  String get recentOrders;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order Placed!'**
  String get orderPlaced;

  /// No description provided for @orderTracking.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get orderTracking;

  /// No description provided for @orderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistory;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFee;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated Time'**
  String get estimatedTime;

  /// No description provided for @estimatedArrival.
  ///
  /// In en, this message translates to:
  /// **'Estimated Arrival'**
  String get estimatedArrival;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @emptyCart.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get emptyCart;

  /// No description provided for @emptyCartMessage.
  ///
  /// In en, this message translates to:
  /// **'Add items from restaurants and shops to get started.'**
  String get emptyCartMessage;

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear Cart'**
  String get clearCart;

  /// No description provided for @browseMerchants.
  ///
  /// In en, this message translates to:
  /// **'Browse Merchants'**
  String get browseMerchants;

  /// No description provided for @proceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get proceedToCheckout;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrders;

  /// No description provided for @noOrdersMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order history will appear here.'**
  String get noOrdersMessage;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHours;

  /// No description provided for @deliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Delivery Time'**
  String get deliveryTime;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @offersTab.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offersTab;

  /// No description provided for @branches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get branches;

  /// No description provided for @selectBranch.
  ///
  /// In en, this message translates to:
  /// **'Select Branch'**
  String get selectBranch;

  /// No description provided for @applyCoupon.
  ///
  /// In en, this message translates to:
  /// **'Apply Coupon'**
  String get applyCoupon;

  /// No description provided for @couponCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon Code'**
  String get couponCode;

  /// No description provided for @removeCoupon.
  ///
  /// In en, this message translates to:
  /// **'Remove Coupon'**
  String get removeCoupon;

  /// No description provided for @couponApplied.
  ///
  /// In en, this message translates to:
  /// **'Coupon applied!'**
  String get couponApplied;

  /// No description provided for @couponInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid coupon code'**
  String get couponInvalid;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @specialInstructions.
  ///
  /// In en, this message translates to:
  /// **'Special Instructions'**
  String get specialInstructions;

  /// No description provided for @specialInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Any allergies or preferences?'**
  String get specialInstructionsHint;

  /// No description provided for @orderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmed'**
  String get orderConfirmed;

  /// No description provided for @orderConfirmedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order has been confirmed and the merchant is preparing it.'**
  String get orderConfirmedMessage;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparing;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @outForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for Delivery'**
  String get outForDelivery;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @rateOrder.
  ///
  /// In en, this message translates to:
  /// **'Rate Order'**
  String get rateOrder;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @callDriver.
  ///
  /// In en, this message translates to:
  /// **'Call Driver'**
  String get callDriver;

  /// No description provided for @chatDriver.
  ///
  /// In en, this message translates to:
  /// **'Chat with Driver'**
  String get chatDriver;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share Location'**
  String get shareLocation;

  /// No description provided for @thankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank You!'**
  String get thankYou;

  /// No description provided for @orderSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order has been placed successfully. You can track it in real-time.'**
  String get orderSuccessMessage;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @trackYourOrder.
  ///
  /// In en, this message translates to:
  /// **'Track Your Order'**
  String get trackYourOrder;

  /// No description provided for @itemAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Item added to cart'**
  String get itemAddedToCart;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get viewCart;

  /// No description provided for @selectDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Select Delivery Address'**
  String get selectDeliveryAddress;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddresses;

  /// No description provided for @noSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses yet'**
  String get noSavedAddresses;

  /// No description provided for @addressLine1.
  ///
  /// In en, this message translates to:
  /// **'Address Line 1'**
  String get addressLine1;

  /// No description provided for @addressLine2.
  ///
  /// In en, this message translates to:
  /// **'Address Line 2'**
  String get addressLine2;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal Code'**
  String get postalCode;

  /// No description provided for @cashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get cashOnDelivery;

  /// No description provided for @creditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get creditCard;

  /// No description provided for @digitalWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital Wallet'**
  String get digitalWallet;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @orderTimeline.
  ///
  /// In en, this message translates to:
  /// **'Order Timeline'**
  String get orderTimeline;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String itemCount(num count);

  /// No description provided for @itemCountOther.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get itemCountOther;

  /// No description provided for @sar.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get sar;

  /// No description provided for @searchRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants...'**
  String get searchRestaurants;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open Now'**
  String get openNow;

  /// No description provided for @freeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery'**
  String get freeDelivery;

  /// No description provided for @highestRated.
  ///
  /// In en, this message translates to:
  /// **'Highest Rated'**
  String get highestRated;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @enterCouponCode.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code'**
  String get enterCouponCode;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @pickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get pickedUp;

  /// No description provided for @inTransit.
  ///
  /// In en, this message translates to:
  /// **'In Transit'**
  String get inTransit;

  /// No description provided for @onboardingTitle6.
  ///
  /// In en, this message translates to:
  /// **'Shop Online'**
  String get onboardingTitle6;

  /// No description provided for @onboardingDesc6.
  ///
  /// In en, this message translates to:
  /// **'From groceries to electronics, fashion to furniture — shop from hundreds of stores and get fast delivery.'**
  String get onboardingDesc6;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get loginWithApple;

  /// No description provided for @loginWithFacebook.
  ///
  /// In en, this message translates to:
  /// **'Continue with Facebook'**
  String get loginWithFacebook;

  /// No description provided for @loginWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Continue with Phone'**
  String get loginWithPhone;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// No description provided for @agreementPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get agreementPrefix;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @superAppTagline.
  ///
  /// In en, this message translates to:
  /// **'Your everyday super app'**
  String get superAppTagline;

  /// No description provided for @allServicesInOneApp.
  ///
  /// In en, this message translates to:
  /// **'All services in one app'**
  String get allServicesInOneApp;

  /// No description provided for @fastDelivery.
  ///
  /// In en, this message translates to:
  /// **'Fast Delivery'**
  String get fastDelivery;

  /// No description provided for @fastDeliveryDesc.
  ///
  /// In en, this message translates to:
  /// **'Get your orders delivered in minutes'**
  String get fastDeliveryDesc;

  /// No description provided for @trustedMerchants.
  ///
  /// In en, this message translates to:
  /// **'Trusted Merchants'**
  String get trustedMerchants;

  /// No description provided for @trustedMerchantsDesc.
  ///
  /// In en, this message translates to:
  /// **'Only verified and top-rated stores'**
  String get trustedMerchantsDesc;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get liveTracking;

  /// No description provided for @liveTrackingDesc.
  ///
  /// In en, this message translates to:
  /// **'Track your orders in real-time'**
  String get liveTrackingDesc;

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode'**
  String get guestMode;

  /// No description provided for @guestModeHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your orders, favorites, and profile.'**
  String get guestModeHint;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @errorLoading.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorLoading;

  /// No description provided for @nearbyEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No merchants found nearby. Try expanding your search.'**
  String get nearbyEmptyHint;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check Your Email'**
  String get checkYourEmail;

  /// No description provided for @emailConfirmationSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Please check your inbox and click the link to activate your account.'**
  String emailConfirmationSent(Object email);

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get goToLogin;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @searchMerchantsProducts.
  ///
  /// In en, this message translates to:
  /// **'Search merchants, products...'**
  String get searchMerchantsProducts;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @allMerchants.
  ///
  /// In en, this message translates to:
  /// **'All Merchants'**
  String get allMerchants;

  /// No description provided for @noMerchantsFound.
  ///
  /// In en, this message translates to:
  /// **'No merchants found'**
  String get noMerchantsFound;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @noNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up! New notifications will appear here.'**
  String get noNotificationsMessage;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @platformOverview.
  ///
  /// In en, this message translates to:
  /// **'Platform Overview'**
  String get platformOverview;

  /// No description provided for @totalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total Users'**
  String get totalUsers;

  /// No description provided for @totalMerchants.
  ///
  /// In en, this message translates to:
  /// **'Merchants'**
  String get totalMerchants;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get totalOrders;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @activeDrivers.
  ///
  /// In en, this message translates to:
  /// **'Active Drivers'**
  String get activeDrivers;

  /// No description provided for @pendingOrdersStat.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get pendingOrdersStat;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get noRecentActivity;

  /// No description provided for @errorLoadingMetrics.
  ///
  /// In en, this message translates to:
  /// **'Error loading metrics'**
  String get errorLoadingMetrics;

  /// No description provided for @errorLoadingActivity.
  ///
  /// In en, this message translates to:
  /// **'Error loading activity'**
  String get errorLoadingActivity;

  /// No description provided for @userManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get searchUsers;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add Admin User'**
  String get addUser;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @suspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspend;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @orderManagement.
  ///
  /// In en, this message translates to:
  /// **'Order Management'**
  String get orderManagement;

  /// No description provided for @searchOrders.
  ///
  /// In en, this message translates to:
  /// **'Search orders...'**
  String get searchOrders;

  /// No description provided for @filterOrders.
  ///
  /// In en, this message translates to:
  /// **'Filter Orders'**
  String get filterOrders;

  /// No description provided for @noOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found'**
  String get noOrdersFound;

  /// No description provided for @markInTransit.
  ///
  /// In en, this message translates to:
  /// **'Mark In Transit'**
  String get markInTransit;

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark Delivered'**
  String get markDelivered;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @merchantManagement.
  ///
  /// In en, this message translates to:
  /// **'Merchant Management'**
  String get merchantManagement;

  /// No description provided for @searchMerchantsAdmin.
  ///
  /// In en, this message translates to:
  /// **'Search merchants...'**
  String get searchMerchantsAdmin;

  /// No description provided for @noMerchantsAdmin.
  ///
  /// In en, this message translates to:
  /// **'No merchants found'**
  String get noMerchantsAdmin;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @setPending.
  ///
  /// In en, this message translates to:
  /// **'Set Pending'**
  String get setPending;

  /// No description provided for @platformSettings.
  ///
  /// In en, this message translates to:
  /// **'Platform Settings'**
  String get platformSettings;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support Email'**
  String get supportEmail;

  /// No description provided for @maxDriversPerZone.
  ///
  /// In en, this message translates to:
  /// **'Max Drivers Per Zone'**
  String get maxDriversPerZone;

  /// No description provided for @maintenanceMode.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Mode'**
  String get maintenanceMode;

  /// No description provided for @maintenanceModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Temporarily disable the app'**
  String get maintenanceModeDesc;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @settingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get settingsFailed;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @resetAllData.
  ///
  /// In en, this message translates to:
  /// **'Reset All Data'**
  String get resetAllData;

  /// No description provided for @resetAllDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all platform data'**
  String get resetAllDataDesc;

  /// No description provided for @resetAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset All Data?'**
  String get resetAllDataTitle;

  /// No description provided for @resetAllDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All data will be permanently deleted.'**
  String get resetAllDataWarning;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @privacySecurity.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurity;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get version;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @riyadhSaudiArabia.
  ///
  /// In en, this message translates to:
  /// **'Riyadh, Saudi Arabia'**
  String get riyadhSaudiArabia;

  /// No description provided for @searchingForLocation.
  ///
  /// In en, this message translates to:
  /// **'Searching for location...'**
  String get searchingForLocation;

  /// No description provided for @dineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine In'**
  String get dineIn;

  /// No description provided for @takeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get takeaway;

  /// No description provided for @reserveATable.
  ///
  /// In en, this message translates to:
  /// **'Reserve a Table'**
  String get reserveATable;

  /// No description provided for @noBranches.
  ///
  /// In en, this message translates to:
  /// **'No branches available'**
  String get noBranches;

  /// No description provided for @primaryBranch.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get primaryBranch;

  /// No description provided for @distanceAway.
  ///
  /// In en, this message translates to:
  /// **'away'**
  String get distanceAway;

  /// No description provided for @km.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get km;

  /// No description provided for @prepTime.
  ///
  /// In en, this message translates to:
  /// **'Prep Time'**
  String get prepTime;

  /// No description provided for @avgPrepTime.
  ///
  /// In en, this message translates to:
  /// **'Avg. {minutes} min'**
  String avgPrepTime(Object minutes);

  /// No description provided for @opensAt.
  ///
  /// In en, this message translates to:
  /// **'Opens at {time}'**
  String opensAt(Object time);

  /// No description provided for @closesAt.
  ///
  /// In en, this message translates to:
  /// **'Closes at {time}'**
  String closesAt(Object time);

  /// No description provided for @closedToday.
  ///
  /// In en, this message translates to:
  /// **'Closed today'**
  String get closedToday;

  /// No description provided for @openToday.
  ///
  /// In en, this message translates to:
  /// **'Open today'**
  String get openToday;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @partySize.
  ///
  /// In en, this message translates to:
  /// **'Party Size'**
  String get partySize;

  /// No description provided for @guests.
  ///
  /// In en, this message translates to:
  /// **'guests'**
  String get guests;

  /// No description provided for @availableSlots.
  ///
  /// In en, this message translates to:
  /// **'Available Slots'**
  String get availableSlots;

  /// No description provided for @noSlotsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No available slots for this date'**
  String get noSlotsAvailable;

  /// No description provided for @confirmReservation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reservation'**
  String get confirmReservation;

  /// No description provided for @reservationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Reservation Confirmed!'**
  String get reservationConfirmed;

  /// No description provided for @reservationPending.
  ///
  /// In en, this message translates to:
  /// **'Reservation Pending'**
  String get reservationPending;

  /// No description provided for @reservationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Reservation Cancelled'**
  String get reservationCancelled;

  /// No description provided for @cancelReservation.
  ///
  /// In en, this message translates to:
  /// **'Cancel Reservation'**
  String get cancelReservation;

  /// No description provided for @modifyReservation.
  ///
  /// In en, this message translates to:
  /// **'Modify Reservation'**
  String get modifyReservation;

  /// No description provided for @specialRequests.
  ///
  /// In en, this message translates to:
  /// **'Special Requests'**
  String get specialRequests;

  /// No description provided for @specialRequestsHint.
  ///
  /// In en, this message translates to:
  /// **'Any dietary needs or seating preferences?'**
  String get specialRequestsHint;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @minutesValue.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String minutesValue(Object value);

  /// No description provided for @myReservations.
  ///
  /// In en, this message translates to:
  /// **'My Reservations'**
  String get myReservations;

  /// No description provided for @noReservations.
  ///
  /// In en, this message translates to:
  /// **'No reservations yet'**
  String get noReservations;

  /// No description provided for @noReservationsMessage.
  ///
  /// In en, this message translates to:
  /// **'Book a table at your favorite restaurant.'**
  String get noReservationsMessage;

  /// No description provided for @upcomingReservations.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingReservations;

  /// No description provided for @pastReservations.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get pastReservations;

  /// No description provided for @activeOffers.
  ///
  /// In en, this message translates to:
  /// **'Active Offers'**
  String get activeOffers;

  /// No description provided for @noOffersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No offers available'**
  String get noOffersAvailable;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String validUntil(Object date);

  /// No description provided for @minOrderRequired.
  ///
  /// In en, this message translates to:
  /// **'Min. order {amount} {currency}'**
  String minOrderRequired(Object amount, Object currency);

  /// No description provided for @useOffer.
  ///
  /// In en, this message translates to:
  /// **'Use Offer'**
  String get useOffer;

  /// No description provided for @offerExpired.
  ///
  /// In en, this message translates to:
  /// **'Offer expired'**
  String get offerExpired;

  /// No description provided for @automaticOffers.
  ///
  /// In en, this message translates to:
  /// **'Auto-applied Offers'**
  String get automaticOffers;

  /// No description provided for @percentageOff.
  ///
  /// In en, this message translates to:
  /// **'{value}% off'**
  String percentageOff(Object value);

  /// No description provided for @fixedOff.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency} off'**
  String fixedOff(Object amount, Object currency);

  /// No description provided for @deliveryZones.
  ///
  /// In en, this message translates to:
  /// **'Delivery Zones'**
  String get deliveryZones;

  /// No description provided for @deliversTo.
  ///
  /// In en, this message translates to:
  /// **'Delivers to'**
  String get deliversTo;

  /// No description provided for @zoneDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery: {fee} {currency}'**
  String zoneDeliveryFee(Object currency, Object fee);

  /// No description provided for @zoneMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Min. order: {amount} {currency}'**
  String zoneMinOrder(Object amount, Object currency);

  /// No description provided for @estimatedDeliveryTime.
  ///
  /// In en, this message translates to:
  /// **'~{minutes} min'**
  String estimatedDeliveryTime(Object minutes);

  /// No description provided for @noDeliveryZones.
  ///
  /// In en, this message translates to:
  /// **'Delivery not available'**
  String get noDeliveryZones;

  /// No description provided for @chooseOptions.
  ///
  /// In en, this message translates to:
  /// **'Choose options'**
  String get chooseOptions;

  /// No description provided for @requiredOption.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredOption;

  /// No description provided for @optionalOption.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optionalOption;

  /// No description provided for @selectOne.
  ///
  /// In en, this message translates to:
  /// **'Select one'**
  String get selectOne;

  /// No description provided for @selectUpTo.
  ///
  /// In en, this message translates to:
  /// **'Select up to {count}'**
  String selectUpTo(Object count);

  /// No description provided for @additionalCost.
  ///
  /// In en, this message translates to:
  /// **'+{amount} {currency}'**
  String additionalCost(Object amount, Object currency);

  /// No description provided for @searchMenu.
  ///
  /// In en, this message translates to:
  /// **'Search menu...'**
  String get searchMenu;

  /// No description provided for @noProductsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No items in this category'**
  String get noProductsInCategory;

  /// No description provided for @popularItems.
  ///
  /// In en, this message translates to:
  /// **'Popular Items'**
  String get popularItems;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inStock;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a Review'**
  String get writeReview;

  /// No description provided for @ratingBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Rating Breakdown'**
  String get ratingBreakdown;

  /// No description provided for @basedOnReviews.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} reviews'**
  String basedOnReviews(Object count);

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @beTheFirst.
  ///
  /// In en, this message translates to:
  /// **'Be the first to review!'**
  String get beTheFirst;

  /// No description provided for @yourRating.
  ///
  /// In en, this message translates to:
  /// **'Your Rating'**
  String get yourRating;

  /// No description provided for @yourReview.
  ///
  /// In en, this message translates to:
  /// **'Your Review'**
  String get yourReview;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted! Thank you.'**
  String get reviewSubmitted;

  /// No description provided for @selectBranchFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a branch first'**
  String get selectBranchFirst;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @fullMenu.
  ///
  /// In en, this message translates to:
  /// **'Full Menu'**
  String get fullMenu;

  /// No description provided for @viewFullMenu.
  ///
  /// In en, this message translates to:
  /// **'View Full Menu'**
  String get viewFullMenu;

  /// No description provided for @allOffers.
  ///
  /// In en, this message translates to:
  /// **'All Offers'**
  String get allOffers;

  /// No description provided for @allReviews.
  ///
  /// In en, this message translates to:
  /// **'All Reviews'**
  String get allReviews;

  /// No description provided for @contactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get contactInfo;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @shareRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Share Restaurant'**
  String get shareRestaurant;

  /// No description provided for @reportRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportRestaurant;

  /// No description provided for @merchantDashboard.
  ///
  /// In en, this message translates to:
  /// **'Merchant Dashboard'**
  String get merchantDashboard;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @todayOrders.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Orders'**
  String get todayOrders;

  /// No description provided for @viewOrders.
  ///
  /// In en, this message translates to:
  /// **'View Orders'**
  String get viewOrders;

  /// No description provided for @manageProducts.
  ///
  /// In en, this message translates to:
  /// **'Manage Products'**
  String get manageProducts;

  /// No description provided for @createOffer.
  ///
  /// In en, this message translates to:
  /// **'Create Offer'**
  String get createOffer;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @markReady.
  ///
  /// In en, this message translates to:
  /// **'Mark Ready'**
  String get markReady;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProduct;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @invalidImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid image URL'**
  String get invalidImageUrl;

  /// No description provided for @addProductImage.
  ///
  /// In en, this message translates to:
  /// **'Add product image'**
  String get addProductImage;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productName;

  /// No description provided for @enterProductName.
  ///
  /// In en, this message translates to:
  /// **'Enter product name'**
  String get enterProductName;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @enterDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter description'**
  String get enterDescription;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @invalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get invalidPrice;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @enterCategory.
  ///
  /// In en, this message translates to:
  /// **'Enter category'**
  String get enterCategory;

  /// No description provided for @imageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrl;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @productAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Toggle product availability'**
  String get productAvailableHint;

  /// No description provided for @featuredProductHint.
  ///
  /// In en, this message translates to:
  /// **'Show this product on the home page'**
  String get featuredProductHint;

  /// No description provided for @productUpdated.
  ///
  /// In en, this message translates to:
  /// **'Product updated successfully'**
  String get productUpdated;

  /// No description provided for @productCreated.
  ///
  /// In en, this message translates to:
  /// **'Product created successfully'**
  String get productCreated;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @areYouSureYouWantToDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete'**
  String get areYouSureYouWantToDelete;

  /// No description provided for @areYouSureYouWantToLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get areYouSureYouWantToLogout;

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted'**
  String get productDeleted;

  /// No description provided for @reservationDetails.
  ///
  /// In en, this message translates to:
  /// **'Reservation Details'**
  String get reservationDetails;

  /// No description provided for @partyOf.
  ///
  /// In en, this message translates to:
  /// **'Party of {count}'**
  String partyOf(Object count);

  /// No description provided for @atTime.
  ///
  /// In en, this message translates to:
  /// **'at {time}'**
  String atTime(Object time);

  /// No description provided for @onDate.
  ///
  /// In en, this message translates to:
  /// **'on {date}'**
  String onDate(Object date);

  /// No description provided for @table.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String table(Object number);

  /// No description provided for @seatInfo.
  ///
  /// In en, this message translates to:
  /// **'Seating info'**
  String get seatInfo;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get noItems;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeItem;

  /// No description provided for @maxQuantity.
  ///
  /// In en, this message translates to:
  /// **'Max {quantity}'**
  String maxQuantity(Object quantity);

  /// No description provided for @minQuantity.
  ///
  /// In en, this message translates to:
  /// **'Min {quantity}'**
  String minQuantity(Object quantity);

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @tryDifferentDate.
  ///
  /// In en, this message translates to:
  /// **'Try a different date or party size.'**
  String get tryDifferentDate;

  /// No description provided for @minimumOrder.
  ///
  /// In en, this message translates to:
  /// **'Min. order'**
  String get minimumOrder;

  /// No description provided for @perGuest.
  ///
  /// In en, this message translates to:
  /// **'per guest'**
  String get perGuest;

  /// No description provided for @myFavorites.
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get myFavorites;

  /// No description provided for @favoriteMerchants.
  ///
  /// In en, this message translates to:
  /// **'Merchants'**
  String get favoriteMerchants;

  /// No description provided for @favoriteProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get favoriteProducts;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @noFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on any merchant or product to save it here.'**
  String get noFavoritesMessage;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites;

  /// No description provided for @favoritesTab.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTab;

  /// No description provided for @noGalleryImages.
  ///
  /// In en, this message translates to:
  /// **'No gallery images available yet.'**
  String get noGalleryImages;

  /// No description provided for @addOns.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get addOns;

  /// No description provided for @orderCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Placed!'**
  String get orderCompletedTitle;

  /// No description provided for @orderCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order has been placed successfully. You can track it in real-time.'**
  String get orderCompletedMessage;

  /// No description provided for @estimatedArrivalTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated arrival: {minutes} min'**
  String estimatedArrivalTime(Object minutes);

  /// No description provided for @glassCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Glass Card'**
  String get glassCardLabel;

  /// No description provided for @skeletonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get skeletonLoading;

  /// No description provided for @menuCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get menuCategories;

  /// No description provided for @popularFirst.
  ///
  /// In en, this message translates to:
  /// **'Popular First'**
  String get popularFirst;

  /// No description provided for @priceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get priceLowToHigh;

  /// No description provided for @priceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price: High to Low'**
  String get priceHighToLow;

  /// No description provided for @filterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get filterByCategory;

  /// No description provided for @itemAddedToCartSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} added to cart'**
  String itemAddedToCartSuccess(Object name);

  /// No description provided for @viewFullMenuHint.
  ///
  /// In en, this message translates to:
  /// **'Browse the complete menu'**
  String get viewFullMenuHint;

  /// No description provided for @restaurantGallery.
  ///
  /// In en, this message translates to:
  /// **'Restaurant Gallery'**
  String get restaurantGallery;

  /// No description provided for @shareThisRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Share this restaurant with friends'**
  String get shareThisRestaurant;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an Issue'**
  String get reportIssue;

  /// No description provided for @callRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Call Restaurant'**
  String get callRestaurant;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// No description provided for @topUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get topUp;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// No description provided for @topUpToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Top up your wallet to get started'**
  String get topUpToGetStarted;

  /// No description provided for @selectAmount.
  ///
  /// In en, this message translates to:
  /// **'Select Amount'**
  String get selectAmount;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @confirmTopUp.
  ///
  /// In en, this message translates to:
  /// **'Confirm Top Up'**
  String get confirmTopUp;

  /// No description provided for @loginToViewWallet.
  ///
  /// In en, this message translates to:
  /// **'Please log in to view your wallet'**
  String get loginToViewWallet;

  /// No description provided for @driverDashboard.
  ///
  /// In en, this message translates to:
  /// **'Driver Dashboard'**
  String get driverDashboard;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @totalDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Total Deliveries'**
  String get totalDeliveries;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @vehicleInfo.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Info'**
  String get vehicleInfo;

  /// No description provided for @availableDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Available Deliveries'**
  String get availableDeliveries;

  /// No description provided for @todayRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Revenue'**
  String get todayRevenue;

  /// No description provided for @pendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get pendingOrders;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @fieldRequiredWithName.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String fieldRequiredWithName(Object field);

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalid;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get phoneInvalid;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @fieldMustBeAtLeast.
  ///
  /// In en, this message translates to:
  /// **'{field} must be at least {min} characters'**
  String fieldMustBeAtLeast(Object field, Object min);

  /// No description provided for @fieldMustBeAtMost.
  ///
  /// In en, this message translates to:
  /// **'{field} must be at most {max} characters'**
  String fieldMustBeAtMost(Object field, Object max);

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @twoFactorAuth.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get twoFactorAuth;

  /// No description provided for @loginActivity.
  ///
  /// In en, this message translates to:
  /// **'Login Activity'**
  String get loginActivity;

  /// No description provided for @dataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & Privacy'**
  String get dataPrivacy;

  /// No description provided for @locationSharing.
  ///
  /// In en, this message translates to:
  /// **'Location Sharing'**
  String get locationSharing;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationPreferences;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @work.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get work;

  /// No description provided for @economy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get economy;

  /// No description provided for @comfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get comfort;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @rateYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Rate your trip'**
  String get rateYourTrip;

  /// No description provided for @rateDriverPrompt.
  ///
  /// In en, this message translates to:
  /// **'How was your driver?'**
  String get rateDriverPrompt;

  /// No description provided for @addFeedback.
  ///
  /// In en, this message translates to:
  /// **'Add your feedback...'**
  String get addFeedback;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRating;

  /// No description provided for @noRidesYet.
  ///
  /// In en, this message translates to:
  /// **'No rides yet'**
  String get noRidesYet;

  /// No description provided for @startFirstRide.
  ///
  /// In en, this message translates to:
  /// **'Book your first ride now!'**
  String get startFirstRide;

  /// No description provided for @rideHistory.
  ///
  /// In en, this message translates to:
  /// **'Ride History'**
  String get rideHistory;

  /// No description provided for @rideDetails.
  ///
  /// In en, this message translates to:
  /// **'Ride Details'**
  String get rideDetails;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup Location'**
  String get pickup;

  /// No description provided for @dropoff.
  ///
  /// In en, this message translates to:
  /// **'Dropoff Location'**
  String get dropoff;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fare;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @driverArriving.
  ///
  /// In en, this message translates to:
  /// **'Driver is arriving'**
  String get driverArriving;

  /// No description provided for @inTrip.
  ///
  /// In en, this message translates to:
  /// **'In Trip'**
  String get inTrip;

  /// No description provided for @arrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get arrived;

  /// No description provided for @driverEnRoute.
  ///
  /// In en, this message translates to:
  /// **'Driver is en route'**
  String get driverEnRoute;

  /// No description provided for @shareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share Trip'**
  String get shareTrip;

  /// No description provided for @sos.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get sos;

  /// No description provided for @tripShared.
  ///
  /// In en, this message translates to:
  /// **'Trip shared successfully!'**
  String get tripShared;

  /// No description provided for @emergencyAlert.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alert'**
  String get emergencyAlert;

  /// No description provided for @emergencyConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to call emergency services?'**
  String get emergencyConfirmation;

  /// No description provided for @confirmSOS.
  ///
  /// In en, this message translates to:
  /// **'Confirm SOS'**
  String get confirmSOS;

  /// No description provided for @emergencyServicesNotified.
  ///
  /// In en, this message translates to:
  /// **'Emergency services have been notified.'**
  String get emergencyServicesNotified;

  /// No description provided for @cancelReasonWrongAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong address entered'**
  String get cancelReasonWrongAddress;

  /// No description provided for @cancelReasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'Changed my mind'**
  String get cancelReasonChangedMind;

  /// No description provided for @cancelReasonDriverDelay.
  ///
  /// In en, this message translates to:
  /// **'Driver is taking too long'**
  String get cancelReasonDriverDelay;

  /// No description provided for @cancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get cancelReasonOther;

  /// No description provided for @cancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel Ride'**
  String get cancelRide;

  /// No description provided for @keepRide.
  ///
  /// In en, this message translates to:
  /// **'Keep Ride'**
  String get keepRide;

  /// No description provided for @cheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get cheapest;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium-sized car'**
  String get medium;

  /// No description provided for @luxury.
  ///
  /// In en, this message translates to:
  /// **'Luxury car'**
  String get luxury;

  /// No description provided for @chooseRideType.
  ///
  /// In en, this message translates to:
  /// **'Choose a ride type'**
  String get chooseRideType;

  /// No description provided for @tripProtected.
  ///
  /// In en, this message translates to:
  /// **'Your trip is protected with SOS coverage'**
  String get tripProtected;

  /// No description provided for @confirmRide.
  ///
  /// In en, this message translates to:
  /// **'Confirm Ride'**
  String get confirmRide;

  /// No description provided for @enterDestination.
  ///
  /// In en, this message translates to:
  /// **'Enter destination address'**
  String get enterDestination;

  /// No description provided for @savedPlace.
  ///
  /// In en, this message translates to:
  /// **'Saved place'**
  String get savedPlace;

  /// No description provided for @setDestination.
  ///
  /// In en, this message translates to:
  /// **'Set Destination'**
  String get setDestination;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @trackRide.
  ///
  /// In en, this message translates to:
  /// **'Track Ride'**
  String get trackRide;

  /// No description provided for @matched.
  ///
  /// In en, this message translates to:
  /// **'Driver Matched'**
  String get matched;

  /// No description provided for @pleaseLogIn.
  ///
  /// In en, this message translates to:
  /// **'Please log in'**
  String get pleaseLogIn;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(Object message);

  /// No description provided for @becomeADriver.
  ///
  /// In en, this message translates to:
  /// **'Become a Driver'**
  String get becomeADriver;

  /// No description provided for @joinFleetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join our fleet and start earning'**
  String get joinFleetSubtitle;

  /// No description provided for @registerNow.
  ///
  /// In en, this message translates to:
  /// **'Register Now'**
  String get registerNow;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @noDeliveriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No deliveries available'**
  String get noDeliveriesAvailable;

  /// No description provided for @enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get enterValidAmount;

  /// No description provided for @topUpSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Top-up successful'**
  String get topUpSuccessful;

  /// No description provided for @topUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Top-up failed: {error}'**
  String topUpFailed(Object error);

  /// No description provided for @applePay.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get applePay;

  /// No description provided for @noTrackingData.
  ///
  /// In en, this message translates to:
  /// **'No tracking data'**
  String get noTrackingData;

  /// No description provided for @trackingUpdatesHint.
  ///
  /// In en, this message translates to:
  /// **'Tracking updates will appear here.'**
  String get trackingUpdatesHint;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @currencySymbol.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get currencySymbol;

  /// No description provided for @amountWithCurrency.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency}'**
  String amountWithCurrency(Object amount, Object currency);

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go Online'**
  String get goOnline;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Go Offline'**
  String get goOffline;

  /// No description provided for @youAreOnline.
  ///
  /// In en, this message translates to:
  /// **'You are online'**
  String get youAreOnline;

  /// No description provided for @youAreOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get youAreOffline;

  /// No description provided for @acceptRide.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptRide;

  /// No description provided for @rejectRide.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectRide;

  /// No description provided for @newRideRequest.
  ///
  /// In en, this message translates to:
  /// **'New ride request'**
  String get newRideRequest;

  /// No description provided for @pickupPassenger.
  ///
  /// In en, this message translates to:
  /// **'Pick up passenger'**
  String get pickupPassenger;

  /// No description provided for @startTrip.
  ///
  /// In en, this message translates to:
  /// **'Start Trip'**
  String get startTrip;

  /// No description provided for @finishTrip.
  ///
  /// In en, this message translates to:
  /// **'Finish Trip'**
  String get finishTrip;

  /// No description provided for @arrivedAtPickup.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get arrivedAtPickup;

  /// No description provided for @waitingForPassenger.
  ///
  /// In en, this message translates to:
  /// **'Waiting for passenger'**
  String get waitingForPassenger;

  /// No description provided for @enterPickupOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter pickup code'**
  String get enterPickupOtp;

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpVerification;

  /// No description provided for @invalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get invalidOtp;

  /// No description provided for @tripStarted.
  ///
  /// In en, this message translates to:
  /// **'Trip started'**
  String get tripStarted;

  /// No description provided for @tripCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get tripCompleted;

  /// No description provided for @todayEarnings.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayEarnings;

  /// No description provided for @weeklyEarnings.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get weeklyEarnings;

  /// No description provided for @monthlyEarnings.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get monthlyEarnings;

  /// No description provided for @withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// No description provided for @withdrawRequest.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Request'**
  String get withdrawRequest;

  /// No description provided for @bonuses.
  ///
  /// In en, this message translates to:
  /// **'Bonuses'**
  String get bonuses;

  /// No description provided for @driverDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get driverDocuments;

  /// No description provided for @drivingLicense.
  ///
  /// In en, this message translates to:
  /// **'Driving License'**
  String get drivingLicense;

  /// No description provided for @vehicleRegistration.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Registration'**
  String get vehicleRegistration;

  /// No description provided for @identityDocument.
  ///
  /// In en, this message translates to:
  /// **'Identity Document'**
  String get identityDocument;

  /// No description provided for @uploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get uploadDocument;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get verificationPending;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @vehicleManagement.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Management'**
  String get vehicleManagement;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @vehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Model'**
  String get vehicleModel;

  /// No description provided for @vehiclePlateLabel.
  ///
  /// In en, this message translates to:
  /// **'Plate Number'**
  String get vehiclePlateLabel;

  /// No description provided for @vehicleColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get vehicleColorLabel;

  /// No description provided for @searchingForDriver.
  ///
  /// In en, this message translates to:
  /// **'Searching for a nearby driver...'**
  String get searchingForDriver;

  /// No description provided for @driverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way'**
  String get driverOnTheWay;

  /// No description provided for @driverArrived.
  ///
  /// In en, this message translates to:
  /// **'Your driver has arrived'**
  String get driverArrived;

  /// No description provided for @onTrip.
  ///
  /// In en, this message translates to:
  /// **'On trip'**
  String get onTrip;

  /// No description provided for @estimatedFare.
  ///
  /// In en, this message translates to:
  /// **'Estimated fare'**
  String get estimatedFare;

  /// No description provided for @distanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceLabel;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @kmShort.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kmShort;

  /// No description provided for @rideEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get rideEconomy;

  /// No description provided for @rideComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get rideComfort;

  /// No description provided for @ridePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get ridePremium;

  /// No description provided for @rideXL.
  ///
  /// In en, this message translates to:
  /// **'XL'**
  String get rideXL;

  /// No description provided for @rideMotorbike.
  ///
  /// In en, this message translates to:
  /// **'Motorbike'**
  String get rideMotorbike;

  /// No description provided for @rideTaxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get rideTaxi;

  /// No description provided for @savedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved Places'**
  String get savedPlaces;

  /// No description provided for @addHome.
  ///
  /// In en, this message translates to:
  /// **'Add Home'**
  String get addHome;

  /// No description provided for @addWork.
  ///
  /// In en, this message translates to:
  /// **'Add Work'**
  String get addWork;

  /// No description provided for @homeAddress.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeAddress;

  /// No description provided for @workAddress.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get workAddress;

  /// No description provided for @favoritePlaces.
  ///
  /// In en, this message translates to:
  /// **'Favorite Places'**
  String get favoritePlaces;

  /// No description provided for @searchDestination.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get searchDestination;

  /// No description provided for @confirmPickup.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pickup'**
  String get confirmPickup;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get promoCode;

  /// No description provided for @applyPromo.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyPromo;

  /// No description provided for @promoApplied.
  ///
  /// In en, this message translates to:
  /// **'Promo applied'**
  String get promoApplied;

  /// No description provided for @promoInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid promo code'**
  String get promoInvalid;

  /// No description provided for @tripReceipt.
  ///
  /// In en, this message translates to:
  /// **'Trip Receipt'**
  String get tripReceipt;

  /// No description provided for @baseFare.
  ///
  /// In en, this message translates to:
  /// **'Base fare'**
  String get baseFare;

  /// No description provided for @distanceFare.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distanceFare;

  /// No description provided for @timeFare.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeFare;

  /// No description provided for @surgeFare.
  ///
  /// In en, this message translates to:
  /// **'Surge'**
  String get surgeFare;

  /// No description provided for @totalFare.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalFare;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @rateYourDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate your driver'**
  String get rateYourDriver;

  /// No description provided for @trustedContacts.
  ///
  /// In en, this message translates to:
  /// **'Trusted Contacts'**
  String get trustedContacts;

  /// No description provided for @addTrustedContact.
  ///
  /// In en, this message translates to:
  /// **'Add Trusted Contact'**
  String get addTrustedContact;

  /// No description provided for @shareLiveTrip.
  ///
  /// In en, this message translates to:
  /// **'Share Live Trip'**
  String get shareLiveTrip;

  /// No description provided for @emergencySos.
  ///
  /// In en, this message translates to:
  /// **'Emergency SOS'**
  String get emergencySos;

  /// No description provided for @sosActivated.
  ///
  /// In en, this message translates to:
  /// **'SOS activated - contacting emergency services'**
  String get sosActivated;

  /// No description provided for @complaint.
  ///
  /// In en, this message translates to:
  /// **'Complaint'**
  String get complaint;

  /// No description provided for @fileComplaint.
  ///
  /// In en, this message translates to:
  /// **'File a Complaint'**
  String get fileComplaint;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @favoriteDrivers.
  ///
  /// In en, this message translates to:
  /// **'Favorite Drivers'**
  String get favoriteDrivers;

  /// No description provided for @cancelRideConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel?'**
  String get cancelRideConfirm;

  /// No description provided for @rideCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get rideCancelled;

  /// No description provided for @noActiveRide.
  ///
  /// In en, this message translates to:
  /// **'No active ride'**
  String get noActiveRide;

  /// No description provided for @requestRide.
  ///
  /// In en, this message translates to:
  /// **'Request Ride'**
  String get requestRide;

  /// No description provided for @ridePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter destination'**
  String get ridePlaceholder;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(Object count);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(Object count);

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @builtWithLove.
  ///
  /// In en, this message translates to:
  /// **'Built with love by the Delwaqty team'**
  String get builtWithLove;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// No description provided for @fareBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Fare breakdown'**
  String get fareBreakdown;

  /// No description provided for @driverFound.
  ///
  /// In en, this message translates to:
  /// **'Driver found!'**
  String get driverFound;

  /// No description provided for @noDriversFound.
  ///
  /// In en, this message translates to:
  /// **'No drivers available nearby. Please try again shortly.'**
  String get noDriversFound;

  /// No description provided for @pickupCode.
  ///
  /// In en, this message translates to:
  /// **'Pickup code'**
  String get pickupCode;

  /// No description provided for @shareCodeWithDriver.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your driver at pickup'**
  String get shareCodeWithDriver;

  /// No description provided for @passengers.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get passengers;

  /// No description provided for @luggage.
  ///
  /// In en, this message translates to:
  /// **'Luggage'**
  String get luggage;

  /// No description provided for @choosePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get choosePayment;

  /// No description provided for @promoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Promo removed'**
  String get promoRemoved;

  /// No description provided for @confirmDestination.
  ///
  /// In en, this message translates to:
  /// **'Confirm destination'**
  String get confirmDestination;

  /// No description provided for @waitingForAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Contacting nearby drivers...'**
  String get waitingForAcceptance;

  /// No description provided for @driversNearby.
  ///
  /// In en, this message translates to:
  /// **'{count} drivers nearby'**
  String driversNearby(Object count);

  /// No description provided for @yourDriver.
  ///
  /// In en, this message translates to:
  /// **'Your driver'**
  String get yourDriver;

  /// No description provided for @vehicleDetails.
  ///
  /// In en, this message translates to:
  /// **'Vehicle details'**
  String get vehicleDetails;

  /// No description provided for @arrivesInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Arrives in {minutes} min'**
  String arrivesInMinutes(Object minutes);

  /// No description provided for @bookAnotherRide.
  ///
  /// In en, this message translates to:
  /// **'Book another ride'**
  String get bookAnotherRide;

  /// No description provided for @tripCancelled.
  ///
  /// In en, this message translates to:
  /// **'Trip cancelled'**
  String get tripCancelled;

  /// No description provided for @loadingMap.
  ///
  /// In en, this message translates to:
  /// **'Loading map...'**
  String get loadingMap;

  /// No description provided for @seatsAndBags.
  ///
  /// In en, this message translates to:
  /// **'{seats} seats, {bags} bags'**
  String seatsAndBags(Object bags, Object seats);

  /// No description provided for @seatsOnly.
  ///
  /// In en, this message translates to:
  /// **'{seats} seats'**
  String seatsOnly(Object seats);

  /// No description provided for @rideEconomyDesc.
  ///
  /// In en, this message translates to:
  /// **'Affordable everyday rides'**
  String get rideEconomyDesc;

  /// No description provided for @rideComfortDesc.
  ///
  /// In en, this message translates to:
  /// **'Newer cars with extra legroom'**
  String get rideComfortDesc;

  /// No description provided for @ridePremiumDesc.
  ///
  /// In en, this message translates to:
  /// **'Luxury cars, top-rated drivers'**
  String get ridePremiumDesc;

  /// No description provided for @rideXLDesc.
  ///
  /// In en, this message translates to:
  /// **'Spacious rides for groups'**
  String get rideXLDesc;

  /// No description provided for @rideMotorbikeDesc.
  ///
  /// In en, this message translates to:
  /// **'Fast and cheap for one'**
  String get rideMotorbikeDesc;

  /// No description provided for @rideTaxiDesc.
  ///
  /// In en, this message translates to:
  /// **'Metered street taxis'**
  String get rideTaxiDesc;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @ratings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get ratings;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @arrive.
  ///
  /// In en, this message translates to:
  /// **'Arrive'**
  String get arrive;

  /// No description provided for @ratePassenger.
  ///
  /// In en, this message translates to:
  /// **'Rate passenger'**
  String get ratePassenger;

  /// No description provided for @incomingRequest.
  ///
  /// In en, this message translates to:
  /// **'Incoming ride request'**
  String get incomingRequest;

  /// No description provided for @estimatedEarnings.
  ///
  /// In en, this message translates to:
  /// **'Estimated earnings'**
  String get estimatedEarnings;

  /// No description provided for @driverRides.
  ///
  /// In en, this message translates to:
  /// **'Ride requests'**
  String get driverRides;

  /// No description provided for @activeTrip.
  ///
  /// In en, this message translates to:
  /// **'Active trip'**
  String get activeTrip;

  /// No description provided for @todayRides.
  ///
  /// In en, this message translates to:
  /// **'Today\'s rides'**
  String get todayRides;

  /// No description provided for @acceptanceRate.
  ///
  /// In en, this message translates to:
  /// **'Acceptance rate'**
  String get acceptanceRate;

  /// No description provided for @pendingWithdrawals.
  ///
  /// In en, this message translates to:
  /// **'Pending withdrawals'**
  String get pendingWithdrawals;

  /// No description provided for @withdrawFunds.
  ///
  /// In en, this message translates to:
  /// **'Withdraw funds'**
  String get withdrawFunds;

  /// No description provided for @requestWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Request withdrawal'**
  String get requestWithdrawal;

  /// No description provided for @withdrawalRequested.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal requested'**
  String get withdrawalRequested;

  /// No description provided for @earningsCredited.
  ///
  /// In en, this message translates to:
  /// **'Earnings credited'**
  String get earningsCredited;

  /// No description provided for @waitingForRides.
  ///
  /// In en, this message translates to:
  /// **'Waiting for ride requests'**
  String get waitingForRides;

  /// No description provided for @goOnlineToReceive.
  ///
  /// In en, this message translates to:
  /// **'Go online to receive ride requests'**
  String get goOnlineToReceive;

  /// No description provided for @arrivingAtPickup.
  ///
  /// In en, this message translates to:
  /// **'Head to pickup'**
  String get arrivingAtPickup;

  /// No description provided for @enterOtpToStart.
  ///
  /// In en, this message translates to:
  /// **'Enter the passenger\'s code to start the trip'**
  String get enterOtpToStart;

  /// No description provided for @confirmArrival.
  ///
  /// In en, this message translates to:
  /// **'I have arrived'**
  String get confirmArrival;

  /// No description provided for @completeTrip.
  ///
  /// In en, this message translates to:
  /// **'Complete trip'**
  String get completeTrip;

  /// No description provided for @rateThePassenger.
  ///
  /// In en, this message translates to:
  /// **'Rate the passenger'**
  String get rateThePassenger;

  /// No description provided for @noActiveTrip.
  ///
  /// In en, this message translates to:
  /// **'No active trip'**
  String get noActiveTrip;

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'away'**
  String get away;

  /// No description provided for @callPassenger.
  ///
  /// In en, this message translates to:
  /// **'Call passenger'**
  String get callPassenger;

  /// No description provided for @registerAsRideDriver.
  ///
  /// In en, this message translates to:
  /// **'Register as a ride driver'**
  String get registerAsRideDriver;

  /// No description provided for @plateNumber.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get plateNumber;

  /// No description provided for @vehicleMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get vehicleMake;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @seats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get seats;

  /// No description provided for @withdrawalMethod.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal method'**
  String get withdrawalMethod;

  /// No description provided for @minimumFareNotMet.
  ///
  /// In en, this message translates to:
  /// **'Minimum amount not met'**
  String get minimumFareNotMet;

  /// No description provided for @amountExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds balance'**
  String get amountExceedsBalance;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @earningsHistory.
  ///
  /// In en, this message translates to:
  /// **'Earnings history'**
  String get earningsHistory;

  /// No description provided for @trip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get trip;

  /// No description provided for @bonus.
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get bonus;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @withdrawalType.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get withdrawalType;

  /// No description provided for @adjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get adjustment;

  /// No description provided for @rideNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This ride is no longer available'**
  String get rideNoLongerAvailable;

  /// No description provided for @driverBusy.
  ///
  /// In en, this message translates to:
  /// **'You already have an active trip'**
  String get driverBusy;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentSearches;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get searchResults;

  /// No description provided for @searchOnMap.
  ///
  /// In en, this message translates to:
  /// **'Set on map'**
  String get searchOnMap;

  /// No description provided for @chooseOnMap.
  ///
  /// In en, this message translates to:
  /// **'Choose on map'**
  String get chooseOnMap;

  /// No description provided for @saveThisPlace.
  ///
  /// In en, this message translates to:
  /// **'Save this place'**
  String get saveThisPlace;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get networkError;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add favorite'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeFavorite;

  /// No description provided for @placeSaved.
  ///
  /// In en, this message translates to:
  /// **'Place saved'**
  String get placeSaved;

  /// No description provided for @locationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off'**
  String get locationServicesOff;

  /// No description provided for @rateLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, please wait a moment'**
  String get rateLimitReached;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm location'**
  String get confirmLocation;

  /// No description provided for @setOnMap.
  ///
  /// In en, this message translates to:
  /// **'Set on map'**
  String get setOnMap;

  /// No description provided for @searchPlaceholderCity.
  ///
  /// In en, this message translates to:
  /// **'Search for a place or address'**
  String get searchPlaceholderCity;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Registration'**
  String get onboardingTitle;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @nationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID Number'**
  String get nationalId;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhoto;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @uploadDrivingLicense.
  ///
  /// In en, this message translates to:
  /// **'Upload Driving License'**
  String get uploadDrivingLicense;

  /// No description provided for @uploadVehicleRegistration.
  ///
  /// In en, this message translates to:
  /// **'Upload Vehicle Registration'**
  String get uploadVehicleRegistration;

  /// No description provided for @insurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get insurance;

  /// No description provided for @uploadInsurance.
  ///
  /// In en, this message translates to:
  /// **'Upload Insurance Document'**
  String get uploadInsurance;

  /// No description provided for @vehicleCategory.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Category'**
  String get vehicleCategory;

  /// No description provided for @vehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Year'**
  String get vehicleYear;

  /// No description provided for @vehicleColor.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Color'**
  String get vehicleColor;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @submitRegistration.
  ///
  /// In en, this message translates to:
  /// **'Submit Registration'**
  String get submitRegistration;

  /// No description provided for @registrationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Registration submitted successfully'**
  String get registrationSubmitted;

  /// No description provided for @registrationPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Your registration is pending admin approval'**
  String get registrationPendingApproval;

  /// No description provided for @editVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit Vehicle'**
  String get editVehicle;

  /// No description provided for @vehicleActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get vehicleActive;

  /// No description provided for @vehicleInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get vehicleInactive;

  /// No description provided for @vehicleVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get vehicleVerified;

  /// No description provided for @vehicleNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Not Verified'**
  String get vehicleNotVerified;

  /// No description provided for @noVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles registered yet'**
  String get noVehicles;

  /// No description provided for @documentManagement.
  ///
  /// In en, this message translates to:
  /// **'Document Management'**
  String get documentManagement;

  /// No description provided for @vehiclePhoto.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Photo'**
  String get vehiclePhoto;

  /// No description provided for @documentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get documentPending;

  /// No description provided for @documentVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get documentVerified;

  /// No description provided for @documentRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get documentRejected;

  /// No description provided for @noDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents uploaded yet'**
  String get noDocuments;

  /// No description provided for @replaceDocument.
  ///
  /// In en, this message translates to:
  /// **'Replace Document'**
  String get replaceDocument;

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires on'**
  String get expiresOn;

  /// No description provided for @rejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get rejectionReason;

  /// No description provided for @walletBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Wallet Breakdown'**
  String get walletBreakdown;

  /// No description provided for @bonusBalance.
  ///
  /// In en, this message translates to:
  /// **'Bonuses'**
  String get bonusBalance;

  /// No description provided for @incentiveBalance.
  ///
  /// In en, this message translates to:
  /// **'Incentives'**
  String get incentiveBalance;

  /// No description provided for @totalWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Total Withdrawn'**
  String get totalWithdrawn;

  /// No description provided for @completedTrips.
  ///
  /// In en, this message translates to:
  /// **'Completed Trips'**
  String get completedTrips;

  /// No description provided for @cancelledTrips.
  ///
  /// In en, this message translates to:
  /// **'Cancelled Trips'**
  String get cancelledTrips;

  /// No description provided for @cancellationRate.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Rate'**
  String get cancellationRate;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(Object current, Object total);

  /// No description provided for @tapToUpload.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload'**
  String get tapToUpload;

  /// No description provided for @uploadComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Upload functionality will be available soon'**
  String get uploadComingSoon;

  /// No description provided for @tawsila.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get tawsila;

  /// No description provided for @tawsilaDesc.
  ///
  /// In en, this message translates to:
  /// **'Book your ride anytime'**
  String get tawsilaDesc;

  /// No description provided for @directDelivery.
  ///
  /// In en, this message translates to:
  /// **'Direct Delivery'**
  String get directDelivery;

  /// No description provided for @directDeliveryDesc.
  ///
  /// In en, this message translates to:
  /// **'Request direct delivery for any order'**
  String get directDeliveryDesc;

  /// No description provided for @directDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct Delivery'**
  String get directDeliveryTitle;

  /// No description provided for @directDeliverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'A driver will fetch your order from anywhere'**
  String get directDeliverySubtitle;

  /// No description provided for @whereToDeliver.
  ///
  /// In en, this message translates to:
  /// **'Where to deliver?'**
  String get whereToDeliver;

  /// No description provided for @pickupFrom.
  ///
  /// In en, this message translates to:
  /// **'Pick up from?'**
  String get pickupFrom;

  /// No description provided for @describeYourOrder.
  ///
  /// In en, this message translates to:
  /// **'Describe your order'**
  String get describeYourOrder;

  /// No description provided for @requestDelivery.
  ///
  /// In en, this message translates to:
  /// **'Request Delivery'**
  String get requestDelivery;

  /// No description provided for @superAdmin.
  ///
  /// In en, this message translates to:
  /// **'SuperAdmin'**
  String get superAdmin;

  /// No description provided for @deliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get deliverTo;

  /// No description provided for @setMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Set my location'**
  String get setMyLocation;

  /// No description provided for @placeDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe the location or landmark'**
  String get placeDescription;

  /// No description provided for @placeDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Near the pharmacy, building 5, apartment 3'**
  String get placeDescriptionHint;

  /// No description provided for @customerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get customerPhone;

  /// No description provided for @customerPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Your phone number for the driver'**
  String get customerPhoneHint;

  /// No description provided for @saveNumber.
  ///
  /// In en, this message translates to:
  /// **'Save number'**
  String get saveNumber;

  /// No description provided for @numberSaved.
  ///
  /// In en, this message translates to:
  /// **'Phone number saved'**
  String get numberSaved;

  /// No description provided for @shoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingList;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get itemName;

  /// No description provided for @itemPrice.
  ///
  /// In en, this message translates to:
  /// **'Estimated price'**
  String get itemPrice;

  /// No description provided for @itemQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get itemQuantity;

  /// No description provided for @purchaseApproval.
  ///
  /// In en, this message translates to:
  /// **'Purchase Approval'**
  String get purchaseApproval;

  /// No description provided for @approvePurchase.
  ///
  /// In en, this message translates to:
  /// **'Approve Purchase'**
  String get approvePurchase;

  /// No description provided for @rejectPurchase.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectPurchase;

  /// No description provided for @totalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get totalCost;

  /// No description provided for @serviceFee.
  ///
  /// In en, this message translates to:
  /// **'Service Fee'**
  String get serviceFee;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// No description provided for @invoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoice;

  /// No description provided for @invoiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Invoice Details'**
  String get invoiceDetails;

  /// No description provided for @previousOrders.
  ///
  /// In en, this message translates to:
  /// **'My Previous Orders'**
  String get previousOrders;

  /// No description provided for @noPreviousOrders.
  ///
  /// In en, this message translates to:
  /// **'No previous orders yet'**
  String get noPreviousOrders;

  /// No description provided for @purchaseStarted.
  ///
  /// In en, this message translates to:
  /// **'Driver started purchasing'**
  String get purchaseStarted;

  /// No description provided for @purchaseStartedDescription.
  ///
  /// In en, this message translates to:
  /// **'The driver has started buying your items'**
  String get purchaseStartedDescription;

  /// No description provided for @priceListReceived.
  ///
  /// In en, this message translates to:
  /// **'Price list received'**
  String get priceListReceived;

  /// No description provided for @priceListDescription.
  ///
  /// In en, this message translates to:
  /// **'Please review the costs and approve'**
  String get priceListDescription;

  /// No description provided for @approveBeforePurchase.
  ///
  /// In en, this message translates to:
  /// **'You must approve the purchase before the driver buys'**
  String get approveBeforePurchase;

  /// No description provided for @orderItems.
  ///
  /// In en, this message translates to:
  /// **'Order Items'**
  String get orderItems;

  /// No description provided for @priceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Price Breakdown'**
  String get priceBreakdown;

  /// No description provided for @deliveryCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get deliveryCostLabel;

  /// No description provided for @serviceFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceFeeLabel;

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// No description provided for @safetySettings.
  ///
  /// In en, this message translates to:
  /// **'Safety Settings'**
  String get safetySettings;

  /// No description provided for @sosSettings.
  ///
  /// In en, this message translates to:
  /// **'SOS Settings'**
  String get sosSettings;

  /// No description provided for @sosAlertEnabled.
  ///
  /// In en, this message translates to:
  /// **'SOS Alert'**
  String get sosAlertEnabled;

  /// No description provided for @sosAlertEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable emergency SOS alerts during rides'**
  String get sosAlertEnabledDescription;

  /// No description provided for @autoSosTimer.
  ///
  /// In en, this message translates to:
  /// **'Auto SOS Timer'**
  String get autoSosTimer;

  /// No description provided for @autoSosTimerDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically trigger SOS after a timer'**
  String get autoSosTimerDescription;

  /// No description provided for @tripSharing.
  ///
  /// In en, this message translates to:
  /// **'Trip Sharing'**
  String get tripSharing;

  /// No description provided for @autoShareTrip.
  ///
  /// In en, this message translates to:
  /// **'Auto Share Trip'**
  String get autoShareTrip;

  /// No description provided for @autoShareTripDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically share trip with trusted contacts'**
  String get autoShareTripDescription;

  /// No description provided for @shareDuration.
  ///
  /// In en, this message translates to:
  /// **'Share Duration'**
  String get shareDuration;

  /// No description provided for @emergencyContacts.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contacts'**
  String get emergencyContacts;

  /// No description provided for @pickupVerification.
  ///
  /// In en, this message translates to:
  /// **'Pickup Verification'**
  String get pickupVerification;

  /// No description provided for @pickupOtpRequired.
  ///
  /// In en, this message translates to:
  /// **'Pickup Code Required'**
  String get pickupOtpRequired;

  /// No description provided for @pickupOtpRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'Require a code from the driver before starting trip'**
  String get pickupOtpRequiredDescription;

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get errorLoadingData;

  /// No description provided for @noTrustedContacts.
  ///
  /// In en, this message translates to:
  /// **'No trusted contacts yet'**
  String get noTrustedContacts;

  /// No description provided for @addTrustedContactsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add trusted contacts to be notified during your trips'**
  String get addTrustedContactsDescription;

  /// No description provided for @family.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get family;

  /// No description provided for @friend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get friend;

  /// No description provided for @colleague.
  ///
  /// In en, this message translates to:
  /// **'Colleague'**
  String get colleague;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @pushNotification.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get pushNotification;

  /// No description provided for @both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get both;

  /// No description provided for @deleteContact.
  ///
  /// In en, this message translates to:
  /// **'Delete Contact'**
  String get deleteContact;

  /// No description provided for @deleteContactConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from your trusted contacts?'**
  String deleteContactConfirmation(Object name);

  /// No description provided for @editContact.
  ///
  /// In en, this message translates to:
  /// **'Edit Contact'**
  String get editContact;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @relationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationship;

  /// No description provided for @notifyOnRide.
  ///
  /// In en, this message translates to:
  /// **'Notify on ride'**
  String get notifyOnRide;

  /// No description provided for @notifyOnRideDescription.
  ///
  /// In en, this message translates to:
  /// **'Get notified when this contact is on a ride'**
  String get notifyOnRideDescription;

  /// No description provided for @notificationMethod.
  ///
  /// In en, this message translates to:
  /// **'Notification method'**
  String get notificationMethod;

  /// No description provided for @notificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get notificationsDisabled;

  /// No description provided for @addLabel.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addLabel;

  /// No description provided for @editLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editLabel;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @deleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
