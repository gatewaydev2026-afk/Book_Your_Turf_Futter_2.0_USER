// services/device_token_service.dart
// User App - Device Token Registration with location support

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'device_manager.dart';
import 'shared_prefs_helper.dart';

class DeviceTokenService {
  static Future<bool> registerDeviceToken({String? location}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('❌ No auth token available');
      return false;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('❌ Auth token is invalid');
      return false;
    }

    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print('❌ Failed to get FCM token');
        return false;
      }

      print('📱 Registering device token...');

      if (!Get.isRegistered<DeviceManager>()) {
        Get.put(DeviceManager(), permanent: true);
      }

      final deviceManager = Get.find<DeviceManager>();

      // Check if already registered and valid
      final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
      if (isValid && deviceManager.isRegistered.value) {
        print('✅ Device already registered');
        // Still update token to be safe
        await deviceManager.registerDevice(
          jwtToken: token,
          fcmToken: fcmToken,
          location: location,
        );
        return true;
      }

      final result = await deviceManager.registerDevice(
        jwtToken: token,
        fcmToken: fcmToken,
        location: location,
      );

      if (result.success) {
        print('✅ Device token registered successfully');
        return true;
      } else {
        print('❌ Failed to register: ${result.error}');
        return false;
      }
    } catch (e) {
      print('❌ Error registering token: $e');
      return false;
    }
  }

  // Force register - clears cache and re-registers
  static Future<bool> forceRegisterDeviceToken({String? location}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('❌ No auth token available');
      return false;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('❌ Auth token is invalid');
      return false;
    }

    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print('❌ Failed to get FCM token');
        return false;
      }

      print('🔄 Force registering device token...');

      if (!Get.isRegistered<DeviceManager>()) {
        Get.put(DeviceManager(), permanent: true);
      }

      final deviceManager = Get.find<DeviceManager>();

      // Clear registration cache
      deviceManager.isRegistered.value = false;
      await SharedPrefsHelper.setLastTokenRegistration(null);

      final result = await deviceManager.registerDevice(
        jwtToken: token,
        fcmToken: fcmToken,
        location: location,
      );

      if (result.success) {
        print('✅ Device token force registered successfully');
        return true;
      } else {
        print('❌ Failed to force register: ${result.error}');
        return false;
      }
    } catch (e) {
      print('❌ Error in force register: $e');
      return false;
    }
  }
}