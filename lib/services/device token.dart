// services/device_token_service.dart
// ✅ User App - Device Token Registration

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'device_manager.dart';
import 'shared_prefs_helper.dart';

class DeviceTokenService {
  static Future<bool> registerDeviceToken() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('❌ No auth token available');
      return false;
    }

    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        print('❌ Failed to get FCM token');
        return false;
      }

      print('📱 Registering device token');

      if (!Get.isRegistered<DeviceManager>()) {
        Get.put(DeviceManager(), permanent: true);
      }

      final deviceManager = Get.find<DeviceManager>();

      final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
      if (isValid && deviceManager.isRegistered.value) {
        print('✅ Device already registered');
        return true;
      }

      final result = await deviceManager.registerDevice(
        jwtToken: token,
        fcmToken: fcmToken,
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
}