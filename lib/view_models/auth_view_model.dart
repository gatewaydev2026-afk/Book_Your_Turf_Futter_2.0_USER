// auth_view_model.dart - COMPLETE FIXED LOGIN WITH ALL FIELD OPTIONS

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/app_initializer.dart';
import '../services/facebook_events.dart';
import '../services/shared_prefs_helper.dart';
import '../services/auto_refresh_service.dart';
import '../services/device_manager.dart';
import 'home_view_model.dart';
import 'booking_view_model.dart';
import 'profile_view_model.dart';
import '../routes/app_routes.dart';
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

  bool _deviceRegistrationStarted = false;

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
    // ✅ Validate input
    if (verificationMethod == 'email' && (email.isEmpty || !email.contains('@'))) {
      _showError('Please enter a valid email address');
      return false;
    }
    if (verificationMethod == 'phone' && (phone.isEmpty || phone.length < 10)) {
      _showError('Please enter a valid phone number');
      return false;
    }

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

      print('📤 SEND OTP Request: $requestData');

      final response = await dio.post('/user/send-otp/', data: requestData);

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      print('📥 SEND OTP Response: ${response.data}');

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

  // ==================== LOGIN - FIXED WITH MULTIPLE FIELD OPTIONS ====================

  Future<bool> login(String loginId, String password) async {
    // ✅ Validate input
    if (loginId.isEmpty || password.isEmpty) {
      _showError('Please enter both email/phone and password');
      return false;
    }

    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();

      // ✅ TRY ALL POSSIBLE FIELD NAMES - One will work
      Map<String, dynamic> requestData = {
        'password': password,
      };

      // Check if loginId is email or phone
      if (loginId.contains('@')) {
        // It's an email - Try all possible email field names
        print('📤 Login with Email: $loginId');

        // Try different email field names
        requestData['email'] = loginId;           // Most common
        requestData['username'] = loginId;        // Alternative
        requestData['login_id'] = loginId;        // Alternative

        // Also try as phone if it's a number
        if (loginId.replaceAll(RegExp(r'\D'), '').length >= 10) {
          requestData['number'] = loginId.replaceAll(RegExp(r'\D'), '');
          requestData['phone'] = loginId.replaceAll(RegExp(r'\D'), '');
          requestData['mobile'] = loginId.replaceAll(RegExp(r'\D'), '');
        }
      } else {
        // It's a phone number - Try all possible phone field names
        String cleanPhone = loginId.replaceAll(RegExp(r'\D'), '');
        print('📤 Login with Phone: $cleanPhone');

        requestData['number'] = cleanPhone;      // Your current field
        requestData['phone'] = cleanPhone;       // Alternative
        requestData['mobile'] = cleanPhone;      // Alternative
        requestData['phone_number'] = cleanPhone; // Alternative
        requestData['username'] = cleanPhone;    // Alternative
        requestData['login_id'] = cleanPhone;    // Alternative
      }

      print('📡 API POST /user/login/');
      print('📤 Request Fields: ${requestData.keys.join(", ")}');
      print('📤 Password: *****');

      final response = await dio.post('/user/login/', data: requestData);

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      print('📥 Login Response Status: ${response.statusCode}');
      print('📥 Login Response Result: ${response.data['result']}');

      if (response.data['result'] == 'success') {
        final token = response.data['data']['access'];
        final user = response.data['data']['user'];

        // Handle user ID properly
        int userId = 0;
        final idValue = user['id'];
        if (idValue is int) {
          userId = idValue;
        } else if (idValue is String) {
          userId = int.tryParse(idValue) ?? 0;
        } else if (idValue is double) {
          userId = idValue.toInt();
        }

        // Save token with expiry
        await SharedPrefsHelper.setToken(token);
        await SharedPrefsHelper.setUserId(userId);
        await SharedPrefsHelper.setUserName(user['name'] ?? '');
        await SharedPrefsHelper.setUserEmail(user['email'] ?? '');
        await SharedPrefsHelper.setUserPhone(user['number'] ?? '');
        await SharedPrefsHelper.setWalletBalance(
            double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0
        );
        await SharedPrefsHelper.setGameCoins(user['game_coins'] ?? 0);
        await SharedPrefsHelper.setReferralCode(user['referral_code'] ?? '');

        print('✅ User data saved:');
        print('   ID: $userId');
        print('   Name: ${user['name']}');
        print('   Email: ${user['email']}');
        print('   Phone: ${user['number']}');

        // Facebook Login Event
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

        // Register device token with location
        await _registerDeviceToken(token);

        // ✅ Load ONLY essential data using AppInitializer
        await AppInitializer.initializeApp();

        _showSuccess('Welcome ${user['name']}!');
        Get.offAllNamed(AppRoutes.mainPage);
        return true;
      } else {
        // ✅ If login fails, try with just one field at a time
        print('⚠️ Login failed with all fields, trying individual fields...');
        return await _tryLoginWithIndividualFields(loginId, password, dio);
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;

      // ✅ If DioException, try individual fields
      print('⚠️ DioException, trying individual fields...');
      try {
        final dio = Get.find<Dio>();
        return await _tryLoginWithIndividualFields(loginId, password, dio);
      } catch (e2) {
        if (e.response?.statusCode == 400) {
          _showError('Invalid email/phone or password. Please try again.');
        } else if (e.response?.statusCode == 401) {
          _showError('Invalid credentials. Please check your email/phone and password.');
        } else {
          _showError(_getApiErrorMessage(e));
        }
        return false;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      print('❌ Login error: $e');
      _showError('Something went wrong. Please try again.');
      return false;
    }
  }

  // ✅ Helper method to try individual field names
  Future<bool> _tryLoginWithIndividualFields(String loginId, String password, Dio dio) async {
    List<String> fieldNames = [];
    String cleanPhone = loginId.replaceAll(RegExp(r'\D'), '');

    if (loginId.contains('@')) {
      fieldNames = ['email', 'username', 'login_id'];
    } else {
      fieldNames = ['number', 'phone', 'mobile', 'phone_number', 'username', 'login_id'];
    }

    for (String field in fieldNames) {
      try {
        Map<String, dynamic> requestData = {
          'password': password,
        };

        if (loginId.contains('@')) {
          requestData[field] = loginId;
        } else {
          requestData[field] = cleanPhone;
        }

        print('📤 Trying login with field: $field = ${requestData[field]}');

        final response = await dio.post('/user/login/', data: requestData);

        if (response.data['result'] == 'success') {
          // Success! Process the response
          final token = response.data['data']['access'];
          final user = response.data['data']['user'];

          int userId = 0;
          final idValue = user['id'];
          if (idValue is int) {
            userId = idValue;
          } else if (idValue is String) {
            userId = int.tryParse(idValue) ?? 0;
          }

          await SharedPrefsHelper.setToken(token);
          await SharedPrefsHelper.setUserId(userId);
          await SharedPrefsHelper.setUserName(user['name'] ?? '');
          await SharedPrefsHelper.setUserEmail(user['email'] ?? '');
          await SharedPrefsHelper.setUserPhone(user['number'] ?? '');
          await SharedPrefsHelper.setWalletBalance(
              double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0
          );
          await SharedPrefsHelper.setGameCoins(user['game_coins'] ?? 0);
          await SharedPrefsHelper.setReferralCode(user['referral_code'] ?? '');

          print('✅ Login successful with field: $field');
          print('   Name: ${user['name']}');

          await _registerDeviceToken(token);
          await AppInitializer.initializeApp();

          _showSuccess('Welcome ${user['name']}!');
          Get.offAllNamed(AppRoutes.mainPage);
          return true;
        }
      } catch (e) {
        print('⚠️ Field "$field" failed: $e');
        continue;
      }
    }

    _showError('Invalid credentials. Please check your email/phone and password.');
    return false;
  }

  // ==================== FETCH LOCATION DIRECTLY ====================

  Future<String?> _fetchCurrentLocationDirectly() async {
    print('\n📍 Fetching location directly for device registration...');

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
            print('📍 Location fetched directly: "$locationName"');
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

  // ==================== DEVICE TOKEN REGISTRATION ====================

  Future<void> _registerDeviceToken(String jwtToken) async {
    if (_deviceRegistrationStarted) {
      print('⏭️ Device registration already started, skipping duplicate...');
      return;
    }

    final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
    if (isValid) {
      print('✅ Device already registered recently, skipping...');
      return;
    }

    if (Get.isRegistered<DeviceManager>()) {
      final deviceManager = Get.find<DeviceManager>();
      if (deviceManager.isRegistered.value) {
        print('✅ Device already registered in this session, skipping...');
        return;
      }
    }

    _deviceRegistrationStarted = true;

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

    if (currentLocation == null || currentLocation.isEmpty) {
      print('⚠️ No location from HomeViewModel, fetching directly...');
      currentLocation = await _fetchCurrentLocationDirectly();
    }

    if (!Get.isRegistered<DeviceManager>()) {
      Get.put(DeviceManager(), permanent: true);
    }

    final deviceManager = Get.find<DeviceManager>();

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

  // ==================== LOGOUT ====================

  Future<void> logout() async {
    if (Get.isRegistered<AutoRefreshService>()) {
      Get.find<AutoRefreshService>().stop();
    }

    if (Get.isRegistered<DeviceManager>()) {
      await Get.find<DeviceManager>().clearRegistration();
    }

    AppInitializer.reset();

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

  String? getRegistrationIdentifier() {
    return _tempIdentifier;
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
    print('❌ Error: $message');

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
}