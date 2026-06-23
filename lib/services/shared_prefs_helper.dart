// services/shared_prefs_helper.dart
// ✅ Updated with secure device ID methods

import 'package:shared_preferences/shared_preferences.dart';
import 'secure_device_id_service.dart'; // ✅ Import new service

class SharedPrefsHelper {
  static late SharedPreferences _prefs;

  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyTokenExpiry = 'token_expiry';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyWalletBalance = 'wallet_balance';
  static const String _keyGameCoins = 'game_coins';
  static const String _keyReferralCode = 'referral_code';
  static const String _keyPendingReferralCode = 'pending_referral_code';
  static const String _keyLastTokenRegistration = 'last_token_registration';
  static const String _keyTurfsCache = 'cached_turfs';
  static const String _keyLastTurfsFetch = 'last_turfs_fetch';
  static const String _keyNotificationsCache = 'notifications_cache';
  static const String _keyLastUpdateCheck = 'last_update_check';
  static const String _keyLastProfileFetch = 'last_profile_fetch';

  // Device Management Keys (now using secure storage)
  static const String _keyDeviceRegistered = 'device_registered';
  static const String _keyDeviceLocation = 'device_location';
  static const String _keyLocationUpdatedAt = 'location_updated_at';
  static const String _keyCurrentDeviceId = 'current_device_id';

  static Future<void> init() async => _prefs = await SharedPreferences.getInstance();

  // ========== FIRST LAUNCH ==========
  static Future<void> setFirstLaunch(bool isFirst) async => await _prefs.setBool(_keyFirstLaunch, isFirst);
  static bool isFirstLaunch() => _prefs.getBool(_keyFirstLaunch) ?? true;

  // ========== AUTH WITH TOKEN EXPIRY ==========
  static Future<void> setToken(String token) async {
    await _prefs.setString(_keyAuthToken, token);
    final expiry = DateTime.now().add(const Duration(days: 7));
    await _prefs.setString(_keyTokenExpiry, expiry.toIso8601String());
    print('🔑 Token saved (expires: ${expiry.toLocal().toString().substring(0, 16)})');
  }

  static String? getToken() => _prefs.getString(_keyAuthToken);

  static DateTime? getTokenExpiry() {
    final expiryStr = _prefs.getString(_keyTokenExpiry);
    if (expiryStr == null) return null;
    try {
      return DateTime.parse(expiryStr);
    } catch (e) {
      return null;
    }
  }

  static bool isTokenValid() {
    final expiry = getTokenExpiry();
    if (expiry == null) return false;
    final isValid = DateTime.now().isBefore(expiry);
    if (!isValid) {
      print('⚠️ Token expired on ${expiry.toLocal().toString().substring(0, 16)}');
    }
    return isValid;
  }

  static Future<void> clearToken() async {
    await _prefs.remove(_keyAuthToken);
    await _prefs.remove(_keyTokenExpiry);
  }

  // ========== USER ID WITH TYPE HANDLING ==========
  static Future<void> setUserId(dynamic id) async {
    int userId;
    if (id is int) {
      userId = id;
    } else if (id is String) {
      userId = int.tryParse(id) ?? 0;
    } else if (id is double) {
      userId = id.toInt();
    } else {
      userId = 0;
    }
    await _prefs.setInt(_keyUserId, userId);
  }

  static int? getUserId() => _prefs.getInt(_keyUserId);

  // ========== USER DATA ==========
  static Future<void> setUserName(String name) async => await _prefs.setString(_keyUserName, name);
  static String? getUserName() => _prefs.getString(_keyUserName);

  static Future<void> setUserEmail(String email) async => await _prefs.setString(_keyUserEmail, email);
  static String? getUserEmail() => _prefs.getString(_keyUserEmail);

  static Future<void> setUserPhone(String phone) async => await _prefs.setString(_keyUserPhone, phone);
  static String? getUserPhone() => _prefs.getString(_keyUserPhone);

  // ========== BALANCES ==========
  static Future<void> setWalletBalance(double balance) async => await _prefs.setDouble(_keyWalletBalance, balance);
  static double getWalletBalance() => _prefs.getDouble(_keyWalletBalance) ?? 0.0;

  static Future<void> setGameCoins(int coins) async => await _prefs.setInt(_keyGameCoins, coins);
  static int getGameCoins() => _prefs.getInt(_keyGameCoins) ?? 0;

  static Future<void> setReferralCode(String code) async => await _prefs.setString(_keyReferralCode, code);
  static String? getReferralCode() => _prefs.getString(_keyReferralCode);

  // ========== DEEP LINK ==========
  static Future<void> setPendingReferralCode(String code) async => await _prefs.setString(_keyPendingReferralCode, code);
  static Future<String?> getPendingReferralCode() async => _prefs.getString(_keyPendingReferralCode);
  static Future<void> clearPendingReferralCode() async => await _prefs.remove(_keyPendingReferralCode);

  // ========== TOKEN REGISTRATION ==========
  static Future<void> setLastTokenRegistration(DateTime? date) async {
    if (date == null) {
      await _prefs.remove(_keyLastTokenRegistration);
    } else {
      await _prefs.setString(_keyLastTokenRegistration, date.toIso8601String());
    }
  }

  static Future<DateTime?> getLastTokenRegistration() async {
    final timestamp = _prefs.getString(_keyLastTokenRegistration);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  static Future<bool> isTokenRegistrationValid() async {
    final lastReg = await getLastTokenRegistration();
    if (lastReg == null) return false;
    return DateTime.now().difference(lastReg).inDays < 7;
  }

  // ========== UPDATE CHECK ==========
  static Future<void> setLastUpdateCheck(DateTime time) async {
    await _prefs.setString(_keyLastUpdateCheck, time.toIso8601String());
  }

  static DateTime? getLastUpdateCheck() {
    final timeStr = _prefs.getString(_keyLastUpdateCheck);
    if (timeStr == null) return null;
    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }

  static bool shouldCheckForUpdate() {
    final lastCheck = getLastUpdateCheck();
    if (lastCheck == null) return true;
    return DateTime.now().difference(lastCheck).inHours >= 24;
  }

  // ========== ✅ FIXED: DEVICE ID (USES SECURE STORAGE) ==========
  // ✅ Now uses SecureDeviceIdService which stores in iOS Keychain / Android EncryptedSharedPreferences

  static Future<String> getDeviceId() async {
    return await SecureDeviceIdService.getCachedDeviceId();
  }

  static Future<void> clearDeviceId() async {
    await SecureDeviceIdService.clearDeviceId();
    SecureDeviceIdService.clearCache();
  }

  // ========== LOCATION STORAGE ==========
  static Future<void> saveDeviceLocation(String location) async {
    await _prefs.setString(_keyDeviceLocation, location);
    await _prefs.setString(_keyLocationUpdatedAt, DateTime.now().toIso8601String());
    print('📍 Location saved: $location');
  }

  static String? getDeviceLocation() => _prefs.getString(_keyDeviceLocation);

  static Future<DateTime?> getLocationUpdatedAt() async {
    final timestamp = _prefs.getString(_keyLocationUpdatedAt);
    if (timestamp == null) return null;
    return DateTime.tryParse(timestamp);
  }

  static Future<bool> isLocationValid() async {
    final updatedAt = await getLocationUpdatedAt();
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt).inHours < 1;
  }

  // ========== NOTIFICATIONS CACHE ==========
  static Future<void> setNotificationsCache(String jsonData) async => await _prefs.setString(_keyNotificationsCache, jsonData);
  static Future<String?> getNotificationsCache() async => _prefs.getString(_keyNotificationsCache);
  static Future<void> clearNotificationsCache() async => await _prefs.remove(_keyNotificationsCache);

  // ========== TURFS CACHE ==========
  static Future<void> cacheTurfs(String turfsJson) async {
    await _prefs.setString(_keyTurfsCache, turfsJson);
    await _prefs.setString(_keyLastTurfsFetch, DateTime.now().toIso8601String());
  }

  static String? getCachedTurfs() => _prefs.getString(_keyTurfsCache);

  static bool isTurfsCacheValid() {
    final lastFetch = _prefs.getString(_keyLastTurfsFetch);
    if (lastFetch == null) return false;
    final lastFetchTime = DateTime.tryParse(lastFetch);
    if (lastFetchTime == null) return false;
    return DateTime.now().difference(lastFetchTime).inMinutes < 10;
  }

  // ========== DEVICE REGISTRATION FLAG ==========
  static Future<void> setDeviceRegistered(bool registered) async => await _prefs.setBool(_keyDeviceRegistered, registered);
  static bool isDeviceRegistered() => _prefs.getBool(_keyDeviceRegistered) ?? false;

  static Future<void> setCurrentDeviceId(String deviceId) async => await _prefs.setString(_keyCurrentDeviceId, deviceId);
  static String? getCurrentDeviceId() => _prefs.getString(_keyCurrentDeviceId);

  // ========== PROFILE CACHE ==========
  static Future<void> setLastProfileFetch(DateTime time) async {
    await _prefs.setString(_keyLastProfileFetch, time.toIso8601String());
  }

  static DateTime? getLastProfileFetch() {
    final timeStr = _prefs.getString(_keyLastProfileFetch);
    if (timeStr == null) return null;
    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }

  static bool isProfileCacheValid() {
    final lastFetch = getLastProfileFetch();
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch).inSeconds < 30;
  }

  // ========== LOGIN CHECK ==========
  static bool isLoggedIn() {
    final token = getToken();
    return token != null && token.isNotEmpty && isTokenValid();
  }

  // ========== CLEAR ALL (PRESERVES DEVICE ID IN SECURE STORAGE) ==========
  static Future<void> clearAll() async {
    final deviceLocation = _prefs.getString(_keyDeviceLocation);
    final locationTime = _prefs.getString(_keyLocationUpdatedAt);

    await _prefs.clear();

    // ✅ DO NOT clear device ID - it's stored in secure storage
    // Device ID persists across reinstalls via Keychain/EncryptedSharedPreferences

    if (deviceLocation != null && deviceLocation.isNotEmpty) {
      await _prefs.setString(_keyDeviceLocation, deviceLocation);
    }
    if (locationTime != null && locationTime.isNotEmpty) {
      await _prefs.setString(_keyLocationUpdatedAt, locationTime);
    }

    // Clear cache
    SecureDeviceIdService.clearCache();

    print('🗑️ All cleared (device_id preserved in secure storage)');
  }
}