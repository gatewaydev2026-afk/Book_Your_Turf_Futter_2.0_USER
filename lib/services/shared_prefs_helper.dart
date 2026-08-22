// services/shared_prefs_helper.dart
// ✅ COMPLETE - With Phone Auth Support

import 'package:book_your_turf/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'secure_device_id_service.dart';

class SharedPrefsHelper {
  static late SharedPreferences _prefs;

  // ========== KEYS ==========
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
  static const String _keyDeviceLocation = 'device_location';
  static const String _keyLocationUpdatedAt = 'location_updated_at';
  static const String _keyDeviceRegistered = 'device_registered';
  static const String _keyPermanentDeviceId = 'permanent_device_id';
  static const String _keyDeviceIdBackup = 'device_id_backup';
  static const String _keySessionId = 'session_id';
  static const String _keyLastLogoutTime = 'last_logout_time';
  static const String _keyAppInitialized = 'app_initialized';

  // ✅ Phone Auth specific keys
  static const String _keyIsPhoneAuthUser = 'is_phone_auth_user';
  static const String _keyIsNumberVerified = 'is_number_verified';
  static const String _keyIsNewUser = 'is_new_user';
  static const String _keyProfileComplete = 'profile_complete';

  static Future<void> init() async => _prefs = await SharedPreferences.getInstance();

  // ========== SESSION MANAGEMENT ==========

  static Future<void> setSessionId(String sessionId) async {
    await _prefs.setString(_keySessionId, sessionId);
  }

  static String? getSessionId() => _prefs.getString(_keySessionId);

  static Future<void> setLastLogoutTime(DateTime time) async {
    await _prefs.setString(_keyLastLogoutTime, time.toIso8601String());
  }

  static DateTime? getLastLogoutTime() {
    final timeStr = _prefs.getString(_keyLastLogoutTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  static Future<void> setAppInitialized(bool initialized) async {
    await _prefs.setBool(_keyAppInitialized, initialized);
  }

  static bool isAppInitialized() => _prefs.getBool(_keyAppInitialized) ?? false;

  // ========== FIRST LAUNCH ==========
  static Future<void> setFirstLaunch(bool isFirst) async => await _prefs.setBool(_keyFirstLaunch, isFirst);
  static bool isFirstLaunch() => _prefs.getBool(_keyFirstLaunch) ?? true;

  // ========== AUTH WITH TOKEN EXPIRY ==========
  static Future<void> setToken(String token) async {
    await _prefs.setString(_keyAuthToken, token);
    final expiry = DateTime.now().add(AppConfig.tokenCacheDuration);
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

  // ========== PHONE AUTH SPECIFIC ==========
  static Future<void> setIsPhoneAuthUser(bool value) async {
    await _prefs.setBool(_keyIsPhoneAuthUser, value);
  }

  static bool getIsPhoneAuthUser() {
    return _prefs.getBool(_keyIsPhoneAuthUser) ?? false;
  }

  static Future<void> setIsNumberVerified(bool value) async {
    await _prefs.setBool(_keyIsNumberVerified, value);
  }

  static bool getIsNumberVerified() {
    return _prefs.getBool(_keyIsNumberVerified) ?? false;
  }

  static Future<void> setIsNewUser(bool value) async {
    await _prefs.setBool(_keyIsNewUser, value);
  }

  static bool getIsNewUser() {
    return _prefs.getBool(_keyIsNewUser) ?? true;
  }

  static Future<void> setProfileComplete(bool value) async {
    await _prefs.setBool(_keyProfileComplete, value);
  }

  static bool getProfileComplete() {
    return _prefs.getBool(_keyProfileComplete) ?? false;
  }

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
    return DateTime.now().difference(lastCheck).inHours >= AppConfig.updateCheckInterval;
  }

  // ============================================================
  // ✅ PERMANENT DEVICE ID
  // ============================================================
  static Future<String> getPermanentDeviceId() async {
    final cached = _prefs.getString(_keyPermanentDeviceId);
    if (cached != null && cached.isNotEmpty) {
      print('📱 🔒 Device ID (session cache): $cached');
      return cached;
    }

    final secureId = await SecureDeviceIdService.getDeviceId();
    print('📱 🔒 Device ID (secure storage): $secureId');

    await _prefs.setString(_keyPermanentDeviceId, secureId);
    await _prefs.setString(_keyDeviceIdBackup, secureId);
    return secureId;
  }

  static Future<String> getDeviceId() async => getPermanentDeviceId();

  static Future<void> setPermanentDeviceId(String deviceId) async {
    if (deviceId.isNotEmpty) {
      await _prefs.setString(_keyPermanentDeviceId, deviceId);
      await _prefs.setString(_keyDeviceIdBackup, deviceId);
      await SecureDeviceIdService.writeDeviceId(deviceId);
      print('📱 🔄 Permanent device ID set: $deviceId');
    }
  }

  static Future<void> syncDeviceIdWithBackend(String jwtToken) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));
      final response = await dio.get(AppConfig.deviceId);
      if (response.statusCode == 200 && response.data['result'] == 'success') {
        final deviceId = response.data['data']['device_id'] as String?;
        if (deviceId != null && deviceId.isNotEmpty) {
          await setPermanentDeviceId(deviceId);
          print('📱 🔄 Synced device ID from backend: $deviceId');
        }
      }
    } catch (e) {
      print('⚠️ Failed to sync device ID: $e');
    }
  }

  static Future<void> clearDeviceId() async {
    await _prefs.remove(_keyPermanentDeviceId);
    await _prefs.remove(_keyDeviceIdBackup);
    print('🗑️ Device ID session cache cleared (secure storage preserved)');
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

  // ============================================================
  // ✅ CLEAR ALL - COMPLETE SESSION RESET
  // ✅ Preserves ONLY Device ID (survives reinstall)
  // ============================================================
  static Future<void> clearAll() async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  🗑️ CLEARING ALL USER DATA - COMPLETE RESET              ║');
    print('╚════════════════════════════════════════════════════════════╝');

    // ✅ PRESERVE DEVICE ID (survives reinstall)
    final deviceId = _prefs.getString(_keyPermanentDeviceId);
    final backupId = _prefs.getString(_keyDeviceIdBackup);
    final deviceLocation = _prefs.getString(_keyDeviceLocation);
    final locationTime = _prefs.getString(_keyLocationUpdatedAt);

    // ✅ PRESERVE FIRST LAUNCH STATUS
    final isFirst = _prefs.getBool(_keyFirstLaunch) ?? true;

    // ✅ CLEAR EVERYTHING ELSE
    await _prefs.clear();

    // ✅ RESTORE PRESERVED VALUES
    if (deviceId != null && deviceId.isNotEmpty) {
      await _prefs.setString(_keyPermanentDeviceId, deviceId);
    }
    if (backupId != null && backupId.isNotEmpty) {
      await _prefs.setString(_keyDeviceIdBackup, backupId);
    }
    if (deviceLocation != null && deviceLocation.isNotEmpty) {
      await _prefs.setString(_keyDeviceLocation, deviceLocation);
    }
    if (locationTime != null && locationTime.isNotEmpty) {
      await _prefs.setString(_keyLocationUpdatedAt, locationTime);
    }

    // ✅ SET FIRST LAUNCH TO FALSE (app already installed)
    await _prefs.setBool(_keyFirstLaunch, isFirst);

    // ✅ CLEAR APP INITIALIZED FLAG - Forces fresh start on next login
    await _prefs.remove(_keyAppInitialized);

    // ✅ SET LAST LOGOUT TIME
    await setLastLogoutTime(DateTime.now());

    // ✅ CLEAR SESSION ID
    await _prefs.remove(_keySessionId);

    print('✅ All user data cleared');
    print('   🔒 Device ID preserved: $deviceId');
    print('   📍 Location preserved: $deviceLocation');
    print('   ⏰ Logout time: ${DateTime.now()}');
    print('═══════════════════════════════════════════════════════════════\n');
  }
}