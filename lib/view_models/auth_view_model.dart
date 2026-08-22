// view_models/auth_view_model.dart - COMPLETE PHONE OTP IMPLEMENTATION
// ✅ Phone OTP login/register (2 APIs only)
// ✅ No name/email/password on auth screens
// ✅ JWT stored locally, never expires
// ✅ Verified badge support
// ✅ FCM device registration after login
// ✅ Small snackbar with 1-second duration at TOP

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

  // Phone OTP state
  final phoneNumber = ''.obs;
  final isRegistered = false.obs;
  final isNumberVerified = false.obs;
  final otpSent = false.obs;
  final isNewUser = true.obs;
  final profileComplete = false.obs;

  Timer? _timer;
  Timer? _expiryTimer;

  DateTime? _otpSentTime;
  static const int otpValidDuration = AppConfig.otpValidDuration;

  bool _deviceRegistrationStarted = false;

  // ✅ DUPLICATE API CALL PREVENTION
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  // ✅ Store user data from verify response
  Map<String, dynamic>? _verifiedUserData;

  @override
  void onClose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    super.onClose();
  }

  // ============================================================
  // ✅ SHOW CUSTOM SMALL SNACKBAR AT TOP
  // ============================================================
  void _showSmallSnackbar(String title, String message, Color color) {
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: Colors.black,
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 8,
      maxWidth: 300,
      barBlur: 0,
      overlayBlur: 0,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOut,
      reverseAnimationCurve: Curves.easeIn,
      animationDuration: const Duration(milliseconds: 300),
      icon: Icon(
        color == Colors.red ? Icons.error_outline : Icons.check_circle,
        color: Colors.white,
        size: 18,
      ),
    );
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
    otpSent.value = false;
  }

  void resetPhoneAuth() {
    phoneNumber.value = '';
    isRegistered.value = false;
    isNumberVerified.value = false;
    otpSent.value = false;
    _verifiedUserData = null;
    clearOtpTime();
  }

  // ============================================================
  // ✅ 1) SEND OTP - Phone Auth
  // POST /api/user/phone/send-otp/
  // ============================================================
  Future<bool> sendPhoneOtp({
    required String number,
    String? referralCode,
  }) async {
    // Clean phone number (remove +91, 91, spaces, special chars)
    String cleanNumber = number.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    if (cleanNumber.startsWith('91')) {
      cleanNumber = cleanNumber.substring(2);
    }
    if (cleanNumber.length != 10) {
      _showSmallSnackbar('Error', 'Please enter a valid 10-digit mobile number', Colors.red);
      return false;
    }

    // ✅ Prevent duplicate calls
    if (_isSendingOtp) {
      print('⏭️ OTP send already in progress - skipping duplicate');
      return false;
    }

    _isSendingOtp = true;
    isLoading.value = true;

    try {
      final dio = Get.find<Dio>();

      Map<String, dynamic> requestData = {'number': cleanNumber};
      if (referralCode != null && referralCode.isNotEmpty) {
        requestData['referral_code'] = referralCode;
      }

      print('📤 SEND OTP Request: $requestData');

      final response = await dio.post(AppConfig.phoneSendOtp, data: requestData);

      isLoading.value = false;
      _isSendingOtp = false;

      print('📥 SEND OTP Response: ${response.data}');

      if (response.data['result'] == 'success') {
        final data = response.data['data'];
        phoneNumber.value = data['number'] ?? cleanNumber;
        isRegistered.value = data['is_registered'] ?? false;
        isNumberVerified.value = data['is_number_verified'] ?? false;
        otpSent.value = true;

        _otpSentTime = DateTime.now();
        _startTimer();

        _showSmallSnackbar('Success', 'OTP sent to $cleanNumber', Colors.white);
        return true;
      } else {
        String msg = response.data['message'] ?? 'Failed to send OTP';
        _showSmallSnackbar('Error', msg, Colors.red);
        return false;
      }
    } on DioException catch (e) {
      isLoading.value = false;
      _isSendingOtp = false;
      _showSmallSnackbar('Error', _getApiErrorMessage(e), Colors.red);
      return false;
    } catch (e) {
      isLoading.value = false;
      _isSendingOtp = false;
      _showSmallSnackbar('Error', 'Something went wrong. Please try again.', Colors.red);
      return false;
    }
  }

  // ============================================================
  // ✅ 2) VERIFY OTP - Phone Auth
  // POST /api/user/phone/verify-otp/
  // ============================================================
  Future<bool> verifyPhoneOtp({
    required String number,
    required String otp,
  }) async {
    // Clean phone number
    String cleanNumber = number.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    if (cleanNumber.startsWith('91')) {
      cleanNumber = cleanNumber.substring(2);
    }

    if (isOtpTimeExpired()) {
      _showSmallSnackbar('Error', 'OTP has expired. Please request a new one.', Colors.red);
      return false;
    }

    // ✅ Prevent duplicate calls
    if (_isVerifyingOtp) {
      print('⏭️ OTP verify already in progress - skipping duplicate');
      return false;
    }

    _isVerifyingOtp = true;
    isLoading.value = true;

    try {
      final dio = Get.find<Dio>();

      final requestData = {
        'number': cleanNumber,
        'otp': otp,
      };

      print('📤 VERIFY OTP Request: $requestData');

      final response = await dio.post(AppConfig.phoneVerifyOtp, data: requestData);

      isLoading.value = false;
      _isVerifyingOtp = false;

      print('📥 VERIFY OTP Response: ${response.data}');

      if (response.data['result'] == 'success') {
        final data = response.data['data'];
        _verifiedUserData = data;

        // ✅ Save JWT token (lifelong - never expires)
        final token = data['access'];
        final user = data['user'];

        if (token == null || token.isEmpty) {
          _showSmallSnackbar('Error', 'Authentication failed. Please try again.', Colors.red);
          return false;
        }

        int userId = 0;
        final idValue = user['id'];
        if (idValue is int) {
          userId = idValue;
        } else if (idValue is String) {
          userId = int.tryParse(idValue) ?? 0;
        } else if (idValue is double) {
          userId = idValue.toInt();
        }

        // ✅ Save user data
        await SharedPrefsHelper.setToken(token);
        await SharedPrefsHelper.setUserId(userId);
        await SharedPrefsHelper.setUserName(user['name'] ?? '');
        await SharedPrefsHelper.setUserEmail(user['email'] ?? '');
        await SharedPrefsHelper.setUserPhone(user['number'] ?? cleanNumber);
        await SharedPrefsHelper.setWalletBalance(
            double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0
        );
        await SharedPrefsHelper.setGameCoins(user['game_coins'] ?? 0);
        await SharedPrefsHelper.setReferralCode(user['referral_code'] ?? '');
        await SharedPrefsHelper.setAppInitialized(true);

        // ✅ Save phone auth specific flags
        await SharedPrefsHelper.setIsPhoneAuthUser(true);
        await SharedPrefsHelper.setIsNumberVerified(user['is_number_verified'] ?? false);
        await SharedPrefsHelper.setIsNewUser(data['is_new_user'] ?? true);
        await SharedPrefsHelper.setProfileComplete(data['profile_complete'] ?? false);

        isNewUser.value = data['is_new_user'] ?? true;
        profileComplete.value = data['profile_complete'] ?? false;

        print('✅ User data saved:');
        print('   ID: $userId');
        print('   Name: ${user['name']}');
        print('   Email: ${user['email']}');
        print('   Phone: ${user['number']}');
        print('   Is New User: ${data['is_new_user']}');
        print('   Is Number Verified: ${user['is_number_verified']}');
        print('   Profile Complete: ${data['profile_complete']}');

        // ✅ Log Facebook event
        try {
          await facebookAppEvents.logEvent(
            name: 'fb_mobile_login',
            parameters: {
              'registration_method': 'phone_otp',
              'user_id': user['id'].toString(),
              'user_phone': user['number'] ?? '',
              'is_new_user': data['is_new_user'].toString(),
            },
          );
          print('✅ Facebook login event logged');
        } catch (e) {
          print('❌ Facebook login event error: $e');
        }

        // ✅ Register device with FCM token
        print('\n╔════════════════════════════════════════════════════════════╗');
        print('║  📱 PHONE OTP LOGIN SUCCESS - REGISTERING DEVICE          ║');
        print('╚════════════════════════════════════════════════════════════╝');

        await _registerDeviceToken(token);

        // ✅ Initialize app services
        await AppInitializer.initializeApp();

        // ✅ Navigate to home
        Get.offAllNamed(AppRoutes.mainPage);

        _showSmallSnackbar('Welcome!', '${user['name']?.isNotEmpty == true ? user['name'] : ''}', Colors.white);
        return true;
      } else {
        String msg = response.data['message'] ?? 'Verification failed. Please try again.';
        _showSmallSnackbar('Error', msg, Colors.red);
        return false;
      }
    } on DioException catch (e) {
      isLoading.value = false;
      _isVerifyingOtp = false;

      if (e.response?.statusCode == 400) {
        _showSmallSnackbar('Error', 'Invalid OTP. Please try again.', Colors.red);
      } else {
        _showSmallSnackbar('Error', _getApiErrorMessage(e), Colors.red);
      }
      return false;
    } catch (e) {
      isLoading.value = false;
      _isVerifyingOtp = false;
      _showSmallSnackbar('Error', 'Something went wrong. Please try again.', Colors.red);
      return false;
    }
  }

  // ============================================================
  // ✅ RESEND OTP - Just call send-otp again
  // ============================================================
  Future<bool> resendPhoneOtp() async {
    if (phoneNumber.value.isEmpty) {
      _showSmallSnackbar('Error', 'No phone number found. Please try again.', Colors.red);
      return false;
    }

    // Reset OTP time first
    clearOtpTime();

    // Call send-otp again
    return await sendPhoneOtp(number: phoneNumber.value);
  }

  // ============================================================
  // ✅ FORCE DEVICE REGISTRATION
  // ============================================================
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
  // ✅ DEVICE TOKEN REGISTRATION - WITH FCM & LOCATION
  // ============================================================
  Future<bool> _registerDeviceToken(String jwtToken) async {
    if (_deviceRegistrationStarted) {
      print('⏭️ Device registration already started, skipping duplicate...');
      return false;
    }

    _deviceRegistrationStarted = true;

    try {
      final persistentDeviceId = await SharedPrefsHelper.getPermanentDeviceId();
      print('📱 Persistent Device ID for registration: $persistentDeviceId');

      // ✅ Get FCM token
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        print('📱 FCM Token: ${fcmToken?.substring(0, fcmToken!.length > 20 ? 20 : fcmToken.length)}...');
      } catch (e) {
        print('⚠️ Could not get FCM token: $e');
      }

      // ✅ Get location
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
      print('   👤 User: ${SharedPrefsHelper.getUserPhone() ?? 'Unknown'}');
      print('   📍 Location: "${currentLocation ?? "none"}"');
      print('   📱 FCM Token: ${fcmToken != null ? "Available" : "Not available"}');

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

  // ============================================================
  // ✅ FETCH LOCATION DIRECTLY
  // ============================================================
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
  // ✅ CHECK IF PROFILE IS COMPLETE (name + email)
  // ============================================================
  Future<bool> isProfileComplete() async {
    final name = SharedPrefsHelper.getUserName();
    final email = SharedPrefsHelper.getUserEmail();

    return name != null && name.isNotEmpty && email != null && email.isNotEmpty;
  }

  // ============================================================
  // ✅ GET PROFILE COMPLETENESS STATUS (for booking block)
  // ============================================================
  Future<Map<String, dynamic>> getProfileStatus() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      return {
        'isComplete': false,
        'missing': ['name', 'email'],
        'isNumberVerified': false,
      };
    }

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get(AppConfig.profile);

      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        final name = user['name'] ?? '';
        final email = user['email'] ?? '';
        final isNumberVerified = user['is_number_verified'] ?? false;

        final missing = <String>[];
        if (name.isEmpty) missing.add('name');
        if (email.isEmpty) missing.add('email');

        return {
          'isComplete': missing.isEmpty,
          'missing': missing,
          'isNumberVerified': isNumberVerified,
          'name': name,
          'email': email,
        };
      }
    } catch (e) {
      print('❌ Error getting profile status: $e');
    }

    return {
      'isComplete': false,
      'missing': ['name', 'email'],
      'isNumberVerified': false,
    };
  }

  // ============================================================
  // ✅ LOGOUT - COMPLETE CLEANUP (Token only, not device ID)
  // ============================================================
  Future<void> logout() async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  🚪 LOGGING OUT - COMPLETE CLEANUP                        ║');
    print('╚════════════════════════════════════════════════════════════╝');

    // ✅ Stop auto refresh service
    if (Get.isRegistered<AutoRefreshService>()) {
      Get.find<AutoRefreshService>().stop();
      print('✅ AutoRefreshService stopped');
    }

    // ✅ Clear device registration
    if (Get.isRegistered<DeviceManager>()) {
      final deviceManager = Get.find<DeviceManager>();
      await deviceManager.clearRegistration();
      print('✅ Device registration cleared');
    }

    // ✅ Reset AppInitializer
    AppInitializer.reset();
    print('✅ AppInitializer reset');

    // ✅ Clear caches
    if (Get.isRegistered<CacheManager>()) {
      Get.find<CacheManager>().clearAllCaches();
      print('✅ CacheManager cleared');
    } else {
      final cacheManager = CacheManager();
      cacheManager.clearAllCaches();
      print('✅ CacheManager cleared (standalone)');
    }

    // ✅ Clear SharedPreferences (except permanent device ID)
    await SharedPrefsHelper.clearAll();
    print('✅ SharedPreferences cleared (Device ID preserved)');

    // ✅ Clear view models
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

    // ✅ Unsubscribe from FCM topics
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      await FirebaseMessaging.instance.unsubscribeFromTopic('offers');
      print('✅ Unsubscribed from FCM topics');
    } catch (e) {
      print('⚠️ Could not unsubscribe from topics: $e');
    }

    // ✅ Delete FCM token (optional)
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
    _showSmallSnackbar('Success', 'Successfully logged out', Colors.white);
  }

  // ============================================================
  // ✅ HELPER METHODS
  // ============================================================

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
}