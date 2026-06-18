// services/device_manager.dart
// ✅ Complete with all methods

import 'dart:io';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/shared_prefs_helper.dart';

class DeviceManager extends GetxService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool _isRegistering = false;
  bool _apiCalled = false;

  final isRegistered = false.obs;
  final devices = <DeviceInfo>[].obs;
  final isLoading = false.obs;

  static const String googleMapsApiKey = 'AIzaSyBQ6kiaROyTfm7TLKG2c_FA1XER8IVaMlY';

  @override
  void onInit() {
    super.onInit();
    _checkExistingRegistration();
  }

  Future<void> _checkExistingRegistration() async {
    final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
    if (isValid) {
      isRegistered.value = true;
      _apiCalled = true;
      print('✅ Device already registered (valid until 7 days)');
    }
  }

  Future<String> getDeviceId() async => await SharedPrefsHelper.getDeviceId();

  // ==================== FETCH LOCATION DIRECTLY ====================

  Future<String?> fetchCurrentLocation() async {
    print('\n📍 Fetching current location for device registration...');

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      print('📍 Got coordinates: ${position.latitude}, ${position.longitude}');

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleMapsApiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'];
          if (results.isNotEmpty) {
            String area = '';
            String city = '';
            String state = '';

            final components = results[0]['address_components'] as List;
            for (var comp in components) {
              final types = comp['types'] as List;
              if (area.isEmpty && (types.contains('sublocality_level_1') ||
                  types.contains('sublocality') ||
                  types.contains('neighborhood') ||
                  types.contains('route'))) {
                area = comp['long_name'];
              }
              if (types.contains('locality') && city.isEmpty) {
                city = comp['long_name'];
              }
              if (types.contains('administrative_area_level_1') && state.isEmpty) {
                state = comp['long_name'];
              }
            }

            String locationName = "";
            if (area.isNotEmpty && city.isNotEmpty && area != city) {
              locationName = "$area, $city";
            } else if (city.isNotEmpty && state.isNotEmpty) {
              locationName = "$city, $state";
            } else if (city.isNotEmpty) {
              locationName = city;
            } else if (area.isNotEmpty) {
              locationName = area;
            } else {
              locationName = results[0]['formatted_address'];
            }

            await SharedPrefsHelper.saveDeviceLocation(locationName);
            print('📍 Location fetched: "$locationName"');
            return locationName;
          }
        }
      }

      final coordinates = "${position.latitude},${position.longitude}";
      await SharedPrefsHelper.saveDeviceLocation(coordinates);
      print('📍 Using coordinates: "$coordinates"');
      return coordinates;

    } catch (e) {
      print('❌ Error fetching location: $e');
      return null;
    }
  }

  Future<Map<String, String>> getDeviceInfo() async {
    final deviceId = await SharedPrefsHelper.getDeviceId();

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'device_id': deviceId,
        'platform': 'android',
        'device_name': _getDeviceName(androidInfo.model, androidInfo.manufacturer),
        'os_version': androidInfo.version.release,
      };
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return {
        'device_id': deviceId,
        'platform': 'ios',
        'device_name': _getDeviceName(iosInfo.model, 'Apple'),
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

  // ==================== REGISTER DEVICE ====================

  Future<DeviceRegistrationResult> registerDevice({
    required String jwtToken,
    String? fcmToken,
    String? location,
  }) async {
    if (_apiCalled) {
      print('⏭️ API already called once, skipping...');
      return DeviceRegistrationResult(success: true, message: 'Already registered');
    }

    if (isRegistered.value) {
      print('✅ Device already registered, skipping API call');
      return DeviceRegistrationResult(success: true, message: 'Already registered');
    }

    final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
    if (isValid) {
      print('✅ Device registration still valid (within 7 days), skipping API call');
      isRegistered.value = true;
      _apiCalled = true;
      return DeviceRegistrationResult(success: true, message: 'Registration still valid');
    }

    if (_isRegistering) {
      print('⏭️ Registration already in progress...');
      return DeviceRegistrationResult(success: false, message: 'Already registering');
    }

    _isRegistering = true;

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  📱 DEVICE REGISTRATION                                      ║');
    print('╚════════════════════════════════════════════════════════════╝');

    final result = DeviceRegistrationResult();

    try {
      final tokenToUse = fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (tokenToUse == null) {
        result.success = false;
        result.error = 'No FCM token';
        return result;
      }

      final deviceInfo = await getDeviceInfo();

      String? locationToUse = location;
      if (locationToUse == null || locationToUse.isEmpty) {
        locationToUse = await fetchCurrentLocation();
      }

      final Map<String, dynamic> requestBody = {
        'token': tokenToUse,
        'device_id': deviceInfo['device_id']!,
        'platform': deviceInfo['platform']!,
        'device_name': deviceInfo['device_name'] ?? 'Unknown',
        'os_version': deviceInfo['os_version'] ?? 'unknown',
      };

      if (locationToUse != null && locationToUse.isNotEmpty) {
        requestBody['location'] = locationToUse;
        print('\n📍 Location added: "$locationToUse"');
      }

      print('\n📤 API Request:');
      print('   device_id: ${deviceInfo['device_id']}');
      print('   platform: ${deviceInfo['platform']}');
      print('   device_name: ${deviceInfo['device_name']}');
      print('   location: ${locationToUse ?? "none"}');

      final dio = Dio(BaseOptions(
        baseUrl: 'https://backend.arcmedialabs.in',
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      ));

      final response = await dio.post('/api/user/device-token/', data: requestBody);

      print('\n📥 Response: Status ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        result.success = true;
        await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
        isRegistered.value = true;
        _apiCalled = true;
        print('\n✅ Device registered successfully!');
      } else {
        result.success = false;
        print('❌ Registration failed');
      }

    } catch (e) {
      result.success = false;
      result.error = e.toString();
      print('❌ Error: $e');
    } finally {
      _isRegistering = false;
    }

    return result;
  }

  Future<bool> registerDeviceToken({String? location}) async {
    final jwtToken = SharedPrefsHelper.getToken();
    if (jwtToken == null || jwtToken.isEmpty) return false;
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
        baseUrl: 'https://backend.arcmedialabs.in',
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));
      final response = await dio.get('/api/user/devices/');

      if (response.statusCode == 200 && response.data['result'] == 'success') {
        final devicesList = (response.data['data'] as List)
            .map((json) => DeviceInfo.fromJson(json))
            .toList();
        devices.assignAll(devicesList);
        print('✅ Found ${devicesList.length} devices');
        return devicesList;
      }
      return [];
    } catch (e) {
      print('❌ Error: $e');
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
        baseUrl: 'https://backend.arcmedialabs.in',
        headers: {'Authorization': 'Bearer $jwtToken'},
      ));

      print('\n📱 Logging out device ID: $deviceRecordId');
      final response = await dio.post(
        '/api/user/devices/logout/',
        data: {'device_id': deviceRecordId},
      );

      if (response.statusCode == 200 && response.data['result'] == 'success') {
        devices.removeWhere((d) => d.id == deviceRecordId);
        print('✅ Device logged out successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ==================== LOGOUT ALL OTHER DEVICES ====================

  Future<int> logoutAllOtherDevices() async {
    final jwtToken = SharedPrefsHelper.getToken();
    if (jwtToken == null || jwtToken.isEmpty) {
      print('❌ No JWT token to logout devices');
      return 0;
    }

    // First fetch all devices
    final allDevices = await fetchDevices();
    final currentDeviceId = await getDeviceId();

    // Find devices to logout (all except current)
    final devicesToLogout = <int>[];

    for (var device in allDevices) {
      if (device.deviceId != currentDeviceId) {
        devicesToLogout.add(device.id);
        print('📍 Will logout: ${device.deviceName} (ID: ${device.id})');
      } else {
        print('📍 Current device: ${device.deviceName} (ID: ${device.id}) - Skipping');
      }
    }

    if (devicesToLogout.isEmpty) {
      print('📱 No other devices found to logout');
      return 0;
    }

    print('\n📱 Found ${devicesToLogout.length} other devices to logout');

    int successCount = 0;
    for (var deviceId in devicesToLogout) {
      final success = await logoutDevice(deviceId);
      if (success) {
        successCount++;
        print('✅ Logged out device ID: $deviceId');
      } else {
        print('❌ Failed to logout device ID: $deviceId');
      }
      // Small delay between requests
      await Future.delayed(const Duration(milliseconds: 500));
    }

    print('✅ Successfully logged out $successCount devices');
    return successCount;
  }

  // ==================== CLEAR REGISTRATION ====================

  Future<void> clearRegistration() async {
    isRegistered.value = false;
    _apiCalled = false;
    devices.clear();
    await SharedPrefsHelper.setLastTokenRegistration(null);
    print('🗑️ Device registration cleared');
  }
}

// ==================== DATA MODELS ====================

class DeviceRegistrationResult {
  bool success = false;
  String message = '';
  String? error;
  DeviceRegistrationResult({this.success = false, this.message = '', this.error});
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