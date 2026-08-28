// view_models/profile_view_model.dart - Complete with Phone OTP Support
// ✅ Added isNumberVerified, isNewUser, isPhoneAuthUser, profileComplete
// ✅ Duplicate API call prevention
// ✅ Cache management
// ✅ Small snackbar with 1-second duration at TOP
// ✅ REMOVED image_picker dependency (no longer needed)

import 'dart:io';
import 'dart:async';
import 'package:book_your_turf/config/app_config.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide MultipartFile, FormData;
import 'package:dio/dio.dart';
// ❌ import 'package:image_picker/image_picker.dart';  // REMOVED - No longer needed
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import '../services/shared_prefs_helper.dart';
import '../models/coin_transaction_model.dart';
import 'home_view_model.dart';
import 'booking_view_model.dart';

class ProfileViewModel extends GetxController {
  // ============================================================
  // 📊 USER DATA OBSERVABLES
  // ============================================================
  final name = ''.obs;
  final email = ''.obs;
  final phone = ''.obs;
  final profileImageUrl = ''.obs;
  final walletBalance = 0.0.obs;
  final gameCoins = 0.obs;
  final referralCode = ''.obs;

  // ✅ Phone Auth specific observables
  final isNumberVerified = false.obs;
  final isNewUser = true.obs;
  final isPhoneAuthUser = false.obs;
  final profileComplete = false.obs;

  // ============================================================
  // 📊 UI STATE OBSERVABLES
  // ============================================================
  final isLoading = false.obs;
  final isUpdating = false.obs;
  final isRefreshingWallet = false.obs;
  final imageVersion = 0.obs;

  // ============================================================
  // 🔒 STATIC CACHE & DUPLICATE PREVENTION
  // ============================================================
  static bool _initialFetchDone = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = AppConfig.profileCacheDuration;
  static Map<String, dynamic>? _cachedUserData;

  // ✅ DUPLICATE API CALL PREVENTION
  static bool _isFetchingProfile = false;
  static DateTime? _lastFetchCallTime;
  static const _minFetchInterval = Duration(seconds: 3);
  Timer? _refreshDebounceTimer;
  static const _refreshDebounceDuration = Duration(milliseconds: 500);

  // ============================================================
  // 🏗️ LIFECYCLE
  // ============================================================
  @override
  void onInit() {
    super.onInit();
    print('📋 ProfileViewModel initialized (lazy loading)');
    _loadFromCache();
  }

  @override
  void onClose() {
    _refreshDebounceTimer?.cancel();
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
      colorText: Colors.white,
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

  // ============================================================
  // 📡 FETCH USER PROFILE
  // ============================================================
  Future<void> fetchUser({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 No token, skipping profile fetch');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping profile fetch');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // ✅ Prevent duplicate calls within 3 seconds
    if (!forceRefresh && _lastFetchCallTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchCallTime!);
      if (elapsed < _minFetchInterval) {
        print('⏭️ Profile fetch skipped (${elapsed.inMilliseconds}ms since last fetch)');
        return;
      }
    }

    // ✅ Prevent concurrent fetches
    if (_isFetchingProfile) {
      print('⏭️ Profile fetch already in progress - skipping duplicate');
      return;
    }

    // ✅ Cache check
    if (!forceRefresh && _initialFetchDone && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration) {
        print('⏭️ Profile data cached (${age.inSeconds}s old) - skipping fetch');
        return;
      }
    }

    if (!forceRefresh && _initialFetchDone && name.value.isNotEmpty) {
      print('⏭️ Profile data already loaded');
      return;
    }

    _isFetchingProfile = true;
    print('📡 Fetching profile from API...');
    isLoading.value = true;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get(AppConfig.profile);

      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        _cachedUserData = user;
        _updateProfileData(user);

        _initialFetchDone = true;
        _lastFetchTime = DateTime.now();
        _lastFetchCallTime = DateTime.now();
        await SharedPrefsHelper.setLastProfileFetch(DateTime.now());

        // ✅ Update cache manager
        if (Get.isRegistered<CacheManager>()) {
          Get.find<CacheManager>().setCachedProfile(user);
        }

        print('✅ Profile fetched successfully');
        print('   Name: ${name.value}');
        print('   Email: ${email.value}');
        print('   Phone: ${phone.value}');
        print('   Verified: ${isNumberVerified.value}');
        print('   New User: ${isNewUser.value}');
        print('   Profile Complete: ${profileComplete.value}');
        print('   Wallet: ₹${walletBalance.value}');
        print('   Coins: ${gameCoins.value}');
      } else {
        print('❌ API returned error: ${response.data['message']}');
        _loadFromCache();
      }
    } catch (e) {
      print('❌ Error fetching profile: $e');
      _loadFromCache();
    } finally {
      isLoading.value = false;
      _isFetchingProfile = false;
    }
  }

  // ============================================================
  // 📦 UPDATE PROFILE DATA
  // ============================================================
  void _updateProfileData(Map<String, dynamic> user) {
    // ✅ Basic user data
    name.value = user['name'] ?? '';
    email.value = user['email'] ?? '';
    phone.value = user['number'] ?? '';
    profileImageUrl.value = user['profile_image_url'] ?? '';
    walletBalance.value = double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0;
    gameCoins.value = user['game_coins'] ?? 0;
    referralCode.value = user['referral_code'] ?? '';

    // ✅ Phone Auth specific fields
    isNumberVerified.value = user['is_number_verified'] ?? false;
    isNewUser.value = user['is_new_user'] ?? false;
    isPhoneAuthUser.value = SharedPrefsHelper.getIsPhoneAuthUser();
    profileComplete.value = user['name']?.isNotEmpty == true && user['email']?.isNotEmpty == true;

    // ✅ Save to SharedPreferences
    if (name.value.isNotEmpty) {
      SharedPrefsHelper.setUserName(name.value);
    }
    if (email.value.isNotEmpty) {
      SharedPrefsHelper.setUserEmail(email.value);
    }
    if (phone.value.isNotEmpty) {
      SharedPrefsHelper.setUserPhone(phone.value);
    }
    SharedPrefsHelper.setWalletBalance(walletBalance.value);
    SharedPrefsHelper.setGameCoins(gameCoins.value);
    SharedPrefsHelper.setReferralCode(referralCode.value);

    // ✅ Save phone auth flags
    SharedPrefsHelper.setIsNumberVerified(isNumberVerified.value);
    SharedPrefsHelper.setIsNewUser(isNewUser.value);
    SharedPrefsHelper.setProfileComplete(profileComplete.value);
  }

  // ============================================================
  // 📦 LOAD FROM CACHE
  // ============================================================
  void _loadFromCache() {
    final cachedName = SharedPrefsHelper.getUserName();
    final cachedWallet = SharedPrefsHelper.getWalletBalance();
    final cachedCoins = SharedPrefsHelper.getGameCoins();
    final cachedReferral = SharedPrefsHelper.getReferralCode();
    final cachedEmail = SharedPrefsHelper.getUserEmail();
    final cachedPhone = SharedPrefsHelper.getUserPhone();

    // ✅ Load phone auth flags from cache
    isNumberVerified.value = SharedPrefsHelper.getIsNumberVerified();
    isNewUser.value = SharedPrefsHelper.getIsNewUser();
    isPhoneAuthUser.value = SharedPrefsHelper.getIsPhoneAuthUser();
    profileComplete.value = SharedPrefsHelper.getProfileComplete();

    if (cachedName != null && cachedName.isNotEmpty) {
      name.value = cachedName;
      walletBalance.value = cachedWallet;
      gameCoins.value = cachedCoins;
      referralCode.value = cachedReferral ?? '';
      if (cachedEmail != null) email.value = cachedEmail;
      if (cachedPhone != null) phone.value = cachedPhone;

      print('📦 Loaded profile from SharedPreferences cache');
      print('   Name: ${name.value}');
      print('   Email: ${email.value}');
      print('   Phone: ${phone.value}');
      print('   Verified: ${isNumberVerified.value}');
      print('   Profile Complete: ${profileComplete.value}');
    } else {
      print('📭 No cached profile data found');
    }
  }

  // ============================================================
  // ✅ PROFILE COMPLETENESS CHECK (For Booking Block)
  // ============================================================
  bool get isProfileCompleteForBooking {
    return name.value.isNotEmpty && email.value.isNotEmpty;
  }

  List<String> getMissingFields() {
    final missing = <String>[];
    if (name.value.isEmpty) missing.add('name');
    if (email.value.isEmpty) missing.add('email');
    return missing;
  }

  // ============================================================
  // ✅ UPDATE PROFILE FOR BOOKING (Name + Email only)
  // ============================================================
  Future<bool> updateProfileForBooking({
    required String name,
    required String email,
  }) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    if (name.isEmpty || email.isEmpty) {
      return false;
    }

    // ✅ Prevent duplicate calls
    if (isUpdating.value) {
      print('⏭️ Profile update already in progress');
      return false;
    }

    isUpdating.value = true;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.patch(
        AppConfig.profileUpdate,
        data: {
          'name': name.trim(),
          'email': email.trim(),
        },
      );

      if (response.data['result'] == 'success') {
        // ✅ Update local values directly without extra API call
        this.name.value = name.trim();
        this.email.value = email.trim();
        profileComplete.value = true;

        // ✅ Save to SharedPreferences
        await SharedPrefsHelper.setUserName(name.trim());
        await SharedPrefsHelper.setUserEmail(email.trim());
        await SharedPrefsHelper.setProfileComplete(true);

        print('✅ Profile updated successfully for booking');
        return true;
      } else {
        print('❌ Profile update failed: ${response.data['message']}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

  // ============================================================
  // 💰 WALLET BALANCE REFRESH
  // ============================================================
  Future<double> refreshWalletBalance() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      return walletBalance.value;
    }

    if (isRefreshingWallet.value) {
      print('⏭️ Wallet refresh already in progress');
      return walletBalance.value;
    }

    isRefreshingWallet.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.get(AppConfig.profile);

      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        final newBalance = double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0;
        walletBalance.value = newBalance;
        gameCoins.value = user['game_coins'] ?? 0;

        await SharedPrefsHelper.setWalletBalance(newBalance);
        await SharedPrefsHelper.setGameCoins(gameCoins.value);

        print('✅ Wallet balance refreshed: ₹${walletBalance.value}');
        return newBalance;
      }
    } catch (e) {
      print('❌ Error refreshing wallet: $e');
    } finally {
      isRefreshingWallet.value = false;
    }
    return walletBalance.value;
  }

  // ============================================================
  // 🖼️ IMAGE COMPRESSION
  // ============================================================
  Future<File?> compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final sizeInKB = bytes.lengthInBytes / 1024;
      print('Original image size: ${sizeInKB.toStringAsFixed(2)} KB');

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 500,
        minHeight: 500,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final compressedFile = File(
            '${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg'
        );
        await compressedFile.writeAsBytes(compressedBytes);

        final compressedSize = compressedBytes.lengthInBytes / 1024;
        print('Compressed image size: ${compressedSize.toStringAsFixed(2)} KB');
        return compressedFile;
      }
      return imageFile;
    } catch (e) {
      print('❌ Error compressing image: $e');
      return imageFile;
    }
  }

  // ============================================================
  // 📤 UPDATE FULL PROFILE (Name + Image)
  // ============================================================
  Future<bool> updateProfile({
    String? name,
    File? profileImageFile,
  }) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      _showSmallSnackbar('Login Required', 'Please login to update profile', Colors.orange);
      return false;
    }

    isUpdating.value = true;

    try {
      final dio = Get.find<Dio>();
      final formData = FormData();

      // ✅ Add name if provided and different
      if (name != null && name.isNotEmpty && name != this.name.value) {
        formData.fields.add(MapEntry('name', name));
      }

      // ✅ Add profile image if provided
      if (profileImageFile != null) {
        final compressedImage = await compressImage(profileImageFile);
        if (compressedImage != null) {
          final multipartFile = await MultipartFile.fromFile(
            compressedImage.path,
            filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
            contentType: MediaType('image', 'jpeg'),
          );
          formData.files.add(MapEntry('profile_image', multipartFile));
        }
      }

      // ✅ Check if there's anything to update
      if (formData.fields.isEmpty && formData.files.isEmpty) {
        _showSmallSnackbar('Info', 'No changes to update', Colors.orange);
        isUpdating.value = false;
        return false;
      }

      final response = await dio.patch(
        AppConfig.profileUpdate,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.data['result'] == 'success') {
        await _handleUpdateSuccess();
        return true;
      } else {
        _showSmallSnackbar('Error', response.data['message'] ?? 'Update failed', Colors.red);
        return false;
      }

    } on DioException catch (e) {
      print('❌ DioException: ${e.message}');
      if (e.response?.statusCode == 405) {
        return await _updateWithPostOverride();
      }
      _showSmallSnackbar('Error', e.response?.data['message'] ?? 'Failed to update profile', Colors.red);
      return false;
    } catch (e) {
      print('❌ Error updating profile: $e');
      _showSmallSnackbar('Error', 'Failed to update profile', Colors.red);
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

  // ============================================================
  // 🔄 POST OVERRIDE (For PATCH not supported)
  // ============================================================
  Future<bool> _updateWithPostOverride() async {
    try {
      final dio = Get.find<Dio>();
      final formData = FormData();

      if (name.value.isNotEmpty) {
        formData.fields.add(MapEntry('name', name.value));
      }
      formData.fields.add(MapEntry('_method', 'PATCH'));

      final response = await dio.post(
        AppConfig.profileUpdate,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.data['result'] == 'success') {
        await _handleUpdateSuccess();
        return true;
      } else {
        _showSmallSnackbar('Error', response.data['message'] ?? 'Update failed', Colors.red);
        return false;
      }
    } catch (e) {
      print('❌ Error with POST override: $e');
      _showSmallSnackbar('Error', 'Failed to update profile', Colors.red);
      return false;
    }
  }

  // ============================================================
  // ✅ HANDLE UPDATE SUCCESS
  // ============================================================
  Future<void> _handleUpdateSuccess() async {
    // ✅ Clear cache
    if (Get.isRegistered<CacheManager>()) {
      Get.find<CacheManager>().clearAllCaches();
    }

    // ✅ Refresh profile data
    await fetchUser(forceRefresh: true);
    imageVersion.value++;

    // ✅ Save name to SharedPreferences
    if (name.value.isNotEmpty) {
      await SharedPrefsHelper.setUserName(name.value);
    }

    // ✅ Refresh dashboard data
    await _refreshDashboard();

    _showSmallSnackbar('Success', 'Profile updated successfully', Colors.black);
  }

  // ============================================================
  // 🔄 REFRESH DASHBOARD
  // ============================================================
  Future<void> _refreshDashboard() async {
    if (Get.isRegistered<HomeViewModel>()) {
      await Get.find<HomeViewModel>().refreshTurfs(showLoading: true);
    }
    if (Get.isRegistered<BookingViewModel>()) {
      await Get.find<BookingViewModel>().refreshBookings();
    }
  }

  // ============================================================
  // 🪙 CONVERT COINS
  // ============================================================
  Future<bool> convertCoins(int coinsToConvert) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      _showSmallSnackbar('Login Required', 'Please login to convert coins', Colors.orange);
      return false;
    }

    if (coinsToConvert < 200) {
      _showSmallSnackbar('Error', 'Minimum 200 coins required', Colors.red);
      return false;
    }

    isLoading.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        AppConfig.convertCoins,
        data: {
          'coins_to_convert': coinsToConvert,
        },
      );

      if (response.data['result'] == 'success') {
        final data = response.data['data'];
        gameCoins.value = data['game_coins'];
        walletBalance.value = double.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0;

        await SharedPrefsHelper.setGameCoins(gameCoins.value);
        await SharedPrefsHelper.setWalletBalance(walletBalance.value);

        _showSmallSnackbar('Success', 'Coins: $coinsToConvert → ₹${(coinsToConvert / 10).toStringAsFixed(2)}', Colors.black);
        return true;
      } else {
        _showSmallSnackbar('Error', response.data['message'] ?? 'Conversion failed', Colors.red);
        return false;
      }
    } catch (e) {
      print('❌ Error converting coins: $e');
      _showSmallSnackbar('Error', 'Failed to convert coins', Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ============================================================
  // 🔄 REFRESH PROFILE
  // ============================================================
  Future<void> refresh() async {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(_refreshDebounceDuration, () async {
      _initialFetchDone = false;
      if (Get.isRegistered<CacheManager>()) {
        Get.find<CacheManager>().clearAllCaches();
      }
      await fetchUser(forceRefresh: true);
      imageVersion.value++;
    });
  }

  // ============================================================
  // 🔄 RESET CACHE
  // ============================================================
  static void resetCache() {
    _initialFetchDone = false;
    _lastFetchTime = null;
    _cachedUserData = null;
    _isFetchingProfile = false;
    _lastFetchCallTime = null;
    print('🔄 Profile cache reset');
  }

  // ============================================================
  // 📊 GETTERS
  // ============================================================
  bool get hasProfileData => name.value.isNotEmpty || email.value.isNotEmpty;
  String get displayName => name.value.isNotEmpty ? name.value : 'User';
  String get displayPhone => phone.value.isNotEmpty ? phone.value : 'Not set';
  String get displayEmail => email.value.isNotEmpty ? email.value : 'Not set';
}