// view_models/wallet_view_model.dart - With Cache Management
// ✅ Small snackbar with 1-second duration at TOP

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
      _showSmallSnackbar('Login Required', 'Please login to recharge wallet', Colors.red);
      return;
    }

    if (amount < 1) {
      _showSmallSnackbar('Invalid Amount', 'Minimum recharge amount is ₹1', Colors.red);
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
        _showSmallSnackbar('Error', response.data['message'] ?? 'Failed to initiate recharge', Colors.red);
        isRecharging.value = false;
      }
    } catch (e) {
      print('Error initiating recharge: $e');
      _showSmallSnackbar('Error', 'Failed to initiate recharge. Please try again.', Colors.red);
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
      _showSmallSnackbar('Error', 'Could not open payment gateway', Colors.red);
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
        _showSmallSnackbar('Success', 'Wallet recharged successfully!', Colors.white);
      } else {
        _showSmallSnackbar('Error', confirmResponse.data['message'] ?? 'Payment confirmation failed', Colors.red);
      }
    } catch (e) {
      print('Error confirming recharge: $e');
      _showSmallSnackbar('Error', 'Failed to confirm payment. Please contact support.', Colors.red);
    } finally {
      isRecharging.value = false;
      _currentOrderId = null;
      _currentReferenceId = null;
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Wallet Recharge Error: ${response.code} - ${response.message}');

    String errorMessage = 'Please try again.';
    if (response.code == 0) {
      errorMessage = 'Payment cancelled by user';
    } else if (response.code == 1) {
      errorMessage = 'Please check your payment method.';
    }

    _showSmallSnackbar('Payment Failed', errorMessage, Colors.red);
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