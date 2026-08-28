// services/phone_auto_detect_service.dart
// ✅ Uses Google Phone Number Hint API - No permissions required!
// ✅ Manual detection only (user clicks button)

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_hint_android/phone_hint_android.dart';

class PhoneAutoDetectService {
  static const String _keyDetectedPhone = 'detected_phone_number';
  static const String _keyUserPhone = 'user_phone_number';

  static final PhoneHintAndroid _phoneHint = PhoneHintAndroid();

  static bool _isDetecting = false;

  /// Get phone number using Google Phone Number Hint API (manual trigger)
  /// Only call this when user clicks the button
  static Future<String?> getPhoneNumberHint() async {
    if (_isDetecting) {
      print('⏭️ Detection already in progress - skipping');
      return await getStoredNumber();
    }

    try {
      _isDetecting = true;
      print('🔍 Manual phone number detection...');

      // ⚠️ Timeout guard: if the native ApiException(16) path gets
      // swallowed by MainActivity's onActivityResult try/catch, the
      // plugin's platform-channel result never arrives and this Future
      // would otherwise hang forever. Timing out lets the UI fall back
      // (e.g. to manual entry) instead of spinning indefinitely.
      final phoneNumber = await _phoneHint.getPhoneNumber().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Phone hint request timed out - no result from native side');
          return null;
        },
      );

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final cleaned = _cleanNumber(phoneNumber);
        if (cleaned.isNotEmpty && cleaned.length == 10) {
          await _saveDetectedNumber(cleaned);
          print('📱 Phone detected: $cleaned');
          return cleaned;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Phone detection error: $e');
      return await getStoredNumber();
    } finally {
      _isDetecting = false;
    }
  }

  /// Get stored phone number from SharedPreferences
  static Future<String?> getStoredNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? number = prefs.getString(_keyDetectedPhone);
      if (number == null || number.isEmpty) {
        number = prefs.getString(_keyUserPhone);
      }
      if (number != null && number.isNotEmpty) {
        final cleaned = _cleanNumber(number);
        if (cleaned.length == 10) {
          return cleaned;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting stored number: $e');
      return null;
    }
  }

  /// Save phone number to SharedPreferences
  static Future<void> savePhoneNumber(String number) async {
    try {
      final cleaned = _cleanNumber(number);
      if (cleaned.isNotEmpty && cleaned.length == 10) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyDetectedPhone, cleaned);
        await prefs.setString(_keyUserPhone, cleaned);
        print('📱 Phone number stored: $cleaned');
      }
    } catch (e) {
      print('⚠️ Error saving number: $e');
    }
  }

  /// Clear stored phone number
  static Future<void> clearStoredNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDetectedPhone);
      await prefs.remove(_keyUserPhone);
      print('🗑️ Stored phone number cleared');
    } catch (e) {
      print('⚠️ Error clearing stored number: $e');
    }
  }

  /// Clean phone number
  static String _cleanNumber(String number) {
    String cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.startsWith('1') && cleaned.length == 13) {
      cleaned = cleaned.substring(1);
      if (cleaned.startsWith('91') && cleaned.length == 12) {
        cleaned = cleaned.substring(2);
      }
    }
    if (cleaned.length == 10 && RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
      return cleaned;
    }
    if (cleaned.length > 10) {
      final extracted = cleaned.substring(cleaned.length - 10);
      if (RegExp(r'^[0-9]+$').hasMatch(extracted)) {
        return extracted;
      }
    }
    return '';
  }

  static Future<void> _saveDetectedNumber(String number) async {
    try {
      final cleaned = _cleanNumber(number);
      if (cleaned.isNotEmpty && cleaned.length == 10) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyDetectedPhone, cleaned);
        await prefs.setString(_keyUserPhone, cleaned);
        print('📱 Detected number saved: $cleaned');
      }
    } catch (e) {
      print('⚠️ Error saving detected number: $e');
    }
  }
}