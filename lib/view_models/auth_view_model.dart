// auth_view_model.dart - Complete with device registration after login
// ✅ SINGLE DOMAIN CONFIGURATION
// ✅ Duplicate login prevention

import 'dart:async';
import 'dart:convert';
import 'package:book_your_turf/config/app_config.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import 'package:book_your_turf/view_models/profile_view_model.dart';
import 'package:flutter/material.dart';
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
import '../routes/app_routes.dart';
import 'package:book_your_turf/main.dart' show facebookAppEvents;

import 'booking_view_model.dart';
import 'home_view_model.dart';
import 'wallet_view_model.dart';
import 'coin_view_model.dart';
import 'discount_view_model.dart';
import 'favorites_view_model.dart';

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
  static const int otpValidDuration = AppConfig.otpValidDuration;

  bool _deviceRegistrationStarted = false;

  // ✅ DUPLICATE API CALL PREVENTION
  bool _isLoggingIn = false;

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
    otpResendCooldown.value = AppConfig.otpResendCooldown;
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
    otpResendCooldown.value = AppConfig.otpResendCooldown;
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

      final response = await dio.post(AppConfig.authSendOtp, data: requestData);

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
      final response = await dio.post(AppConfig.authResendOtp, data: {'identifier': identifier});

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
      final response = await dio.post(AppConfig.authVerifyOtp, data: {'identifier': identifier, 'otp': otp});

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

        _tempIdentifier = null;
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

      final response = await dio.post(AppConfig.authForgotPasswordOtp, data: requestData);

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
      final response = await dio.post(AppConfig.authResetPassword, data: {
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

  // ============================================================
  // ✅ LOGIN - With immediate device registration
  // ✅ Duplicate prevention
  // ============================================================

  Future<bool> login(String loginId, String password) async {
    // ✅ FIX: Prevent concurrent login attempts
    if (_isLoggingIn) {
      print('⏭️ Login already in progress - skipping duplicate');
      return false;
    }

    if (loginId.isEmpty || password.isEmpty) {
      _showError('Please enter both email/phone and password');
      return false;
    }

    _isLoggingIn = true;
    isLoading.value = true;
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final dio = Get.find<Dio>();

      Map<String, dynamic> requestData = {
        'password': password,
      };

      if (loginId.contains('@')) {
        print('📤 Login with Email: $loginId');
        requestData['email'] = loginId;
        requestData['username'] = loginId;
        requestData['login_id'] = loginId;

        if (loginId.replaceAll(RegExp(r'\D'), '').length >= 10) {
          requestData['number'] = loginId.replaceAll(RegExp(r'\D'), '');
          requestData['phone'] = loginId.replaceAll(RegExp(r'\D'), '');
          requestData['mobile'] = loginId.replaceAll(RegExp(r'\D'), '');
        }
      } else {
        String cleanPhone = loginId.replaceAll(RegExp(r'\D'), '');
        print('📤 Login with Phone: $cleanPhone');
        requestData['number'] = cleanPhone;
        requestData['phone'] = cleanPhone;
        requestData['mobile'] = cleanPhone;
        requestData['phone_number'] = cleanPhone;
        requestData['username'] = cleanPhone;
        requestData['login_id'] = cleanPhone;
      }

      print('📡 API POST /user/login/');
      print('📤 Request Fields: ${requestData.keys.join(", ")}');

      final response = await dio.post(AppConfig.authLogin, data: requestData);

      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _isLoggingIn = false;

      print('📥 Login Response Status: ${response.statusCode}');
      print('📥 Login Response Result: ${response.data['result']}');

      if (response.data['result'] == 'success') {
        final token = response.data['data']['access'];
        final user = response.data['data']['user'];

        int userId = 0;
        final idValue = user['id'];
        if (idValue is int) {
          userId = idValue;
        } else if (idValue is String) {
          userId = int.tryParse(idValue) ?? 0;
        } else if (idValue is double) {
          userId = idValue.toInt();
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

        await SharedPrefsHelper.setAppInitialized(true);

        print('✅ User data saved:');
        print('   ID: $userId');
        print('   Name: ${user['name']}');
        print('   Email: ${user['email']}');
        print('   Phone: ${user['number']}');

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

        print('\n╔════════════════════════════════════════════════════════════╗');
        print('║  📱 LOGIN SUCCESS - REGISTERING DEVICE                     ║');
        print('╚════════════════════════════════════════════════════════════╝');

        final deviceRegistered = await _registerDeviceToken(token);

        if (deviceRegistered) {
          print('✅ Device registered successfully after login');
        } else {
          print('⚠️ Device registration failed after login - will retry on next launch');
        }

        await AppInitializer.initializeApp();

        _showSuccess('Welcome ${user['name']}!');
        Get.offAllNamed(AppRoutes.mainPage);
        _isLoggingIn = false;
        return true;
      } else {
        print('⚠️ Login failed with all fields, trying individual fields...');
        final result = await _tryLoginWithIndividualFields(loginId, password, dio);
        _isLoggingIn = false;
        return result;
      }
    } on DioException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      isLoading.value = false;
      _isLoggingIn = false;

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
      _isLoggingIn = false;
      print('❌ Login error: $e');
      _showError('Something went wrong. Please try again.');
      return false;
    }
  }

  // ✅ FIXED: Try individual fields with a limit, not infinite loop
  Future<bool> _tryLoginWithIndividualFields(String loginId, String password, Dio dio) async {
    List<String> fieldNames = [];
    String cleanPhone = loginId.replaceAll(RegExp(r'\D'), '');

    if (loginId.contains('@')) {
      fieldNames = ['email', 'username', 'login_id'];
    } else {
      fieldNames = ['number', 'phone', 'mobile', 'phone_number', 'username', 'login_id'];
    }

    // ✅ Try each field once, stop on success
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

        final response = await dio.post(AppConfig.authLogin, data: requestData);

        if (response.data['result'] == 'success') {
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

          await SharedPrefsHelper.setAppInitialized(true);

          print('✅ Login successful with field: $field');
          print('   Name: ${user['name']}');

          print('\n╔════════════════════════════════════════════════════════════╗');
          print('║  📱 LOGIN SUCCESS - REGISTERING DEVICE                     ║');
          print('╚════════════════════════════════════════════════════════════╝');

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

  // ============================================================
  // ✅ AUTO-LOGIN AFTER REGISTRATION
  // ============================================================

  Future<bool> autoLoginAfterRegistration({
    required String email,
    required String phone,
    required String password,
    required String name,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  📱 AUTO-LOGIN AFTER REGISTRATION                          ║');
    print('╚════════════════════════════════════════════════════════════╝');

    try {
      String loginId = phone.isNotEmpty ? phone : email;
      return await login(loginId, password);
    } catch (e) {
      print('❌ Auto-login error: $e');
      return false;
    }
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

      final url = Uri.parse(AppConfig.geocodeUrl(position.latitude, position.longitude));

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

  // ============================================================
  // ✅ DEVICE TOKEN REGISTRATION - IMMEDIATE
  // ============================================================

  Future<bool> _registerDeviceToken(String jwtToken) async {
    if (_deviceRegistrationStarted) {
      print('⏭️ Device registration already started, skipping duplicate...');
      return false;
    }

    final isValid = await SharedPrefsHelper.isTokenRegistrationValid();
    if (isValid) {
      print('✅ Device already registered recently, updating token...');
    }

    if (Get.isRegistered<DeviceManager>()) {
      final deviceManager = Get.find<DeviceManager>();
      if (deviceManager.isRegistered.value) {
        print('✅ Device already registered in this session, updating token...');
      }
    }

    _deviceRegistrationStarted = true;

    try {
      final persistentDeviceId = await SharedPrefsHelper.getPermanentDeviceId();
      print('📱 Persistent Device ID for registration: $persistentDeviceId');

      String? currentLocation;
      if (Get.isRegistered<HomeViewModel>()) {
        final homeVm = Get.find<HomeViewModel>();
        int attempts = 0;
        while (homeVm.currentLocationName.value.isEmpty && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        currentLocation = homeVm.currentLocationName.value;
        if (currentLocation!.isNotEmpty) {
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

      print('\n📱 Registering device with PERSISTENT ID...');
      print('   🆔 Device ID: $persistentDeviceId');
      print('   👤 User: ${SharedPrefsHelper.getUserEmail() ?? 'Unknown'}');
      print('   📍 Location: "${currentLocation ?? "none"}"');

      final result = await deviceManager.registerDevice(
        jwtToken: jwtToken,
        location: currentLocation,
      );

      if (result.success) {
        print('✅ Device registered successfully');
        await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
        _deviceRegistrationStarted = false;
        return true;
      } else {
        print('❌ Device registration failed: ${result.error}');
        _deviceRegistrationStarted = false;
        return false;
      }
    } catch (e) {
      print('❌ Device registration error: $e');
      _deviceRegistrationStarted = false;
      return false;
    }
  }

  Future<bool> forceRegisterDevice() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('❌ No token available for device registration');
      return false;
    }

    print('🔄 Force registering device...');
    _deviceRegistrationStarted = false;
    return await _registerDeviceToken(token);
  }

  // ============================================================
  // ✅ LOGOUT - COMPLETE CLEANUP
  // ============================================================

  Future<void> logout() async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  🚪 LOGGING OUT - COMPLETE CLEANUP                        ║');
    print('╚════════════════════════════════════════════════════════════╝');

    if (Get.isRegistered<AutoRefreshService>()) {
      Get.find<AutoRefreshService>().stop();
      print('✅ AutoRefreshService stopped');
    }

    if (Get.isRegistered<DeviceManager>()) {
      final deviceManager = Get.find<DeviceManager>();
      await deviceManager.clearRegistration();
      print('✅ Device registration cleared');
    }

    AppInitializer.reset();
    print('✅ AppInitializer reset');

    if (Get.isRegistered<CacheManager>()) {
      Get.find<CacheManager>().clearAllCaches();
      print('✅ CacheManager cleared');
    } else {
      final cacheManager = CacheManager();
      cacheManager.clearAllCaches();
      print('✅ CacheManager cleared (standalone)');
    }

    await SharedPrefsHelper.clearAll();
    print('✅ SharedPreferences cleared (Device ID preserved)');

    if (Get.isRegistered<HomeViewModel>()) {
      final homeVm = Get.find<HomeViewModel>();
      homeVm.turfs.clear();
      homeVm.allTurfs.clear();
      homeVm.nearbyTurfs.clear();
      homeVm.searchResults.clear();
      homeVm.searchQuery.value = '';
      homeVm.selectedCategory.value = '';
      homeVm.homeError.value = '';
      print('✅ HomeViewModel cleared');
    }

    if (Get.isRegistered<BookingViewModel>()) {
      final bookingVm = Get.find<BookingViewModel>();
      bookingVm.bookings.clear();
      bookingVm.filteredBookings.clear();
      BookingViewModel.resetCache();
      print('✅ BookingViewModel cleared');
    }

    if (Get.isRegistered<ProfileViewModel>()) {
      final profileVm = Get.find<ProfileViewModel>();
      profileVm.name.value = '';
      profileVm.email.value = '';
      profileVm.phone.value = '';
      profileVm.walletBalance.value = 0.0;
      profileVm.gameCoins.value = 0;
      profileVm.referralCode.value = '';
      profileVm.profileImageUrl.value = '';
      ProfileViewModel.resetCache();
      print('✅ ProfileViewModel cleared');
    }

    if (Get.isRegistered<WalletViewModel>()) {
      WalletViewModel.resetCache();
      print('✅ WalletViewModel cache reset');
    }

    if (Get.isRegistered<CoinViewModel>()) {
      CoinViewModel.resetCache();
      print('✅ CoinViewModel cache reset');
    }

    if (Get.isRegistered<DiscountViewModel>()) {
      DiscountViewModel.resetCache();
      print('✅ DiscountViewModel cache reset');
    }

    if (Get.isRegistered<FavoritesViewModel>()) {
      FavoritesViewModel.resetCache();
      print('✅ FavoritesViewModel cache reset');
    }

    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      await FirebaseMessaging.instance.unsubscribeFromTopic('offers');
      print('✅ Unsubscribed from FCM topics');
    } catch (e) {
      print('⚠️ Could not unsubscribe from topics: $e');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
      print('✅ FCM token deleted');
    } catch (e) {
      print('⚠️ Could not delete FCM token: $e');
    }

    print('\n✅ LOGOUT COMPLETE - All data cleared');
    print('   🔒 Device ID preserved');
    print('   🔄 App will start fresh on next login');
    print('═══════════════════════════════════════════════════════════════\n');

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