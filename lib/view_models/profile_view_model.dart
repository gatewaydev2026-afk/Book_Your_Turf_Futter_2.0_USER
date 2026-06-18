// view_models/profile_view_model.dart
import 'dart:io';
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

  @override
  void onInit() {
    super.onInit();
    _checkLoginAndFetch();
  }

  Future<void> _checkLoginAndFetch() async {
    final token = SharedPrefsHelper.getToken();
    if (token != null && token.isNotEmpty) {
      await fetchUser();
    } else {
      print('User not logged in, skipping profile fetch');
    }
  }

  Future<void> fetchUser() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('User not logged in, skipping profile fetch');
      return;
    }

    isLoading.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/profile/');

      print('========== PROFILE FETCH RESPONSE ==========');
      print('Status: ${response.statusCode}');

      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        name.value = user['name'] ?? '';
        email.value = user['email'] ?? '';
        phone.value = user['number'] ?? '';
        profileImageUrl.value = user['profile_image_url'] ?? '';
        walletBalance.value = double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0;
        gameCoins.value = user['game_coins'] ?? 0;
        referralCode.value = user['referral_code'] ?? '';

        print('Wallet Balance: ${walletBalance.value}');
        print('Game Coins: ${gameCoins.value}');
        print('Referral Code: ${referralCode.value}');

        if (name.value.isNotEmpty) {
          await SharedPrefsHelper.setUserName(name.value);
        }
        await SharedPrefsHelper.setWalletBalance(walletBalance.value);
        await SharedPrefsHelper.setGameCoins(gameCoins.value);
        await SharedPrefsHelper.setReferralCode(referralCode.value);
      }
    } catch (e) {
      print('Error fetching user: $e');
      Get.snackbar('Error', 'Failed to load profile',
          backgroundColor: Colors.red,
          colorText: Colors.white
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<double> refreshWalletBalance() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('User not logged in, skipping wallet refresh');
      return walletBalance.value;
    }

    isRefreshingWallet.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/profile/');

      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        final newBalance = double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0;
        walletBalance.value = newBalance;
        gameCoins.value = user['game_coins'] ?? 0;

        await SharedPrefsHelper.setWalletBalance(newBalance);
        await SharedPrefsHelper.setGameCoins(gameCoins.value);

        print('Wallet balance refreshed: $newBalance');
        return newBalance;
      }
    } catch (e) {
      print('Error refreshing wallet balance: $e');
    } finally {
      isRefreshingWallet.value = false;
    }
    return walletBalance.value;
  }

  // NEW: Fetch coin transaction history
  Future<List<CoinTransactionModel>> fetchCoinTransactions({String? type, String? status}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      return [];
    }

    try {
      final dio = Get.find<Dio>();
      final queryParams = <String, dynamic>{};
      if (type != null && type != 'all') {
        queryParams['type'] = type;
      }
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await dio.get(
        '/user/coins/transactions/',
        queryParameters: queryParams,
      );

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => CoinTransactionModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching coin transactions: $e');
    }
    return [];
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

    print('=== UPDATING PROFILE ===');
    print('Name: $name');
    print('Has Image: ${profileImageFile != null}');

    try {
      final dio = Get.find<Dio>();
      final formData = FormData();

      if (name != null && name.isNotEmpty && name != this.name.value) {
        formData.fields.add(MapEntry('name', name));
        print('Adding name field: $name');
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
          print('Adding profile_image file: ${compressedImage.path}');
        }
      }

      if (formData.fields.isEmpty && formData.files.isEmpty) {
        print('No changes to update');
        Get.snackbar('Info', 'No changes to update',
            backgroundColor: Colors.orange, colorText: Colors.white);
        isUpdating.value = false;
        return false;
      }

      print('Sending PATCH request to /user/profile/');

      final response = await dio.patch(
        '/user/profile/',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');

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
        print('Method not allowed, trying POST with _method override');
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
    print('Using POST with method override');
    try {
      final dio = Get.find<Dio>();
      final formData = FormData();

      if (name.value.isNotEmpty) {
        formData.fields.add(MapEntry('name', name.value));
      }
      formData.fields.add(MapEntry('_method', 'PATCH'));

      final response = await dio.post(
        '/user/profile/',
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
    await fetchUser();
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
      await Get.find<HomeViewModel>().refreshTurfs();
    }
    if (Get.isRegistered<BookingViewModel>()) {
      await Get.find<BookingViewModel>().fetch();
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
      final response = await dio.post('/user/convert-coins/', data: {
        'coins_to_convert': coinsToConvert,
      });

      print('========== CONVERT COINS RESPONSE ==========');
      print('Response: ${response.data}');

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
    await fetchUser();
    imageVersion.value++;
  }

  Future<void> checkWalletBalance() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('No token found');
      return;
    }

    try {
      final dio = Get.find<Dio>();
      print('========== WALLET API TEST ==========');
      final response = await dio.get('/user/profile/');
      print('Response status: ${response.statusCode}');

      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        print('Wallet balance from API: ${user['wallet_balance']}');
        print('Game coins from API: ${user['game_coins']}');
        print('Local wallet balance: ${walletBalance.value}');

        final apiBalance = double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0;
        if (apiBalance != walletBalance.value) {
          print('Wallet balance mismatch! Updating...');
          walletBalance.value = apiBalance;
          await SharedPrefsHelper.setWalletBalance(apiBalance);
        }
      }
    } catch (e) {
      print('Wallet API test failed: $e');
    }
  }
}