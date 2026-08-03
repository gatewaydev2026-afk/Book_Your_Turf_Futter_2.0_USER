// view_models/profile_view_model.dart - With Cache Management
// ✅ Duplicate API call prevention
// ✅ Fixed: Static access issues

import 'dart:io';
import 'dart:async';
import 'package:book_your_turf/config/app_config.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide MultipartFile, FormData;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import '../services/shared_prefs_helper.dart';
import '../models/coin_transaction_model.dart';
import 'home_view_model.dart';
import 'booking_view_model.dart';

class ProfileViewModel extends GetxController {
  final name = ''.obs;
  final email = ''.obs;
  final phone = ''.obs;
  final profileImageUrl = ''.obs;
  final walletBalance = 0.0.obs;
  final gameCoins = 0.obs;
  final referralCode = ''.obs;
  final isLoading = false.obs;
  final isUpdating = false.obs;
  final isRefreshingWallet = false.obs;
  final imageVersion = 0.obs;

  static bool _initialFetchDone = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = AppConfig.profileCacheDuration;
  static Map<String, dynamic>? _cachedUserData;

  // ✅ DUPLICATE API CALL PREVENTION - ALL STATIC
  static bool _isFetchingProfile = false;
  static DateTime? _lastFetchCallTime;  // ✅ Made static
  static const _minFetchInterval = Duration(seconds: 3);
  // ✅ Timer cannot be static - kept as instance variable
  Timer? _refreshDebounceTimer;
  static const _refreshDebounceDuration = Duration(milliseconds: 500);

  @override
  void onInit() {
    super.onInit();
    print('📋 ProfileViewModel initialized (lazy loading)');
    _loadFromCache();
  }

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

    // ✅ FIX: Prevent duplicate calls within 3 seconds
    if (!forceRefresh && _lastFetchCallTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchCallTime!);
      if (elapsed < _minFetchInterval) {
        print('⏭️ Profile fetch skipped (${elapsed.inMilliseconds}ms since last fetch)');
        return;
      }
    }

    // ✅ FIX: Prevent concurrent fetches. Lock applies EVEN when
    // forceRefresh=true — same reasoning as BookingViewModel.loadBookings():
    // forceRefresh should only skip the freshness/cache checks below, not
    // let two overlapping forceRefresh callers both bypass the in-flight lock.
    if (_isFetchingProfile) {
      print('⏭️ Profile fetch already in progress - skipping duplicate (forceRefresh: $forceRefresh)');
      return;
    }

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

        print('✅ Profile fetched successfully');
        print('   Name: ${name.value}');
        print('   Wallet: ₹${walletBalance.value}');
        print('   Coins: ${gameCoins.value}');
      }
    } catch (e) {
      print('❌ Error fetching profile: $e');
      _loadFromCache();
    } finally {
      isLoading.value = false;
      _isFetchingProfile = false;
    }
  }

  void _updateProfileData(Map<String, dynamic> user) {
    name.value = user['name'] ?? '';
    email.value = user['email'] ?? '';
    phone.value = user['number'] ?? '';
    profileImageUrl.value = user['profile_image_url'] ?? '';
    walletBalance.value = double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0;
    gameCoins.value = user['game_coins'] ?? 0;
    referralCode.value = user['referral_code'] ?? '';

    if (name.value.isNotEmpty) {
      SharedPrefsHelper.setUserName(name.value);
    }
    SharedPrefsHelper.setWalletBalance(walletBalance.value);
    SharedPrefsHelper.setGameCoins(gameCoins.value);
    SharedPrefsHelper.setReferralCode(referralCode.value);
  }

  void _loadFromCache() {
    final cachedName = SharedPrefsHelper.getUserName();
    final cachedWallet = SharedPrefsHelper.getWalletBalance();
    final cachedCoins = SharedPrefsHelper.getGameCoins();
    final cachedReferral = SharedPrefsHelper.getReferralCode();

    if (cachedName != null && cachedName.isNotEmpty) {
      name.value = cachedName;
      walletBalance.value = cachedWallet;
      gameCoins.value = cachedCoins;
      referralCode.value = cachedReferral ?? '';

      final cachedEmail = SharedPrefsHelper.getUserEmail();
      final cachedPhone = SharedPrefsHelper.getUserPhone();
      if (cachedEmail != null) email.value = cachedEmail;
      if (cachedPhone != null) phone.value = cachedPhone;

      print('📦 Loaded profile from SharedPreferences cache');
    }
  }

  Future<double> refreshWalletBalance() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
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

        return newBalance;
      }
    } catch (e) {
      print('Error refreshing wallet: $e');
    } finally {
      isRefreshingWallet.value = false;
    }
    return walletBalance.value;
  }

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
      print('Error compressing image: $e');
      return imageFile;
    }
  }

  Future<bool> updateProfile({
    String? name,
    File? profileImageFile,
  }) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to update profile',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    isUpdating.value = true;

    try {
      final dio = Get.find<Dio>();
      final formData = FormData();

      if (name != null && name.isNotEmpty && name != this.name.value) {
        formData.fields.add(MapEntry('name', name));
      }

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

      if (formData.fields.isEmpty && formData.files.isEmpty) {
        Get.snackbar('Info', 'No changes to update',
            backgroundColor: Colors.orange, colorText: Colors.white);
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
        _showError(response.data['message'] ?? 'Update failed');
        return false;
      }

    } on DioException catch (e) {
      print('DioException: ${e.message}');
      if (e.response?.statusCode == 405) {
        return await _updateWithPostOverride();
      }
      _showError(e.response?.data['message'] ?? 'Failed to update profile');
      return false;
    } catch (e) {
      print('Error updating profile: $e');
      _showError('Failed to update profile');
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

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
        _showError(response.data['message'] ?? 'Update failed');
        return false;
      }
    } catch (e) {
      print('Error with POST override: $e');
      _showError('Failed to update profile');
      return false;
    }
  }

  Future<void> _handleUpdateSuccess() async {
    if (Get.isRegistered<CacheManager>()) {
      Get.find<CacheManager>().clearAllCaches();
    }
    await fetchUser(forceRefresh: true);
    imageVersion.value++;

    if (name.value.isNotEmpty) {
      await SharedPrefsHelper.setUserName(name.value);
    }

    await _refreshDashboard();

    Get.snackbar('Success', 'Profile updated successfully',
        backgroundColor: Colors.green, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
  }

  void _showError(String message) {
    Get.snackbar('Error', message,
        backgroundColor: Colors.red, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _refreshDashboard() async {
    if (Get.isRegistered<HomeViewModel>()) {
      await Get.find<HomeViewModel>().refreshTurfs(showLoading: true);
    }
    if (Get.isRegistered<BookingViewModel>()) {
      await Get.find<BookingViewModel>().refreshBookings();
    }
  }

  Future<bool> convertCoins(int coinsToConvert) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to convert coins',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    isLoading.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(AppConfig.convertCoins, data: {
        'coins_to_convert': coinsToConvert,
      });

      if (response.data['result'] == 'success') {
        final data = response.data['data'];
        gameCoins.value = data['game_coins'];
        walletBalance.value = double.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0;

        await SharedPrefsHelper.setGameCoins(gameCoins.value);
        await SharedPrefsHelper.setWalletBalance(walletBalance.value);

        Get.snackbar(
          'Success',
          '${response.data['message']}\nCoins: $coinsToConvert → ₹${(coinsToConvert / 10).toStringAsFixed(2)}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return true;
      } else {
        Get.snackbar('Error', response.data['message'] ?? 'Conversion failed',
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }
    } catch (e) {
      print('Error converting coins: $e');
      Get.snackbar('Error', 'Failed to convert coins',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

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

  static void resetCache() {
    _initialFetchDone = false;
    _lastFetchTime = null;
    _cachedUserData = null;
    _isFetchingProfile = false;
    _lastFetchCallTime = null;
  }

  @override
  void onClose() {
    _refreshDebounceTimer?.cancel();
    super.onClose();
  }
}