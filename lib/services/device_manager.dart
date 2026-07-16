// services/device_manager.dart
// ✅ Complete - Uses SharedPreferences for device ID

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/shared_prefs_helper.dart';

class DeviceManager extends GetxService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool _isRegistering = false;

  final isRegistered = false.obs;
  final devices = <DeviceInfo>[].obs;
  final isLoading = false.obs;

  static bool _registrationInProgress = false;
  static final Set<String> _processedFcmTokens = {};

  // ✅ PERMANENT device ID - cached
  static String? _permanentDeviceId;
  static String? _cachedDeviceName;

  @override
  void onInit() {
    super.onInit();
    _initPermanentDeviceId();
    _checkExistingRegistration();
    _setupFCMTokenRefresh();
  }

  // ✅ Initialize permanent device ID ONCE
  Future<void> _initPermanentDeviceId() async {
    if (_permanentDeviceId == null) {
      _permanentDeviceId = await SharedPrefsHelper.getPermanentDeviceId();
      print('📱 🔒 PERMANENT Device ID: $_permanentDeviceId');
      print('   ✅ This ID will NEVER change');
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

    // ✅ Update only FCM token
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

  // ✅ Get permanent device ID - NEVER changes
  Future<String> _getPermanentDeviceId() async {
    if (_permanentDeviceId != null) {
      return _permanentDeviceId!;
    }
    _permanentDeviceId = await SharedPrefsHelper.getPermanentDeviceId();
    return _permanentDeviceId!;
  }

  // ✅ Public method - returns permanent device ID
  Future<String> getDeviceId() async {
    return await _getPermanentDeviceId();
  }

  // ✅ Get current device name
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

  // ✅ ============================================================
  // ✅ UPDATE DEVICE TOKEN - ONLY FCM TOKEN
  // ✅ ============================================================
  Future<bool> _updateDeviceToken({
    required String jwtToken,
    required String fcmToken,
    required String deviceId,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      print('📤 UPDATING DEVICE TOKEN ONLY:');
      print('   device_id: $deviceId (SAME)');

      final response = await dio.post(
        '/api/user/device-token/update/',
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

  // ✅ ============================================================
  // ✅ UPDATE DEVICE LOCATION - ONLY LOCATION
  // ✅ ============================================================
  Future<bool> _updateDeviceLocation({
    required String jwtToken,
    required String deviceId,
    required String location,
  }) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      print('📤 UPDATING DEVICE LOCATION ONLY:');
      print('   device_id: $deviceId (SAME)');
      print('   location: $location');

      final response = await dio.patch(
        '/api/user/device-token/location/',
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

  // ✅ ============================================================
  // ✅ CHECK IF SAME DEVICE - COMPARE DEVICE NAME
  // ✅ ============================================================
  Future<bool> _isSameDevice(String jwtToken, String currentDeviceName) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      print('📤 Checking if device exists with name: $currentDeviceName');

      final response = await dio.get(
        '/api/user/devices/check-by-name/',
        queryParameters: {'device_name': currentDeviceName},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['result'] == 'success' && data['exists'] == true) {
          print('✅ Device with name "$currentDeviceName" EXISTS in backend');
          return true;
        }
      }
      print('❌ Device with name "$currentDeviceName" does NOT exist');
      return false;
    } catch (e) {
      print('⚠️ Error checking device: $e');
      return false;
    }
  }

  // ✅ ============================================================
  // ✅ GET EXISTING DEVICE ID BY DEVICE NAME
  // ✅ ============================================================
  Future<String?> _getExistingDeviceIdByName(String jwtToken, String deviceName) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://test.backend.arcmedialabs.in',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      final response = await dio.get(
        '/api/user/devices/get-by-name/',
        queryParameters: {'device_name': deviceName},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['result'] == 'success' && data['data'] != null) {
          final deviceId = data['data']['device_id'];
          print('✅ Found existing device ID: $deviceId');
          return deviceId;
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting device ID: $e');
      return null;
    }
  }

  // ✅ ============================================================
  // ✅ REGISTER DEVICE - SAME DEVICE NAME = UPDATE ONLY
  // ✅ Different Device Name = CREATE NEW
  // ✅ ============================================================
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

    if (isRegistered.value) {
      print('✅ Device already registered in this session');
      return DeviceRegistrationResult(success: true, message: 'Already registered');
    }

    final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
    if (isValid) {
      isRegistered.value = true;
      print('✅ Device registration still valid (within 7 days)');
      return DeviceRegistrationResult(success: true, message: 'Registration still valid');
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
      final String currentDeviceName = deviceInfo['device_name']!;
      final String currentPlatform = deviceInfo['platform']!;

      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║  📱 DEVICE REGISTRATION CHECK                               ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('   📱 Device Name: $currentDeviceName');

      // ✅ Check if device with same name exists
      final bool deviceExists = await _isSameDevice(jwtToken, currentDeviceName);

      if (deviceExists) {
        // ✅ SAME DEVICE - UPDATE ONLY
        print('\n╔════════════════════════════════════════════════════════════╗');
        print('║  🔄 SAME DEVICE DETECTED - UPDATING ONLY                   ║');
        print('╚════════════════════════════════════════════════════════════╝');
        print('   ✅ Device with name "$currentDeviceName" already exists');
        print('   ❌ NO NEW DEVICE ID GENERATED');

        final existingDeviceId = await _getExistingDeviceIdByName(jwtToken, currentDeviceName);

        if (existingDeviceId != null) {
          // ✅ Update FCM token
          bool tokenUpdated = await _updateDeviceToken(
            jwtToken: jwtToken,
            fcmToken: tokenToUse,
            deviceId: existingDeviceId,
          );

          // ✅ Update location if provided
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

            // ✅ Sync local device ID with backend
            await SharedPrefsHelper.setPermanentDeviceId(existingDeviceId);
            _permanentDeviceId = existingDeviceId;

            print('\n✅ Device UPDATED successfully:');
            print('   🆔 Device ID: $existingDeviceId (SAME - NO CHANGE)');
            print('   📱 Device Name: $currentDeviceName (SAME)');
            print('   ✅ NO NEW DEVICE CREATED');

            return DeviceRegistrationResult(
                success: true,
                message: 'Device updated successfully'
            );
          }
          return DeviceRegistrationResult(success: false, error: 'Update failed');
        }
        return DeviceRegistrationResult(success: false, error: 'Device exists but no ID found');
      } else {
        // ✅ NEW DEVICE - CREATE NEW
        print('\n╔════════════════════════════════════════════════════════════╗');
        print('║  🆕 NEW DEVICE - CREATING NEW ENTRY                        ║');
        print('╚════════════════════════════════════════════════════════════╝');
        print('   ✅ New device name: $currentDeviceName');

        return await _createNewDevice(
          jwtToken: jwtToken,
          tokenToUse: tokenToUse,
          deviceInfo: deviceInfo,
          location: location,
        );
      }

    } catch (e) {
      return DeviceRegistrationResult(success: false, error: e.toString());
    } finally {
      _registrationInProgress = false;
    }
  }

  // ✅ ============================================================
  // ✅ CREATE NEW DEVICE
  // ✅ ============================================================
  Future<DeviceRegistrationResult> _createNewDevice({
    required String jwtToken,
    required String tokenToUse,
    required Map<String, String> deviceInfo,
    String? location,
  }) async {
    try {
      final String deviceId = deviceInfo['device_id']!;
      final String deviceName = deviceInfo['device_name']!;
      final String platform = deviceInfo['platform']!;
      final String osVersion = deviceInfo['os_version']!;

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
        baseUrl: 'https://test.backend.arcmedialabs.in',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      final response = await dio.post('/api/user/device-token/', data: requestBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
        isRegistered.value = true;
        _processedFcmTokens.add(tokenToUse);

        // ✅ Save device ID locally
        await SharedPrefsHelper.setPermanentDeviceId(deviceId);
        _permanentDeviceId = deviceId;

        print('\n✅ NEW Device created successfully:');
        print('   🆕 Device ID: $deviceId (NEW)');
        print('   📱 Device Name: $deviceName');

        return DeviceRegistrationResult(success: true);
      }
      return DeviceRegistrationResult(success: false);
    } catch (e) {
      print('❌ Error creating new device: $e');
      return DeviceRegistrationResult(success: false, error: e.toString());
    }
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
        baseUrl: 'https://test.backend.arcmedialabs.in',
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));
      final response = await dio.get('/api/user/devices/');

      if (response.statusCode == 200 && response.data['result'] == 'success') {
        final devicesList = (response.data['data'] as List)
            .map((json) => DeviceInfo.fromJson(json))
            .toList();
        devices.assignAll(devicesList);
        return devicesList;
      }
      return [];
    } catch (e) {
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
        baseUrl: 'https://test.backend.arcmedialabs.in',
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));

      final response = await dio.post(
        '/api/user/devices/logout/',
        data: {'device_id': deviceRecordId},
      );

      if (response.statusCode == 200 && response.data['result'] == 'success') {
        devices.removeWhere((d) => d.id == deviceRecordId);
        return true;
      }
      return false;
    } catch (e) {
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