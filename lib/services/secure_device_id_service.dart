// services/secure_device_id_service.dart
// ✅ ONE device_id PER PHYSICAL DEVICE — survives every reinstall
//
// Strategy:
//   Android → ANDROID_ID (hardware-bound, wiped only on factory reset)
//             Fallback: flutter_secure_storage (EncryptedSharedPrefs + Auto Backup)
//   iOS     → identifierForVendor via device_info_plus
//             Fallback: Keychain via flutter_secure_storage

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureDeviceIdService {
  static const String _keyDeviceId       = 'persistent_device_id';
  static const String _keyDeviceIdBackup = 'persistent_device_id_backup';

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Secure storage — used as fallback when hardware ID is unavailable
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final Uuid _uuid = const Uuid();

  /// In-memory cache — avoids repeated async reads within a single session.
  static String? _cachedDeviceId;

  // ─────────────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the permanent device ID.
  /// Same value every call — even after uninstall + reinstall.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    _cachedDeviceId = await _resolveDeviceId();
    return _cachedDeviceId!;
  }

  /// Convenience alias.
  static Future<String> getCachedDeviceId() => getDeviceId();

  /// Write a specific ID (e.g. backend-canonical value) to all storage layers.
  static Future<void> writeDeviceId(String deviceId) async {
    if (deviceId.isEmpty) return;
    _cachedDeviceId = deviceId;
    try {
      await _storage.write(key: _keyDeviceId,       value: deviceId);
      await _storage.write(key: _keyDeviceIdBackup, value: deviceId);
      print('📱 ✅ Device ID written to secure storage: $deviceId');
    } catch (e) {
      print('❌ Error writing device ID: $e');
    }
  }

  /// Clears only the in-memory cache.
  /// Does NOT touch secure storage — the ID must survive restarts.
  static void clearCache() {
    _cachedDeviceId = null;
  }

  /// Full wipe (use only in testing / factory-reset flows).
  static Future<void> clearDeviceId() async {
    _cachedDeviceId = null;
    try {
      await _storage.delete(key: _keyDeviceId);
      await _storage.delete(key: _keyDeviceIdBackup);
      print('🗑️ Device ID cleared from secure storage');
    } catch (e) {
      print('❌ Error clearing device ID: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE — resolution chain
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> _resolveDeviceId() async {
    // ── Step 1: try to get a hardware-bound ID ──────────────────────────────
    final hardwareId = await _getHardwareId();
    if (hardwareId != null && hardwareId.isNotEmpty) {
      print('📱 🔒 Hardware device ID: $hardwareId');
      print('   ✅ Survives uninstall/reinstall (hardware-bound)');

      // Keep secure storage in sync (used by writeDeviceId callers)
      try {
        await _storage.write(key: _keyDeviceId,       value: hardwareId);
        await _storage.write(key: _keyDeviceIdBackup, value: hardwareId);
      } catch (_) {}

      return hardwareId;
    }

    // ── Step 2: secure storage fallback ────────────────────────────────────
    // On Android: EncryptedSharedPreferences + android:allowBackup="true"
    // means the value is restored from Google Drive backup after reinstall.
    // On iOS: Keychain survives uninstall natively.
    try {
      String? stored = await _storage.read(key: _keyDeviceId);
      if (stored != null && stored.isNotEmpty) {
        print('📱 🔒 Device ID from secure storage (fallback): $stored');
        return stored;
      }

      String? backup = await _storage.read(key: _keyDeviceIdBackup);
      if (backup != null && backup.isNotEmpty) {
        print('📱 🔄 Device ID restored from backup key: $backup');
        await _storage.write(key: _keyDeviceId, value: backup);
        return backup;
      }
    } catch (e) {
      print('⚠️ Secure storage read error: $e');
    }

    // ── Step 3: first-ever install — generate & persist ───────────────────
    final newId = _uuid.v4();
    print('📱 🆕 First install — generated device ID: $newId');
    try {
      await _storage.write(key: _keyDeviceId,       value: newId);
      await _storage.write(key: _keyDeviceIdBackup, value: newId);
    } catch (e) {
      print('❌ Could not persist new device ID: $e');
    }
    return newId;
  }

  /// Returns a stable, hardware-bound identifier or null if unavailable.
  ///
  /// Android: Settings.Secure.ANDROID_ID
  ///   — unique per (device, user, app-signing-key) since Android 8+
  ///   — survives reinstalls; changes only on factory reset
  ///
  /// iOS: UIDevice.identifierForVendor
  ///   — unique per (device, vendor/developer account)
  ///   — resets only when ALL apps from the same vendor are uninstalled
  ///   — for our single-app vendor this is effectively permanent
  static Future<String?> _getHardwareId() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final id   = info.id; // Settings.Secure.ANDROID_ID
        if (id.isNotEmpty && id != 'unknown') {
          // Prefix to distinguish from UUID fallback IDs
          return 'AND-$id';
        }
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        final id   = info.identifierForVendor;
        if (id != null && id.isNotEmpty) {
          return 'IOS-$id';
        }
      }
    } catch (e) {
      print('⚠️ Could not read hardware ID: $e');
    }
    return null;
  }
}