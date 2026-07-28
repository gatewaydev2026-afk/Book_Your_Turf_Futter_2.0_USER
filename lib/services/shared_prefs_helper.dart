// services/shared_prefs_helper.dart
// ✅ COMPLETE - Device ID stored in SecureStorage (survives reinstalls) + Backend Sync

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

  // ✅ PERMANENT DEVICE ID - Stored in SharedPreferences
  static const String _keyPermanentDeviceId = 'permanent_device_id';
  static const String _keyDeviceIdBackup = 'device_id_backup';

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

  // ✅ ============================================================
  // ✅ PERMANENT DEVICE ID
  //    Primary source → SecureDeviceIdService
  //      Android : ANDROID_ID (hardware-bound, survives reinstall)
  //                Fallback: EncryptedSharedPreferences + Auto Backup
  //      iOS     : identifierForVendor (hardware-bound, survives reinstall)
  //                Fallback: Keychain via flutter_secure_storage
  //    SharedPreferences = session-level cache only (fast reads).
  //    Result: ONE stable device_id per physical device, forever.
  // ✅ ============================================================

  /// Returns the permanent device ID.
  /// Reads from secure storage on first call; uses SharedPrefs as cache
  /// for all subsequent calls within the same app session.
  static Future<String> getPermanentDeviceId() async {
    // 1️⃣ Fast path – session cache (cleared on reinstall, that's fine)
    final cached = _prefs.getString(_keyPermanentDeviceId);
    if (cached != null && cached.isNotEmpty) {
      print('📱 🔒 Device ID (session cache): $cached');
      return cached;
    }

    // 2️⃣ Authoritative source – secure storage (survives reinstall)
    final secureId = await SecureDeviceIdService.getDeviceId();
    print('📱 🔒 Device ID (secure storage): $secureId');
    print('   ✅ Same ID returned after reinstall');

    // Populate session cache for fast access during this session
    await _prefs.setString(_keyPermanentDeviceId, secureId);
    await _prefs.setString(_keyDeviceIdBackup, secureId);
    return secureId;
  }

  /// Convenience alias used throughout the codebase.
  static Future<String> getDeviceId() async => getPermanentDeviceId();

  /// Called after the backend returns a canonical device_id.
  /// Updates BOTH the secure storage (via cache invalidation + next read)
  /// and the session cache so everything stays consistent.
  static Future<void> setPermanentDeviceId(String deviceId) async {
    if (deviceId.isNotEmpty) {
      // Update session cache immediately
      await _prefs.setString(_keyPermanentDeviceId, deviceId);
      await _prefs.setString(_keyDeviceIdBackup, deviceId);
      // Invalidate secure storage cache so next cold-start re-reads correctly.
      // SecureDeviceIdService will write this value on the next getDeviceId()
      // call if the secure store is empty; to keep them in sync, write now:
      await SecureDeviceIdService.writeDeviceId(deviceId);
      print('📱 🔄 Permanent device ID set: $deviceId');
    }
  }

  /// Sync with backend: if backend returns a device_id, adopt it.
  static Future<void> syncDeviceIdWithBackend(String jwtToken) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://backend.arcmedialabs.in/api',
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));
      final response = await dio.get('/user/device-id/');
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

  /// Clears only the session cache.
  /// The secure-storage copy is intentionally preserved so the ID
  /// survives this call and any future reinstall.
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

  // ✅ ============================================================
  // ✅ CLEAR ALL - BUT PRESERVE DEVICE ID
  // ✅ ============================================================

  static Future<void> clearAll() async {
    final deviceId = _prefs.getString(_keyPermanentDeviceId);
    final backupId = _prefs.getString(_keyDeviceIdBackup);
    final deviceLocation = _prefs.getString(_keyDeviceLocation);
    final locationTime = _prefs.getString(_keyLocationUpdatedAt);

    await _prefs.clear();

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

    print('🗑️ All cleared (Device ID preserved)');
  }
}