// auth_view_model.dart - COMPLETE with Location Fallback & Facebook Events

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/facebook_events.dart';
import '../services/shared_prefs_helper.dart';
import '../services/auto_refresh_service.dart';
import '../services/device_manager.dart';
import 'home_view_model.dart';
import 'booking_view_model.dart';
import 'profile_view_model.dart';
import '../routes/app_routes.dart';
// 🔥 Import Facebook App Events
import 'package:book_your_turf/main.dart' show facebookAppEvents;

class AuthViewModel extends GetxController {
  final isLoading = false.obs;
  final otpResendCooldown = 60.obs;
  String? _tempEmail;
  String? _tempPhone;
  String? _tempName;
  String? _tempPassword;
  String? _tempReferralCode;
  String? _tempVerificationMethod;
  String? _tempIdentifier;
  Timer? _timer;
  Timer? _expiryTimer;

  DateTime? _otpSentTime;
  static const int otpValidDuration = 60;

  // ✅ Flag to prevent duplicate device registration
  bool _deviceRegistrationStarted = false;

  // Google Maps API Key
  static const String googleMapsApiKey = 'AIzaSyBQ6kiaROyTfm7TLKG2c_FA1XER8IVaMlY';

  @override
  void onClose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    super.onClose();
  }

  void startResendTimer() {
    _timer?.cancel();
    _startTimer();
  }

  void _startTimer() {
    otpResendCooldown.value = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (otpResendCooldown.value <= 0) {
        timer.cancel();
      } else {
        otpResendCooldown.value--;
      }
    });
  }

  bool isOtpTimeExpired() {
    if (_otpSentTime == null) return true;
    final difference = DateTime.now().difference(_otpSentTime!);
    return difference.inSeconds > otpValidDuration;
  }

  int getRemainingSeconds() {
    if (_otpSentTime == null) return 0;
    final difference = DateTime.now().difference(_otpSentTime!);
    final remaining = otpValidDuration - difference.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void clearOtpTime() {
    _otpSentTime = null;
    _timer?.cancel();
    _expiryTimer?.cancel();
    otpResendCooldown.value = 60;
  }

  // ==================== REGISTRATION - SEND OTP ====================
  Future<bool> sendRegistrationOtp({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? referralCode,
    required String verificationMethod,
  }) async {
    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();

      _tempName = name;
      _tempEmail = email;
      _tempPhone = phone;
      _tempPassword = password;
      _tempReferralCode = referralCode;
      _tempVerificationMethod = verificationMethod;
      _tempIdentifier = verificationMethod == 'email' ? email : phone;

      Map<String, dynamic> requestData = {
        'name': name,
        'email': email,
        'number': phone,
        'password': password,
        'verification_method': verificationMethod,
      };
      if (referralCode != null && referralCode.isNotEmpty) {
        requestData['referral_code'] = referralCode;
      }

      final response = await dio.post('/user/send-otp/', data: requestData);

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      if (response.data['result'] == 'success') {
        _otpSentTime = DateTime.now();
        _startTimer();
        _showSuccess('OTP sent to ${verificationMethod == 'email' ? email : phone}');
        return true;
      } else {
        String msg = response.data['message'] ?? 'Failed to send OTP';
        _showError(msg);
        return false;
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _showError(_getApiErrorMessage(e));
      return false;
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _showError('Something went wrong. Please try again.');
      return false;
    }
  }

  // ==================== RESEND OTP ====================
  Future<bool> resendOtp(String identifier) async {
    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();
      final response = await dio.post('/user/resend-otp/', data: {'identifier': identifier});

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      if (response.data['result'] == 'success') {
        _otpSentTime = DateTime.now();
        _startTimer();
        _showSuccess('OTP resent successfully');
        return true;
      } else {
        String msg = response.data['message'] ?? 'Failed to resend OTP';
        _showError(msg);
        return false;
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _showError(_getApiErrorMessage(e));
      return false;
    }
  }

  // ==================== VERIFY OTP & CREATE ACCOUNT ====================
  Future<bool> verifyOtp(String otp, String identifier) async {
    if (isOtpTimeExpired()) {
      _showError('OTP has expired. Please request a new one.');
      return false;
    }

    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();
      final response = await dio.post('/user/verify-register/', data: {'identifier': identifier, 'otp': otp});

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      if (response.statusCode == 201 && response.data['result'] == 'success') {
        // 🔥 Facebook Registration Event - Account Created Successfully
        try {
          await facebookAppEvents.logEvent(
            name: 'fb_mobile_complete_registration',
            parameters: {
              'registration_method': 'otp_${_tempVerificationMethod ?? 'email'}',
              'email': _tempEmail ?? '',
              'phone': _tempPhone ?? '',
              'name': _tempName ?? '',
            },
          );
          print('✅ Facebook registration event logged');
        } catch (e) {
          print('❌ Facebook registration event error: $e');
        }

        _showSuccess('Account created successfully! Please login');
        _tempIdentifier = _tempEmail = _tempPhone = _tempName = _tempPassword = _tempReferralCode = null;
        clearOtpTime();
        return true;
      } else {
        String msg = response.data['message'] ?? 'Verification failed';
        _showError(msg);
        return false;
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _showError(_getApiErrorMessage(e));
      return false;
    }
  }

  // ==================== FORGOT PASSWORD - SEND OTP ====================
  Future<bool> sendPasswordResetOtp({
    required String verificationMethod,
    String? email,
    String? phone,
  }) async {
    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();
      Map<String, dynamic> requestData = {'verification_method': verificationMethod};

      if (verificationMethod == 'email' && email != null) {
        requestData['email'] = email;
      } else if (verificationMethod == 'phone' && phone != null) {
        requestData['number'] = phone;
      }

      final response = await dio.post('/user/forgot-password-otp/', data: requestData);

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      if (response.data['result'] == 'success') {
        _otpSentTime = DateTime.now();
        _startTimer();
        _showSuccess('OTP sent successfully');
        return true;
      } else {
        String msg = response.data['message'] ?? 'Failed to send OTP';
        _showError(msg);
        return false;
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _showError(_getApiErrorMessage(e));
      return false;
    }
  }

  // ==================== RESET PASSWORD ====================
  Future<bool> resetPassword(String otp, String newPassword, {required String identifier}) async {
    if (isOtpTimeExpired()) {
      _showError('OTP has expired. Please request a new one.');
      return false;
    }

    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();
      final response = await dio.post('/user/reset-password/', data: {
        'identifier': identifier,
        'otp': otp,
        'new_password': newPassword
      });

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      if (response.statusCode == 200 && response.data['result'] == 'success') {
        _showSuccess('Password reset successful! Please login with your new password.');
        clearOtpTime();
        return true;
      } else {
        String msg = response.data['message'] ?? 'Password reset failed';
        _showError(msg);
        return false;
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _showError(_getApiErrorMessage(e));
      return false;
    }
  }

  // ==================== LOGIN ====================
  Future<bool> login(String loginId, String password) async {
    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();
      final response = await dio.post('/user/login/', data: {'login_id': loginId, 'password': password});

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      if (response.data['result'] == 'success') {
        final token = response.data['data']['access'];
        final user = response.data['data']['user'];

        await SharedPrefsHelper.setToken(token);
        await SharedPrefsHelper.setUserId(user['id']);
        await SharedPrefsHelper.setUserName(user['name']);
        await SharedPrefsHelper.setUserEmail(user['email']);
        await SharedPrefsHelper.setUserPhone(user['number']);
        await SharedPrefsHelper.setWalletBalance(double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0);
        await SharedPrefsHelper.setGameCoins(user['game_coins'] ?? 0);
        await SharedPrefsHelper.setReferralCode(user['referral_code'] ?? '');

        // 🔥 Facebook Login Event
        try {
          await facebookAppEvents.logEvent(
            name: 'fb_mobile_login',
            parameters: {
              'registration_method': 'email_password',
              'user_id': user['id'].toString(),
              'user_email': user['email'] ?? '',
              'user_name': user['name'] ?? '',
            },
          );
          print('✅ Facebook login event logged');
        } catch (e) {
          print('❌ Facebook login event error: $e');
        }

        // ✅ Register device token with location
        await _registerDeviceToken(token);

        // Load initial data
        await _loadInitialData();

        _showSuccess('Welcome ${user['name']}!');
        Get.offAllNamed(AppRoutes.mainPage);
        return true;
      } else {
        String msg = response.data['message'] ?? 'Invalid credentials';
        _showError(msg);
        return false;
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _showError(_getApiErrorMessage(e));
      return false;
    }
  }

  // ==================== FETCH LOCATION DIRECTLY (FALLBACK) ====================

  Future<String?> _fetchCurrentLocationDirectly() async {
    print('\n📍 Fetching location directly for device registration...');

    try {
      // Request permission
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

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      print('📍 Got coordinates: ${position.latitude}, ${position.longitude}');

      // Get location name from Google Maps API
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

            // Save to SharedPreferences
            await SharedPrefsHelper.saveDeviceLocation(locationName);
            print('📍 Location fetched directly: "$locationName"');
            return locationName;
          }
        }
      }

      // Fallback to coordinates
      final coordinates = "${position.latitude},${position.longitude}";
      await SharedPrefsHelper.saveDeviceLocation(coordinates);
      print('📍 Using coordinates: "$coordinates"');
      return coordinates;

    } catch (e) {
      print('❌ Error fetching location: $e');
      return null;
    }
  }

  // ==================== DEVICE TOKEN REGISTRATION - SINGLE CALL ====================

  Future<void> _registerDeviceToken(String jwtToken) async {
    // ✅ Prevent multiple calls
    if (_deviceRegistrationStarted) {
      print('⏭️ Device registration already started, skipping duplicate...');
      return;
    }

    // ✅ Check if already registered recently (7 days validity)
    final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
    if (isValid) {
      print('✅ Device already registered recently, skipping...');
      return;
    }

    // ✅ Check if already registered in this session
    if (Get.isRegistered<DeviceManager>()) {
      final deviceManager = Get.find<DeviceManager>();
      if (deviceManager.isRegistered.value) {
        print('✅ Device already registered in this session, skipping...');
        return;
      }
    }

    _deviceRegistrationStarted = true;

    // ✅ Try to get location from HomeViewModel first
    String? currentLocation;
    if (Get.isRegistered<HomeViewModel>()) {
      final homeVm = Get.find<HomeViewModel>();
      int attempts = 0;
      while (homeVm.currentLocationName.value.isEmpty && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      currentLocation = homeVm.currentLocationName.value;
      if (currentLocation.isNotEmpty) {
        print('📍 Got location from HomeViewModel: "$currentLocation"');
      }
    }

    // ✅ If no location from HomeViewModel, fetch directly
    if (currentLocation == null || currentLocation.isEmpty) {
      print('⚠️ No location from HomeViewModel, fetching directly...');
      currentLocation = await _fetchCurrentLocationDirectly();
    }

    // Initialize DeviceManager
    if (!Get.isRegistered<DeviceManager>()) {
      Get.put(DeviceManager(), permanent: true);
    }

    final deviceManager = Get.find<DeviceManager>();

    // ✅ Register device (ONLY ONE API CALL)
    print('\n📱 Registering device (ONCE per session)...');
    print('📍 Location to send: "${currentLocation ?? "none"}"');

    final result = await deviceManager.registerDevice(
      jwtToken: jwtToken,
      location: currentLocation,
    );

    if (result.success) {
      print('✅ Device registered successfully with location: ${currentLocation ?? "none"}');
      await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
    } else {
      print('❌ Device registration failed: ${result.error}');
    }
  }

  // ==================== LOAD INITIAL DATA ====================
  Future<void> _loadInitialData() async {
    try {
      if (Get.isRegistered<ProfileViewModel>()) {
        await Get.find<ProfileViewModel>().fetchUser();
      }
      if (Get.isRegistered<HomeViewModel>()) {
        await Get.find<HomeViewModel>().fetchTurfs();
        await Get.find<HomeViewModel>().getUserLocation();
      }
      if (Get.isRegistered<BookingViewModel>()) {
        await Get.find<BookingViewModel>().fetch();
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    if (Get.isRegistered<AutoRefreshService>()) {
      Get.find<AutoRefreshService>().stop();
    }

    // Clear device registration
    if (Get.isRegistered<DeviceManager>()) {
      await Get.find<DeviceManager>().clearRegistration();
    }

    await SharedPrefsHelper.clearAll();

    if (Get.isRegistered<HomeViewModel>()) {
      Get.find<HomeViewModel>().turfs.clear();
    }
    if (Get.isRegistered<BookingViewModel>()) {
      Get.find<BookingViewModel>().bookings.clear();
    }
    if (Get.isRegistered<ProfileViewModel>()) {
      Get.find<ProfileViewModel>().name.value = '';
      Get.find<ProfileViewModel>().walletBalance.value = 0.0;
    }
    Get.offAllNamed(AppRoutes.login);
    _showSuccess('Successfully logged out');
  }

  // ==================== HELPER METHODS ====================

  String _getApiErrorMessage(DioException e) {
    if (e.response != null && e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map) {
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] != null) return data['error'].toString();
        if (data['detail'] != null) return data['detail'].toString();
      } else if (data is String) {
        return data;
      }
      switch (e.response?.statusCode) {
        case 400: return 'Bad request. Please check your input.';
        case 401: return 'Unauthorized. Please login again.';
        case 403: return 'Access denied.';
        case 404: return 'Service not found. Please try again.';
        case 500: return 'Server error. Please try again later.';
        default: return 'Request failed with status ${e.response?.statusCode}';
      }
    } else if (e.message != null) {
      if (e.message!.contains('SocketException')) {
        return 'No internet connection. Please check your network.';
      }
      if (e.message!.contains('Timeout')) {
        return 'Connection timeout. Please try again.';
      }
      return e.message!;
    }
    return 'An unexpected error occurred. Please try again.';
  }

  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    );
  }

  void _showError(String message) {
    print('❌ API Error: $message');

    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      mainButton: TextButton(
        onPressed: () => Get.back(),
        child: const Text('OK', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  String? getRegistrationIdentifier() {
    return _tempIdentifier;
  }
}