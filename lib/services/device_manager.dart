// services/device_manager.dart
// ✅ Complete with proper device registration logic
// ✅ (user_id + device_id + device_name) = UNIQUE combination
// ✅ Same user + same device_id + same device_name → UPDATE
// ✅ Different user → ALWAYS CREATE NEW (even if same physical device)
// ✅ Same user + different device_id → CREATE NEW
// ✅ Same user + different device_name → CREATE NEW

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/shared_prefs_helper.dart';

class DeviceManager extends GetxService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  final isRegistered = false.obs;
  final devices = <DeviceInfo>[].obs;
  final isLoading = false.obs;

  static bool _registrationInProgress = false;
  static final Set<String> _processedFcmTokens = {};

  // Secure storage for device ID (survives reinstall)
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _deviceIdKey = 'permanent_device_id';
  static const String _deviceIdBackupKey = 'permanent_device_id_backup';

  // PERMANENT device ID - cached
  static String? _permanentDeviceId;
  static String? _cachedDeviceName;
  static String? _cachedDeviceUniqueId;

  @override
  void onInit() {
    super.onInit();
    _initPermanentDeviceId();
    _checkExistingRegistration();
    _setupFCMTokenRefresh();
    _setupLogoutListener();
  }

  // Setup logout listener
  void _setupLogoutListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'device_logout') {
        final deviceId = message.data['device_id'];
        final currentDeviceId = _permanentDeviceId;
        if (deviceId == currentDeviceId) {
          print('🔴 Device logout notification received for this device');
          _handleForcedLogout();
        }
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Background message handler
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('📱 Background message received: ${message.messageId}');
    if (message.data['type'] == 'device_logout') {
      print('🔴 Device logout notification received in background');
      await SharedPrefsHelper.clearAll();
    }
  }

  // Handle forced logout
  Future<void> _handleForcedLogout() async {
    try {
      await SharedPrefsHelper.clearAll();
      await clearRegistration();

      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                'Logged Out Remotely',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'You have been logged out from this device by the device owner. '
                'Please login again to continue using the app.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Get.back();
                Get.offAllNamed('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Login',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      print('❌ Error handling forced logout: $e');
      Get.offAllNamed('/login');
    }
  }

  // Initialize permanent device ID - SURVIVES REINSTALL
  Future<void> _initPermanentDeviceId() async {
    if (_permanentDeviceId == null) {
      _permanentDeviceId = await _getOrCreateDeviceId();
      print('📱 🔒 PERMANENT Device ID: $_permanentDeviceId');
      print('   ✅ This ID will NEVER change');
      print('   ✅ Survives app reinstall');
    }
  }

  // Get or create unique device ID - survives reinstall
  Future<String> _getOrCreateDeviceId() async {
    try {
      String? deviceId = await _secureStorage.read(key: _deviceIdKey);

      if (deviceId != null && deviceId.isNotEmpty) {
        print('📱 Found existing device ID in secure storage: $deviceId');
        return deviceId;
      }

      deviceId = await _secureStorage.read(key: _deviceIdBackupKey);
      if (deviceId != null && deviceId.isNotEmpty) {
        print('📱 Found backup device ID: $deviceId');
        await _secureStorage.write(key: _deviceIdKey, value: deviceId);
        return deviceId;
      }

      deviceId = await SharedPrefsHelper.getPermanentDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        print('📱 Found device ID in SharedPreferences: $deviceId');
        await _secureStorage.write(key: _deviceIdKey, value: deviceId);
        await _secureStorage.write(key: _deviceIdBackupKey, value: deviceId);
        return deviceId;
      }

      final uniqueId = await _generateUniqueDeviceId();
      print('🆕 Generated NEW unique device ID: $uniqueId');

      await _secureStorage.write(key: _deviceIdKey, value: uniqueId);
      await _secureStorage.write(key: _deviceIdBackupKey, value: uniqueId);
      await SharedPrefsHelper.setPermanentDeviceId(uniqueId);

      return uniqueId;
    } catch (e) {
      print('⚠️ Error accessing secure storage: $e');
      String? deviceId = await SharedPrefsHelper.getPermanentDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      }
      final uniqueId = await _generateUniqueDeviceId();
      await SharedPrefsHelper.setPermanentDeviceId(uniqueId);
      return uniqueId;
    }
  }

  // Generate truly unique device ID using device-specific identifiers
  Future<String> _generateUniqueDeviceId() async {
    try {
      String deviceIdentifier = '';

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        final String? hardwareId = androidInfo.id;
        final String? serialNumber = androidInfo.serialNumber;
        final String? device = androidInfo.device;
        final String? model = androidInfo.model;
        final String? manufacturer = androidInfo.manufacturer;

        List<String> identifiers = [];

        if (hardwareId != null && hardwareId.isNotEmpty && hardwareId != 'unknown') {
          identifiers.add(hardwareId);
        }
        if (serialNumber != null && serialNumber.isNotEmpty && serialNumber != 'unknown') {
          identifiers.add(serialNumber);
        }
        if (device != null && device.isNotEmpty && device != 'unknown') {
          identifiers.add(device);
        }
        if (model != null && model.isNotEmpty && model != 'unknown') {
          identifiers.add(model);
        }
        if (manufacturer != null && manufacturer.isNotEmpty && manufacturer != 'unknown') {
          identifiers.add(manufacturer);
        }

        if (identifiers.isNotEmpty) {
          deviceIdentifier = identifiers.first;
        } else {
          deviceIdentifier = '${androidInfo.manufacturer}_${androidInfo.model}_${androidInfo.device}';
        }

        print('📱 Android device identifiers:');
        print('   Hardware ID: ${androidInfo.id}');
        print('   Serial: ${androidInfo.serialNumber}');
        print('   Device: ${androidInfo.device}');
        print('   Model: ${androidInfo.model}');
        print('   Manufacturer: ${androidInfo.manufacturer}');
        print('   Using: $deviceIdentifier');

      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        final String? vendorId = iosInfo.identifierForVendor;
        final String? model = iosInfo.model;
        final String? systemVersion = iosInfo.systemVersion;

        List<String> identifiers = [];

        if (vendorId != null && vendorId.isNotEmpty && vendorId != 'unknown') {
          identifiers.add(vendorId);
        }
        if (model != null && model.isNotEmpty && model != 'unknown') {
          identifiers.add(model);
        }
        if (systemVersion != null && systemVersion.isNotEmpty && systemVersion != 'unknown') {
          identifiers.add(systemVersion);
        }

        if (identifiers.isNotEmpty) {
          deviceIdentifier = identifiers.first;
        } else {
          deviceIdentifier = 'iOS_${iosInfo.model}_${iosInfo.systemVersion}';
        }

        print('📱 iOS device identifiers:');
        print('   Vendor ID: ${iosInfo.identifierForVendor}');
        print('   Model: ${iosInfo.model}');
        print('   Using: $deviceIdentifier');

      } else {
        deviceIdentifier = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }

      String cleanId = deviceIdentifier
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();

      if (cleanId.isEmpty || cleanId == '_') {
        cleanId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }

      final uniqueId = 'BYT_$cleanId';

      if (uniqueId.length > 255) {
        return uniqueId.substring(0, 255);
      }

      print('✅ Generated unique device ID: $uniqueId');
      return uniqueId;

    } catch (e) {
      print('⚠️ Error generating device ID: $e');
      return 'BYT_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  void _setupFCMTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('📱 FCM Token refreshed');
      await _updateFcmTokenOnly(newToken);
    });
  }

  Future<void> _updateFcmTokenOnly(String newToken) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) return;

    if (_processedFcmTokens.contains(newToken)) {
      print('⏭️ Token already processed');
      return;
    }

    _processedFcmTokens.add(newToken);
    final deviceId = await _getPermanentDeviceId();
    await _updateDeviceToken(
      jwtToken: token,
      fcmToken: newToken,
      deviceId: deviceId,
    );
  }

  Future<void> _checkExistingRegistration() async {
    final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
    if (isValid) {
      isRegistered.value = true;
      print('✅ Device already registered (valid until 7 days)');
    }
  }

  Future<String> _getPermanentDeviceId() async {
    if (_permanentDeviceId != null) {
      return _permanentDeviceId!;
    }
    _permanentDeviceId = await _getOrCreateDeviceId();
    return _permanentDeviceId!;
  }

  Future<String> getDeviceId() async {
    return await _getPermanentDeviceId();
  }

  Future<String> _getCurrentDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      _cachedDeviceName = _getDeviceName(androidInfo.model, androidInfo.manufacturer);
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      _cachedDeviceName = _getDeviceName(iosInfo.model, 'Apple');
    } else {
      _cachedDeviceName = 'Unknown Device';
    }

    return _cachedDeviceName!;
  }

  // ============================================================
  // ✅ CHECK IF DEVICE EXISTS FOR THIS USER
  // ✅ Uses (user_id + device_id + device_name) combination
  // ✅ CRITICAL FIX: Different user → ALWAYS CREATE NEW
  // ============================================================
  Future<Map<String, dynamic>?> _checkDeviceExistsForUser({
    required String jwtToken,
    required String deviceId,
    required String deviceName,
    required String userId,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in/api',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      print('🔍 Checking if device exists for this user:');
      print('   👤 user_id: $userId');
      print('   🔑 device_id: $deviceId');
      print('   📱 device_name: $deviceName');

      final response = await dio.get(
        '/user/devices/check/',
        queryParameters: {
          'user_id': userId,
          'device_id': deviceId,
          'device_name': deviceName,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['result'] == 'success') {
          bool exists = data['exists'] ?? false;
          Map<String, dynamic>? deviceData = data['data'];

          print('✅ Device check response (raw): exists=$exists');

          // 🔴 CRITICAL FIX: Even if backend says exists=true,
          // we must verify the returned record belongs to THIS user.
          // Different user → ALWAYS CREATE NEW
          if (exists && deviceData != null) {
            final String? returnedUserId = deviceData['user_id']?.toString();

            if (returnedUserId != userId) {
              print('   ⚠️⚠️⚠️ DIFFERENT USER DETECTED! ⚠️⚠️⚠️');
              print('      👤 Current user_id      : $userId');
              print('      👤 Returned user_id     : $returnedUserId');
              print('   🔴 FORCING exists=false → CREATE NEW DEVICE RECORD');
              print('   🔴 This prevents updating another user\'s device!');

              exists = false;
              deviceData = null;
              data['exists'] = false;
              data['data'] = null;
            } else {
              print('   ✅ SAME USER - Device record found:');
              print('      📝 Record ID: ${deviceData['id']}');
              print('      🔑 device_id: ${deviceData['device_id']}');
              print('      📱 device_name: ${deviceData['device_name']}');
              print('      👤 user_id: ${deviceData['user_id']}');
              print('   ✅ Will UPDATE existing record');
            }
          } else {
            print('   ❌ No device found for this user with these details');
            print('   ✅ Will CREATE NEW device record');
          }

          print('✅ Device check response (final): exists=$exists');
          return data;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error checking device: $e');
      return null;
    }
  }

  // ============================================================
  // UPDATE DEVICE TOKEN - ONLY FCM TOKEN
  // ============================================================
  Future<bool> _updateDeviceToken({
    required String jwtToken,
    required String fcmToken,
    required String deviceId,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in/api',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      print('📤 UPDATING DEVICE TOKEN ONLY:');
      print('   device_id: $deviceId (SAME)');

      final response = await dio.post(
        '/user/device-token/update/',
        data: {
          'token': fcmToken,
          'device_id': deviceId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ FCM token updated successfully');
        await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating token: $e');
      return false;
    }
  }

  // ============================================================
  // UPDATE DEVICE LOCATION - ONLY LOCATION
  // ============================================================
  Future<bool> _updateDeviceLocation({
    required String jwtToken,
    required String deviceId,
    required String location,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in/api',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      print('📤 UPDATING DEVICE LOCATION ONLY:');
      print('   device_id: $deviceId (SAME)');
      print('   location: $location');

      final response = await dio.patch(
        '/user/device-token/location/',
        data: {
          'device_id': deviceId,
          'location': location,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Device location updated successfully');
        await SharedPrefsHelper.saveDeviceLocation(location);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error updating location: $e');
      return false;
    }
  }

  Future<Map<String, String>> getDeviceInfo() async {
    final deviceId = await _getPermanentDeviceId();
    final deviceName = await _getCurrentDeviceName();

    print('📱 Using PERMANENT device ID: $deviceId');
    print('📱 Device Name: $deviceName');

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'device_id': deviceId,
        'platform': 'android',
        'device_name': deviceName,
        'os_version': androidInfo.version.release,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return {
        'device_id': deviceId,
        'platform': 'ios',
        'device_name': deviceName,
        'os_version': iosInfo.systemVersion,
      };
    } else {
      return {
        'device_id': deviceId,
        'platform': 'unknown',
        'device_name': 'Unknown Device',
        'os_version': 'unknown',
      };
    }
  }

  String _getDeviceName(String model, String manufacturer) {
    if (model.toLowerCase().contains(manufacturer.toLowerCase())) {
      return model;
    }
    return '$manufacturer $model';
  }

  // ============================================================
  // ✅ REGISTER DEVICE - SMART LOGIC
  // ✅ (user_id + device_id + device_name) = UNIQUE
  // ✅ If all three match AND same user → UPDATE
  // ✅ If different user → ALWAYS CREATE NEW
  // ✅ If any one is different → CREATE NEW
  // ============================================================
  Future<DeviceRegistrationResult> registerDevice({
    required String jwtToken,
    String? fcmToken,
    String? location,
  }) async {
    if (_registrationInProgress) {
      return DeviceRegistrationResult(
          success: false,
          message: 'Registration already in progress'
      );
    }

    _registrationInProgress = true;

    try {
      String? tokenToUse = fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (tokenToUse == null) {
        return DeviceRegistrationResult(success: false, error: 'No FCM token');
      }

      if (_processedFcmTokens.contains(tokenToUse)) {
        isRegistered.value = true;
        return DeviceRegistrationResult(success: true, message: 'Token already registered');
      }

      final deviceInfo = await getDeviceInfo();
      final String deviceId = deviceInfo['device_id']!;
      final String deviceName = deviceInfo['device_name']!;
      final String platform = deviceInfo['platform']!;
      final String osVersion = deviceInfo['os_version']!;

      // Get current user ID
      final int? userIdInt = SharedPrefsHelper.getUserId();
      final String userId = userIdInt?.toString() ?? '';

      if (userId.isEmpty) {
        return DeviceRegistrationResult(success: false, error: 'User ID not found');
      }

      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  📱 DEVICE REGISTRATION                                     ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('   👤 Current User ID: $userId');
      print('   👤 User Email: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');
      print('   🔑 Device ID: $deviceId');
      print('   📱 Device Name: $deviceName');

      // ✅ Check if device exists for this user with same ID + NAME
      // ✅ This now has the CRITICAL FIX: different user → returns exists=false
      final existingDevice = await _checkDeviceExistsForUser(
        jwtToken: jwtToken,
        deviceId: deviceId,
        deviceName: deviceName,
        userId: userId,
      );

      bool exists = existingDevice?['exists'] ?? false;

      if (exists) {
        // ✅ Case 1: Same user_id + same device_id + same device_name → UPDATE
        print('\n╔════════════════════════════════════════════════════════════╗');
        print('║  🔄 SAME USER + SAME DEVICE DETECTED - UPDATING ONLY      ║');
        print('╚════════════════════════════════════════════════════════════╝');
        print('   ✅ Same User ID: $userId');
        print('   ✅ Same Device ID: $deviceId');
        print('   ✅ Same Device Name: $deviceName');
        print('   ✅ All three match → UPDATE (NO NEW DEVICE)');

        // Get the existing device record ID
        final deviceData = existingDevice?['data'];
        final String? existingDeviceId = deviceData?['device_id'];
        final int? existingRecordId = deviceData?['id'];

        if (existingDeviceId == null || existingRecordId == null) {
          return DeviceRegistrationResult(success: false, error: 'Existing device not found');
        }

        // Update FCM token
        bool tokenUpdated = await _updateDeviceToken(
          jwtToken: jwtToken,
          fcmToken: tokenToUse,
          deviceId: existingDeviceId,
        );

        // Update location if provided
        bool locationUpdated = true;
        if (location != null && location.isNotEmpty) {
          locationUpdated = await _updateDeviceLocation(
            jwtToken: jwtToken,
            deviceId: existingDeviceId,
            location: location,
          );
        }

        if (tokenUpdated || locationUpdated) {
          await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
          isRegistered.value = true;
          _processedFcmTokens.add(tokenToUse);

          print('\n✅ Device UPDATED successfully:');
          print('   👤 User ID: $userId (SAME)');
          print('   🔑 Device ID: $existingDeviceId (SAME)');
          print('   📱 Device Name: $deviceName (SAME)');
          print('   📝 Record ID: $existingRecordId');

          return DeviceRegistrationResult(
              success: true,
              message: 'Device updated successfully'
          );
        }
        return DeviceRegistrationResult(success: false, error: 'Update failed');

      } else {
        // ✅ Case 2: Different user OR different device_id OR different device_name → CREATE NEW
        print('\n╔════════════════════════════════════════════════════════════╗');
        print('║  🆕 NEW DEVICE - CREATING NEW ENTRY                        ║');
        print('╚════════════════════════════════════════════════════════════╝');
        print('   👤 User ID: $userId');
        print('   🔑 Device ID: $deviceId');
        print('   📱 Device Name: $deviceName');

        if (existingDevice != null && existingDevice['data'] != null) {
          final existingData = existingDevice['data'];
          final String? existingUserId = existingData?['user_id']?.toString();
          if (existingUserId != null && existingUserId != userId) {
            print('   🔴 DIFFERENT USER DETECTED!');
            print('      👤 Existing user_id: $existingUserId');
            print('      👤 Current user_id : $userId');
            print('   🆕 Creating NEW device record for current user');
          } else {
            print('   💡 Different device_id or device_name');
          }
        } else {
          print('   💡 No existing device found');
        }

        return await _registerNewDevice(
          jwtToken: jwtToken,
          tokenToUse: tokenToUse,
          deviceId: deviceId,
          deviceName: deviceName,
          platform: platform,
          osVersion: osVersion,
          location: location,
        );
      }

    } catch (e) {
      print('❌ Error in registerDevice: $e');
      return DeviceRegistrationResult(success: false, error: e.toString());
    } finally {
      _registrationInProgress = false;
    }
  }

  // ============================================================
  // REGISTER NEW DEVICE - CREATES FRESH ENTRY
  // ============================================================
  Future<DeviceRegistrationResult> _registerNewDevice({
    required String jwtToken,
    required String tokenToUse,
    required String deviceId,
    required String deviceName,
    required String platform,
    required String osVersion,
    String? location,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'token': tokenToUse,
        'device_id': deviceId,
        'platform': platform,
        'device_name': deviceName,
        'os_version': osVersion,
      };

      if (location != null && location.isNotEmpty) {
        requestBody['location'] = location;
      }

      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in/api',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      print('📤 Registering NEW device for user:');
      print('   👤 User: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');
      print('   👤 User ID: ${SharedPrefsHelper.getUserId() ?? 'Unknown'}');
      print('   🔑 device_id: $deviceId');
      print('   📱 device_name: $deviceName');
      print('   📱 platform: $platform');
      print('   📱 os_version: $osVersion');

      final response = await dio.post('/user/device-token/', data: requestBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
        isRegistered.value = true;
        _processedFcmTokens.add(tokenToUse);

        print('\n✅ NEW Device registered successfully:');
        print('   🔑 Device ID: $deviceId');
        print('   📱 Device Name: $deviceName');
        print('   👤 User: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');

        return DeviceRegistrationResult(success: true);
      }
      return DeviceRegistrationResult(success: false);
    } catch (e) {
      print('❌ Error registering new device: $e');
      return DeviceRegistrationResult(success: false, error: e.toString());
    }
  }

  // ============================================================
  // FORCE REGISTER DEVICE - Public method
  // ============================================================
  Future<bool> forceRegisterDevice({String? location}) async {
    // Clear old registration status
    isRegistered.value = false;
    _processedFcmTokens.clear();
    await SharedPrefsHelper.setLastTokenRegistration(null);

    final jwtToken = SharedPrefsHelper.getToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      print('❌ No JWT token available');
      return false;
    }

    print('🔄 Force registering device...');
    final result = await registerDevice(jwtToken: jwtToken, location: location);
    return result.success;
  }

  Future<bool> registerDeviceToken({String? location}) async {
    final jwtToken = SharedPrefsHelper.getToken();
    if (jwtToken == null || jwtToken.isEmpty) return false;
    if (!SharedPrefsHelper.isTokenValid()) return false;
    final result = await registerDevice(jwtToken: jwtToken, location: location);
    return result.success;
  }

  // ==================== FETCH DEVICES ====================
  Future<List<DeviceInfo>> fetchDevices() async {
    final jwtToken = SharedPrefsHelper.getToken();
    if (jwtToken == null || jwtToken.isEmpty) return [];

    isLoading.value = true;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in/api',
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));
      final response = await dio.get('/user/devices/');

      if (response.statusCode == 200 && response.data['result'] == 'success') {
        final devicesList = (response.data['data'] as List)
            .map((json) => DeviceInfo.fromJson(json))
            .toList();
        devices.assignAll(devicesList);
        print('📱 Loaded ${devicesList.length} devices for user: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');
        return devicesList;
      }
      return [];
    } catch (e) {
      print('❌ Error fetching devices: $e');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  // ==================== LOGOUT DEVICE ====================
  Future<bool> logoutDevice(int deviceRecordId) async {
    final jwtToken = SharedPrefsHelper.getToken();
    if (jwtToken == null || jwtToken.isEmpty) return false;

    isLoading.value = true;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in/api',
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));

      print('📤 Logging out device record ID: $deviceRecordId');
      print('   👤 User: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');

      final response = await dio.post(
        '/user/devices/logout/',
        data: {'device_id': deviceRecordId},
      );

      if (response.statusCode == 200 && response.data['result'] == 'success') {
        final removedDevice = devices.firstWhereOrNull((d) => d.id == deviceRecordId);
        devices.removeWhere((d) => d.id == deviceRecordId);

        print('✅ Device logged out successfully: ${removedDevice?.deviceName}');
        print('   👤 User: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');

        final currentDeviceId = await getDeviceId();
        if (removedDevice?.deviceId == currentDeviceId) {
          print('🔴 Current device was logged out! Auto-logging out user...');
          await _handleForcedLogout();
        }

        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error logging out device: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ==================== LOGOUT ALL OTHER DEVICES ====================
  Future<int> logoutAllOtherDevices() async {
    final jwtToken = SharedPrefsHelper.getToken();
    if (jwtToken == null || jwtToken.isEmpty) return 0;

    final allDevices = await fetchDevices();
    final currentDeviceId = await getDeviceId();

    final devicesToLogout = allDevices
        .where((d) => d.deviceId != currentDeviceId)
        .map((d) => d.id)
        .toList();

    if (devicesToLogout.isEmpty) return 0;

    print('📤 Logging out ${devicesToLogout.length} other devices for user: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');

    int successCount = 0;
    for (var deviceId in devicesToLogout) {
      final success = await logoutDevice(deviceId);
      if (success) successCount++;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return successCount;
  }

  Future<void> clearRegistration() async {
    isRegistered.value = false;
    _processedFcmTokens.clear();
    devices.clear();
    await SharedPrefsHelper.setLastTokenRegistration(null);
    print('🗑️ Device registration cleared');
  }
}

class DeviceRegistrationResult {
  bool success;
  String message;
  String? error;
  DeviceRegistrationResult({
    this.success = false,
    this.message = '',
    this.error
  });
}

class DeviceInfo {
  final int id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String osVersion;
  final String? location;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeviceInfo({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.osVersion,
    this.location,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    id: json['id'] ?? 0,
    deviceId: json['device_id'] ?? '',
    deviceName: json['device_name'] ?? 'Unknown Device',
    platform: json['platform'] ?? 'unknown',
    osVersion: json['os_version'] ?? 'unknown',
    location: json['location'],
    isActive: json['is_active'] ?? true,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
  );

  String get formattedDate {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    return 'Just now';
  }

  String get activeStatusText => isActive ? 'Active' : 'Inactive';
  Color get activeStatusColor => isActive ? Colors.green : Colors.red;
}