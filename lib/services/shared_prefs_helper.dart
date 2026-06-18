// services/shared_prefs_helper.dart
// ✅ Complete with device ID and location storage

import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  static late SharedPreferences _prefs;

  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyAuthToken = 'auth_token';
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

  // ✅ Device Management Keys
  static const String _keyDeviceId = 'persistent_device_id';
  static const String _keyDeviceRegistered = 'device_registered';
  static const String _keyDeviceLocation = 'device_location';
  static const String _keyLocationUpdatedAt = 'location_updated_at';
  static const String _keyCurrentDeviceId = 'current_device_id';

  static Future<void> init() async => _prefs = await SharedPreferences.getInstance();

  // ========== FIRST LAUNCH ==========
  static Future<void> setFirstLaunch(bool isFirst) async => await _prefs.setBool(_keyFirstLaunch, isFirst);
  static bool isFirstLaunch() => _prefs.getBool(_keyFirstLaunch) ?? true;

  // ========== AUTH ==========
  static Future<void> setToken(String token) async => await _prefs.setString(_keyAuthToken, token);
  static String? getToken() => _prefs.getString(_keyAuthToken);
  static Future<void> setUserId(int id) async => await _prefs.setInt(_keyUserId, id);
  static int? getUserId() => _prefs.getInt(_keyUserId);
  static Future<void> setUserName(String name) async => await _prefs.setString(_keyUserName, name);
  static String? getUserName() => _prefs.getString(_keyUserName);
  static Future<void> setUserEmail(String email) async => await _prefs.setString(_keyUserEmail, email);
  static String? getUserEmail() => _prefs.getString(_keyUserEmail);
  static Future<void> setUserPhone(String phone) async => await _prefs.setString(_keyUserPhone, phone);
  static String? getUserPhone() => _prefs.getString(_keyUserPhone);

  // ========== BALANCES ==========
  static Future<void> setWalletBalance(double balance) async => await _prefs.setDouble(_keyWalletBalance, balance);
  static double? getWalletBalance() => _prefs.getDouble(_keyWalletBalance);
  static Future<void> setGameCoins(int coins) async => await _prefs.setInt(_keyGameCoins, coins);
  static int? getGameCoins() => _prefs.getInt(_keyGameCoins);
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

  // ========== DEVICE ID (PERSISTENT - NEVER CLEARED) ==========
  static Future<String> getDeviceId() async {
    String? deviceId = _prefs.getString(_keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      await _prefs.setString(_keyDeviceId, deviceId);
      print('📱 Generated new device ID: $deviceId');
    }
    return deviceId;
  }

  static String _generateDeviceId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().hashCode.abs()}';
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

  // ========== CLEAR ALL (PRESERVES DEVICE ID AND LOCATION) ==========
  static Future<void> clearAll() async {
    final deviceId = _prefs.getString(_keyDeviceId);
    final deviceLocation = _prefs.getString(_keyDeviceLocation);
    final locationTime = _prefs.getString(_keyLocationUpdatedAt);

    await _prefs.clear();

    if (deviceId != null && deviceId.isNotEmpty) {
      await _prefs.setString(_keyDeviceId, deviceId);
    }
    if (deviceLocation != null && deviceLocation.isNotEmpty) {
      await _prefs.setString(_keyDeviceLocation, deviceLocation);
    }
    if (locationTime != null && locationTime.isNotEmpty) {
      await _prefs.setString(_keyLocationUpdatedAt, locationTime);
    }
    print('🗑️ All cleared (device_id and location preserved)');
  }

  static bool isLoggedIn() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }
}