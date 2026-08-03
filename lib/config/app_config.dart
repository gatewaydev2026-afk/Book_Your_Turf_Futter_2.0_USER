// lib/config/app_config.dart
// ✅ SINGLE SOURCE OF TRUTH FOR ALL DOMAIN AND CONFIGURATION VALUES

class AppConfig {
  // ============================================================
  // 🔥 BACKEND DOMAIN - CHANGE THIS ONE PLACE FOR ALL APIS
  // ============================================================
  static const String baseUrl = 'https://test.backend.arcmedialabs.in';
  static const String apiBaseUrl = '$baseUrl/api';

  // ============================================================
  // 🔑 API KEYS
  // ============================================================
  static const String googleMapsApiKey = 'AIzaSyBQ6kiaROyTfm7TLKG2c_FA1XER8IVaMlY';
  static const String razorpayKey = 'rzp_live_Rn1hHzY0kkjXFj';

  // ============================================================
  // 📍 LOCATION DEFAULTS
  // ============================================================
  static const double maxDistanceKm = 25.0;
  static const int defaultPageSize = 20;

  // ============================================================
  // ⏱️ CACHE DURATIONS
  // ============================================================
  static const Duration cacheDuration = Duration(minutes: 15);
  static const Duration tokenCacheDuration = Duration(days: 7);
  static const Duration discountCacheDuration = Duration(minutes: 5);
  static const Duration profileCacheDuration = Duration(minutes: 5);
  static const Duration notificationCacheDuration = Duration(minutes: 5);
  static const Duration bookingCacheDuration = Duration(minutes: 5);
  static const Duration walletCacheDuration = Duration(minutes: 5);
  static const Duration coinCacheDuration = Duration(minutes: 5);

  // ============================================================
  // ⏱️ DUPLICATE API CALL PREVENTION
  // ============================================================
  static const Duration minFetchInterval = Duration(seconds: 3);
  static const Duration refreshDebounceDuration = Duration(milliseconds: 500);
  static const Duration locationDebounceDuration = Duration(seconds: 2);
  static const Duration notificationDebounceDuration = Duration(seconds: 2);

  // ============================================================
  // 📄 PAGINATION
  // ============================================================
  static const int pageSize = 20;

  // ============================================================
  // 🔔 NOTIFICATION CLEANUP
  // ============================================================
  static const int maxProcessedNotificationIds = 100;
  static const Duration notificationCleanupInterval = Duration(minutes: 5);

  // ============================================================
  // 🔐 OTP & AUTH
  // ============================================================
  static const int otpValidDuration = 60; // seconds
  static const int otpResendCooldown = 60; // seconds

  // ============================================================
  // 📱 UPDATE CHECK
  // ============================================================
  static const int updateCheckInterval = 24; // hours

  // ============================================================
  // 🌐 API ENDPOINTS - AUTH
  // ============================================================
  static String get authLogin => '$apiBaseUrl/user/login/';
  static String get authRegister => '$apiBaseUrl/user/register/';
  static String get authSendOtp => '$apiBaseUrl/user/send-otp/';
  static String get authResendOtp => '$apiBaseUrl/user/resend-otp/';
  static String get authVerifyOtp => '$apiBaseUrl/user/verify-register/';
  static String get authForgotPasswordOtp => '$apiBaseUrl/user/forgot-password-otp/';
  static String get authResetPassword => '$apiBaseUrl/user/reset-password/';

  // ============================================================
  // 👤 USER PROFILE
  // ============================================================
  static String get profile => '$apiBaseUrl/user/profile/';
  static String get profileUpdate => '$apiBaseUrl/user/profile/';

  // ============================================================
  // 🏟️ TURFS
  // ============================================================
  static String get turfs => '$apiBaseUrl/user/turfs/';
  static String get turfsCalendar => '$apiBaseUrl/user/{turfId}/calendar/';

  // ============================================================
  // ❤️ FAVORITES
  // ============================================================
  static String get favorites => '$apiBaseUrl/user/favorites/';
  static String get toggleFavorite => '$apiBaseUrl/user/favorites/toggle/';

  // ============================================================
  // 📋 BOOKINGS
  // ============================================================
  static String get bookings => '$apiBaseUrl/user/bookings/';
  static String get initiateBooking => '$apiBaseUrl/user/bookings/initiate/';
  static String get confirmBooking => '$apiBaseUrl/user/bookings/confirm/';
  static String get walletBook => '$apiBaseUrl/user/bookings/wallet-book/';
  static String get cancelBooking => '$apiBaseUrl/user/bookings/cancel/';
  static String get payBalance => '$apiBaseUrl/user/bookings/pay-balance/';
  static String get confirmBalance => '$apiBaseUrl/user/bookings/confirm-balance/';
  static String get payBalanceWallet => '$apiBaseUrl/user/bookings/pay-balance-wallet/';

  // ============================================================
  // 💰 WALLET
  // ============================================================
  static String get walletTransactions => '$apiBaseUrl/user/wallet/transactions/';
  static String get walletRechargeInitiate => '$apiBaseUrl/user/wallet/recharge/initiate/';
  static String get walletRechargeConfirm => '$apiBaseUrl/user/wallet/recharge/confirm/';

  // ============================================================
  // 🪙 COINS
  // ============================================================
  static String get coinTransactions => '$apiBaseUrl/user/coins/transactions/';
  static String get convertCoins => '$apiBaseUrl/user/convert-coins/';

  // ============================================================
  // 🏷️ DISCOUNTS
  // ============================================================
  static String get applicableDiscounts => '$apiBaseUrl/user/applicable-discounts/';

  // ============================================================
  // 📱 DEVICE MANAGEMENT
  // ============================================================
  static String get deviceToken => '$apiBaseUrl/user/device-token/';
  static String get deviceTokenUpdate => '$apiBaseUrl/user/device-token/update/';
  static String get deviceLocation => '$apiBaseUrl/user/device-token/location/';
  static String get devices => '$apiBaseUrl/user/devices/';
  static String get deviceCheck => '$apiBaseUrl/user/devices/check/';
  static String get deviceLogout => '$apiBaseUrl/user/devices/logout/';
  static String get deviceId => '$apiBaseUrl/user/device-id/';

  // ============================================================
  // 🔔 NOTIFICATIONS
  // ============================================================
  static String get notifications => '$apiBaseUrl/user/notifications/history/';
  static String markNotificationRead(int id) => '$apiBaseUrl/user/notifications/mark-read/$id/';
  static String get markAllNotificationsRead => '$apiBaseUrl/user/notifications/mark-all-read/';

  // ============================================================
  // 📲 APP VERSION
  // ============================================================
  static String get appVersion => '$apiBaseUrl/user/app-version/';
  static String get appVersionAlt => '$baseUrl/api/version/';

  // ============================================================
  // 🗺️ GOOGLE MAPS
  // ============================================================
  static String geocodeUrl(double lat, double lng) =>
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$googleMapsApiKey';

  // ============================================================
  // 🔗 DEEP LINK & STORE LINKS
  // ============================================================
  static String get playStoreLink => 'https://play.google.com/store/apps/details?id=com.book_your_turf.app';
  static String get appStoreLink => 'https://apps.apple.com/in/app/book_your_turf/id6756934347';

  static String generateShareLink(String code) =>
      '$playStoreLink&referral_code=$code';

  static String generateDeepLinkScheme(String code) =>
      'book_your_turf://refer/$code';

  // ============================================================
  // 🌍 ENVIRONMENT
  // ============================================================
  static const String environment = 'production';

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isStaging => environment == 'staging';

  // ============================================================
  // 📊 LOGGING
  // ============================================================
  static const bool enableLogging = true;
  static const bool enableApiLogging = true;
}