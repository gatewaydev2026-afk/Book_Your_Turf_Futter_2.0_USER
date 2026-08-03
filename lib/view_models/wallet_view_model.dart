// view_models/wallet_view_model.dart - With Cache Management

import 'package:book_your_turf/config/app_config.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/wallet_transaction_model.dart';
import '../services/shared_prefs_helper.dart';
import 'profile_view_model.dart';

class WalletViewModel extends GetxController {
  final walletBalance = 0.0.obs;
  final isLoading = false.obs;
  final isRecharging = false.obs;
  final transactions = <WalletTransactionModel>[].obs;
  final filteredTransactions = <WalletTransactionModel>[].obs;
  final selectedFilter = 'all'.obs;

  late Razorpay _razorpay;
  String? _currentOrderId;
  String? _currentReferenceId;

  @override
  void onInit() {
    super.onInit();
    _initRazorpay();
    print('📋 WalletViewModel initialized (lazy loading)');

    if (Get.isRegistered<ProfileViewModel>()) {
      walletBalance.value = Get.find<ProfileViewModel>().walletBalance.value;
    }
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // ============================================================
  // ✅ LOAD WALLET DATA - SINGLE API CALL GUARANTEE
  // ============================================================

  Future<void> loadWalletData({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 No token, skipping wallet data load');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping wallet data load');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // ✅ Get CacheManager
    final cacheManager = Get.isRegistered<CacheManager>()
        ? Get.find<CacheManager>()
        : CacheManager();

    // Load balance from profile
    if (Get.isRegistered<ProfileViewModel>()) {
      final profileVm = Get.find<ProfileViewModel>();
      walletBalance.value = profileVm.walletBalance.value;
      print('✅ Wallet balance from profile: ₹${walletBalance.value}');
    }

    // ✅ Check if cache is fresh
    if (!forceRefresh && cacheManager.hasCachedWallet && cacheManager.isWalletFresh()) {
      print('⏭️ Wallet transactions cached and fresh - using cache');
      final cachedData = cacheManager.getCachedWalletTransactions();
      if (cachedData != null) {
        transactions.value = cachedData.map((json) => WalletTransactionModel.fromJson(json)).toList();
        _applyFilter();
        return;
      }
    }

    // ✅ Try to start fetch - prevents duplicate calls
    if (!cacheManager.startWalletFetch()) {
      print('⏭️ Wallet fetch already in progress - skipping duplicate');
      return;
    }

    print('📡 Fetching wallet transactions from API...');
    isLoading.value = true;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get(AppConfig.walletTransactions);

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];

        // ✅ Save to cache
        cacheManager.setCachedWalletTransactions(data);

        transactions.value = data
            .map((json) => WalletTransactionModel.fromJson(json))
            .toList();

        _applyFilter();

        print('✅ Wallet transactions fetched: ${transactions.length} transactions');
      }
    } catch (e) {
      print('❌ Error fetching wallet transactions: $e');
      // ✅ Fallback to cache on error
      if (cacheManager.hasCachedWallet) {
        print('📦 Using cached wallet transactions as fallback');
        final cachedData = cacheManager.getCachedWalletTransactions();
        if (cachedData != null) {
          transactions.value = cachedData.map((json) => WalletTransactionModel.fromJson(json)).toList();
          _applyFilter();
        }
      }
    } finally {
      isLoading.value = false;
      // ✅ FIX: startWalletFetch() only ACQUIRES the fetch lock. Re-calling it
      // here (as the old code did) never released it, so after the very first
      // fetch (success or error) the lock stayed permanently held and every
      // future loadWalletData() call silently skipped itself forever.
      cacheManager.endWalletFetch();
    }
  }

  void _applyFilter() {
    if (selectedFilter.value == 'all') {
      filteredTransactions.value = transactions;
    } else {
      filteredTransactions.value = transactions
          .where((t) => t.transactionType.toLowerCase() == selectedFilter.value)
          .toList();
    }
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilter();
  }

  // ============================================================
  // ✅ RECHARGE WALLET
  // ============================================================

  Future<void> initiateRecharge(double amount) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to recharge wallet',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (amount < 1) {
      Get.snackbar('Invalid Amount', 'Minimum recharge amount is ₹1',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    isRecharging.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        AppConfig.walletRechargeInitiate,
        data: {'amount': amount},
      );

      if (response.data['result'] == 'success') {
        final data = response.data['data'];
        _currentOrderId = data['razorpay_order_id'];
        _currentReferenceId = data['reference_id'];
        _openRazorpayCheckout(data, amount);
      } else {
        Get.snackbar('Error', response.data['message'] ?? 'Failed to initiate recharge',
            backgroundColor: Colors.red, colorText: Colors.white);
        isRecharging.value = false;
      }
    } catch (e) {
      print('Error initiating recharge: $e');
      Get.snackbar('Error', 'Failed to initiate recharge. Please try again.',
          backgroundColor: Colors.red, colorText: Colors.white);
      isRecharging.value = false;
    }
  }

  void _openRazorpayCheckout(Map<String, dynamic> orderData, double amount) {
    final options = {
      'key': AppConfig.razorpayKey,
      'amount': (amount * 100).toInt(),
      'name': 'Book Your Turf',
      'description': 'Wallet Recharge - ₹${amount.toStringAsFixed(2)}',
      'order_id': orderData['razorpay_order_id'],
      'prefill': {
        'contact': SharedPrefsHelper.getUserPhone() ?? '',
        'email': SharedPrefsHelper.getUserEmail() ?? '',
      },
      'theme': {'color': '#66BB6A'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
      Get.snackbar('Error', 'Could not open payment gateway',
          backgroundColor: Colors.red, colorText: Colors.white);
      isRecharging.value = false;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('Wallet Recharge Success - Payment ID: ${response.paymentId}');

    try {
      final dio = Get.find<Dio>();
      final confirmResponse = await dio.post(
        AppConfig.walletRechargeConfirm,
        data: {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': _currentOrderId,
        },
      );

      if (confirmResponse.data['result'] == 'success') {
        // ✅ Force refresh - clear cache
        if (Get.isRegistered<CacheManager>()) {
          Get.find<CacheManager>().clearAllCaches();
        }
        await loadWalletData(forceRefresh: true);
        if (Get.isRegistered<ProfileViewModel>()) {
          await Get.find<ProfileViewModel>().fetchUser(forceRefresh: true);
        }
        Get.snackbar('Success', 'Wallet recharged successfully!',
            backgroundColor: Colors.green, colorText: Colors.white,
            duration: const Duration(seconds: 3));
      } else {
        Get.snackbar('Error', confirmResponse.data['message'] ?? 'Payment confirmation failed',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      print('Error confirming recharge: $e');
      Get.snackbar('Error', 'Failed to confirm payment. Please contact support.',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isRecharging.value = false;
      _currentOrderId = null;
      _currentReferenceId = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Wallet Recharge Error: ${response.code} - ${response.message}');

    String errorMessage = 'Payment failed. Please try again.';
    if (response.code == 0) {
      errorMessage = 'Payment cancelled by user';
    } else if (response.code == 1) {
      errorMessage = 'Payment failed. Please check your payment method.';
    }

    Get.snackbar('Payment Failed', errorMessage,
        backgroundColor: Colors.red, colorText: Colors.white,
        duration: const Duration(seconds: 3));
    isRecharging.value = false;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }

  // ============================================================
  // ✅ REFRESH - FORCE REFRESH ON DEMAND
  // ============================================================

  Future<void> refreshWallet() async {
    if (Get.isRegistered<CacheManager>()) {
      Get.find<CacheManager>().clearAllCaches();
    }
    await loadWalletData(forceRefresh: true);
  }

  static void resetCache() {
    if (Get.isRegistered<CacheManager>()) {
      Get.find<CacheManager>().clearAllCaches();
    }
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }
}