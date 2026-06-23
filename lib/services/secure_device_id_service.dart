// services/secure_device_id_service.dart
// ✅ Stores device_id in iOS Keychain / Android EncryptedSharedPreferences
//    Survives app reinstalls

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureDeviceIdService {
  static const String _keyDeviceId = 'persistent_device_id';
  static const String _keyDeviceIdBackup = 'persistent_device_id_backup';

  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // ✅ Android EncryptedSharedPreferences
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock, // ✅ iOS Keychain
    ),
  );

  static final Uuid _uuid = const Uuid();

  /// Get or create persistent device ID that survives app reinstalls
  static Future<String> getDeviceId() async {
    try {
      // 1. Try to get existing device ID from secure storage
      String? deviceId = await _storage.read(key: _keyDeviceId);

      if (deviceId != null && deviceId.isNotEmpty) {
        print('📱 Loaded existing device ID from secure storage: $deviceId');

        // ✅ Verify the device ID is valid UUID format
        if (_isValidUuid(deviceId)) {
          return deviceId;
        } else {
          print('⚠️ Invalid UUID format, generating new one...');
          // If invalid format, generate new one and overwrite
          return await _generateAndStoreDeviceId();
        }
      }

      // 2. Try backup key (if main key was corrupted)
      String? backupId = await _storage.read(key: _keyDeviceIdBackup);
      if (backupId != null && backupId.isNotEmpty && _isValidUuid(backupId)) {
        print('📱 Restored device ID from backup: $backupId');
        // Restore to main key
        await _storage.write(key: _keyDeviceId, value: backupId);
        return backupId;
      }

      // 3. No existing ID - generate new one
      print('📱 No existing device ID found, generating new one...');
      return await _generateAndStoreDeviceId();

    } catch (e) {
      print('❌ Error reading secure storage: $e');
      // Fallback: try to generate new one
      return await _generateAndStoreDeviceId();
    }
  }

  /// Generate new UUID and store securely
  static Future<String> _generateAndStoreDeviceId() async {
    final newDeviceId = _uuid.v4();
    print('📱 Generated new device ID: $newDeviceId');

    try {
      // Store in main key
      await _storage.write(key: _keyDeviceId, value: newDeviceId);

      // Store backup
      await _storage.write(key: _keyDeviceIdBackup, value: newDeviceId);

      print('✅ Device ID saved to secure storage (Keychain/EncryptedSharedPrefs)');
    } catch (e) {
      print('❌ Error saving device ID to secure storage: $e');
    }

    return newDeviceId;
  }

  /// Check if string is a valid UUID
  static bool _isValidUuid(String value) {
    try {
      // UUID format: 8-4-4-4-12 hex characters
      final regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      return regex.hasMatch(value);
    } catch (e) {
      return false;
    }
  }

  /// Clear device ID (for testing / logout)
  static Future<void> clearDeviceId() async {
    try {
      await _storage.delete(key: _keyDeviceId);
      await _storage.delete(key: _keyDeviceIdBackup);
      print('🗑️ Device ID cleared from secure storage');
    } catch (e) {
      print('❌ Error clearing device ID: $e');
    }
  }

  /// Get device ID with caching for performance
  static String? _cachedDeviceId;

  static Future<String> getCachedDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }
    _cachedDeviceId = await getDeviceId();
    return _cachedDeviceId!;
  }

  /// Clear cache (useful after logout)
  static void clearCache() {
    _cachedDeviceId = null;
  }
}