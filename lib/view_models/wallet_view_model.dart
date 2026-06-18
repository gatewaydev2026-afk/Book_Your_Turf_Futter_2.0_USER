// view_models/wallet_view_model.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/wallet_transaction_model.dart';
import '../services/notification_service.dart';
import '../services/shared_prefs_helper.dart';

class WalletViewModel extends GetxController {
  final walletBalance = 0.0.obs;
  final isLoading = false.obs;
  final isRecharging = false.obs;
  final transactions = <WalletTransactionModel>[].obs;
  final filteredTransactions = <WalletTransactionModel>[].obs;

  final selectedFilter = 'all'.obs; // all, credit, debit
  late Razorpay _razorpay;
  String? _currentOrderId;
  String? _currentReferenceId;

  @override
  void onInit() {
    super.onInit();
    _initRazorpay();
    fetchWalletBalance();
    fetchTransactions();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> fetchWalletBalance() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('No token found for wallet balance');
      return;
    }

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/profile/');
      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        walletBalance.value = double.tryParse(user['wallet_balance']?.toString() ?? '0') ?? 0;
        print('Wallet balance fetched: ${walletBalance.value}');
      }
    } catch (e) {
      print('Error fetching wallet balance: $e');
    }
  }

  Future<void> fetchTransactions({String? type, String? status}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('No token found for wallet transactions');
      return;
    }

    isLoading.value = true;
    print('Fetching wallet transactions...');

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
        '/user/wallet/transactions/',
        queryParameters: queryParams,
      );

      print('Wallet transactions response: ${response.data}');

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];
        print('Wallet transactions count: ${data.length}');

        // Print first transaction for debugging
        if (data.isNotEmpty) {
          print('First transaction: ${data[0]}');
        }

        transactions.value = data
            .map((json) => WalletTransactionModel.fromJson(json))
            .toList();
        _applyFilter();
      } else {
        print('Failed to fetch wallet transactions: ${response.data['message']}');
      }
    } catch (e) {
      print('Error fetching wallet transactions: $e');
      if (e is DioException) {
        print('Dio error response: ${e.response?.data}');
        print('Dio error status: ${e.response?.statusCode}');
      }
    } finally {
      isLoading.value = false;
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
    print('Filtered transactions: ${filteredTransactions.length}');
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilter();
  }

  // FIXED: Minimum recharge amount changed from ₹10 to ₹1
  Future<void> initiateRecharge(double amount) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to recharge wallet',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Changed from amount < 10 to amount < 1
    if (amount < 1) {
      Get.snackbar('Invalid Amount', 'Minimum recharge amount is ₹1',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    isRecharging.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        '/user/wallet/recharge/initiate/',
        data: {'amount': amount},
      );

      print('Recharge initiate response: ${response.data}');

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
    const String razorpayKey = 'rzp_live_Rn1hHzY0kkjXFj';
    int amountInPaise = (amount * 100).toInt();

    final options = {
      'key': razorpayKey,
      'amount': amountInPaise,
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

// lib/view_models/wallet_view_model.dart


  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('Wallet Recharge Success - Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');

    try {
      final dio = Get.find<Dio>();
      final confirmResponse = await dio.post(
        '/user/wallet/recharge/confirm/',
        data: {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': _currentOrderId,
        },
      );

      print('Recharge confirm response: ${confirmResponse.data}');

      if (confirmResponse.data['result'] == 'success') {
        await fetchWalletBalance();
        await fetchTransactions();
        Get.snackbar(
          'Success',
          'Wallet recharged successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Error',
          confirmResponse.data['message'] ?? 'Payment confirmation failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error confirming recharge: $e');
      Get.snackbar(
        'Error',
        'Failed to confirm payment. Please contact support.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
    } else if (response.code == 2) {
      errorMessage = 'Payment failed. Please try again.';
    }

    Get.snackbar(
      'Payment Failed',
      errorMessage,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
    isRecharging.value = false;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }

  Future<void> refresh() async {
    await fetchWalletBalance();
    await fetchTransactions();
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }
}