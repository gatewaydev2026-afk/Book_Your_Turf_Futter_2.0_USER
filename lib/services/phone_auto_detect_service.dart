// services/phone_auto_detect_service.dart
// ✅ Auto-detect once when page loads - No manual button needed
// ✅ Also has manual getPhoneNumberHint for fallback

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_hint_android/phone_hint_android.dart';

class PhoneAutoDetectService {
  static const String _keyDetectedPhone = 'detected_phone_number';
  static const String _keyUserPhone = 'user_phone_number';
  static const String _keyAutoDetectDone = 'auto_detect_done';

  static final PhoneHintAndroid _phoneHint = PhoneHintAndroid();
  static bool _isDetecting = false;

  /// Auto-detect phone number - Only runs once per device
  static Future<String?> autoDetectOnce() async {
    // ✅ Check if auto-detect already done
    final alreadyDone = await _isAutoDetectDone();
    if (alreadyDone) {
      print('✅ Auto-detect already done - using stored number');
      return await getStoredNumber();
    }

    if (_isDetecting) {
      print('⏭️ Detection already in progress - skipping');
      return await getStoredNumber();
    }

    try {
      _isDetecting = true;
      print('🔍 Auto-detecting phone number...');

      final phoneNumber = await _phoneHint.getPhoneNumber();

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final cleaned = _cleanNumber(phoneNumber);
        if (cleaned.isNotEmpty && cleaned.length == 10) {
          await _saveDetectedNumber(cleaned);
          await _setAutoDetectDone(true);
          print('📱 Phone auto-detected: $cleaned');
          return cleaned;
        }
      }
      print('ℹ️ No phone number detected');
      await _setAutoDetectDone(true);
      return null;
    } catch (e) {
      print('⚠️ Auto-detect error: $e');
      await _setAutoDetectDone(true);
      return await getStoredNumber();
    } finally {
      _isDetecting = false;
    }
  }

  /// ✅ MANUAL PHONE NUMBER HINT - For manual button (fallback)
  static Future<String?> getPhoneNumberHint() async {
    if (_isDetecting) {
      print('⏭️ Detection already in progress - skipping');
      return await getStoredNumber();
    }

    try {
      _isDetecting = true;
      print('🔍 Manual phone number detection...');

      final phoneNumber = await _phoneHint.getPhoneNumber();

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        final cleaned = _cleanNumber(phoneNumber);
        if (cleaned.isNotEmpty && cleaned.length == 10) {
          await _saveDetectedNumber(cleaned);
          await _setAutoDetectDone(true);
          print('📱 Phone detected manually: $cleaned');
          return cleaned;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Manual phone detection error: $e');
      return await getStoredNumber();
    } finally {
      _isDetecting = false;
    }
  }

  static Future<bool> _isAutoDetectDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAutoDetectDone) ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _setAutoDetectDone(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoDetectDone, value);
    } catch (e) {
      print('⚠️ Error saving auto-detect status: $e');
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

  /// Clear stored phone number (for testing)
  static Future<void> clearStoredNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDetectedPhone);
      await prefs.remove(_keyUserPhone);
      await prefs.remove(_keyAutoDetectDone);
      print('🗑️ Stored phone number and auto-detect status cleared');
    } catch (e) {
      print('⚠️ Error clearing stored number: $e');
    }
  }

  /// Reset auto-detect status (for testing)
  static Future<void> resetAutoDetect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAutoDetectDone);
      print('🔄 Auto-detect status reset');
    } catch (e) {
      print('⚠️ Error resetting auto-detect: $e');
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