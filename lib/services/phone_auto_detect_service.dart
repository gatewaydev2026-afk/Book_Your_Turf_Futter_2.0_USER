// services/phone_auto_detect_service.dart
// ✅ Real SIM number detection using mobile_number package

import 'dart:io';
import 'package:mobile_number/mobile_number.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneAutoDetectService {
  static const String _keyDetectedPhone = 'detected_phone_number';

  /// Stored number திரும்ப கொடுக்கும்
  static Future<String?> getStoredNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyDetectedPhone);
    } catch (e) {
      return null;
    }
  }

  /// Real SIM number(s) எடுக்கும் (Android only) — Dual SIM support
  static Future<List<String>> getSimPhoneNumbers() async {
    if (!Platform.isAndroid) return [];

    try {
      // Permission check
      if (!await MobileNumber.hasPhonePermission) {
        await MobileNumber.requestPhonePermission;
      }

      final status = await Permission.phone.request();
      if (!status.isGranted) {
        print('❌ Phone permission denied');
        final stored = await getStoredNumber();
        return stored != null ? [stored] : [];
      }

      List<String> numbers = [];

      // Dual SIM support
      final simCards = await MobileNumber.getSimCards;
      if (simCards != null && simCards.isNotEmpty) {
        for (var sim in simCards) {
          final num = _cleanNumber(sim.number ?? '');
          if (num.length == 10 && !numbers.contains(num)) {
            numbers.add(num);
          }
        }
      }

      // Fallback - single number
      if (numbers.isEmpty) {
        final single = await MobileNumber.mobileNumber;
        final cleaned = _cleanNumber(single ?? '');
        if (cleaned.length == 10) {
          numbers.add(cleaned);
        }
      }

      // Save first one for future use
      if (numbers.isNotEmpty) {
        await _saveDetectedNumber(numbers.first);
        print('📱 Detected numbers: $numbers');
      } else {
        print('ℹ️ No phone number detected from SIM');
      }

      return numbers;
    } catch (e) {
      print('❌ Error detecting SIM numbers: $e');
      final stored = await getStoredNumber();
      return stored != null ? [stored] : [];
    }
  }

  /// Single number (old API compatibility)
  static Future<String?> getSimPhoneNumber() async {
    final list = await getSimPhoneNumbers();
    return list.isNotEmpty ? list.first : null;
  }

  static String _cleanNumber(String number) {
    String cleaned = number.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length == 10 && RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
      return cleaned;
    }
    return '';
  }

  static Future<void> _saveDetectedNumber(String number) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDetectedPhone, number);
    } catch (e) {
      print('⚠️ Error saving number: $e');
    }
  }

  static Future<void> setDetectedNumber(String number) async {
    final cleaned = _cleanNumber(number);
    if (cleaned.isNotEmpty) {
      await _saveDetectedNumber(cleaned);
      print('📱 Phone number stored: $cleaned');
    }
  }

  static Future<void> clearStoredNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDetectedPhone);
      print('🗑️ Stored phone number cleared');
    } catch (e) {
      print('⚠️ Error clearing stored number: $e');
    }
  }
}