// booking_summary_view_model.dart - COMPLETE FIXED WITH PROPER DECIMAL HANDLING
// ✅ Fixed: toStringAsFixed called on String error

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/turf_model.dart';
import '../models/slot_model.dart';
import '../services/facebook_events.dart';
import '../services/notification_service.dart';
import '../services/shared_prefs_helper.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/booking_view_model.dart';
import '../view_models/main_page_view_model.dart';
import '../routes/app_routes.dart';
// 🔥 Import Facebook App Events
import 'package:book_your_turf/main.dart' show facebookAppEvents;

class BookingSummaryViewModel extends GetxController {
  late TurfModel turf;
  late List<SlotModel> selectedSlots;
  late int selectedCourt;
  late DateTime selectedDate;
  late String selectedPaymentType;
  late double totalAmount;
  late double payableAmount;
  late double minimumAdvance;

  final isLoading = false.obs;
  final isPaymentInitiated = false.obs;
  final isUILocked = false.obs;
  final paymentSuccessConfirmed = false.obs;
  final hasShownSuccessPopup = false.obs;

  late Razorpay _razorpay;
  String? _currentOrderId;
  List<Map<String, dynamic>>? _currentSlotsData;
  double? _currentTotalAmount;
  double? _currentPayableAmount;
  int? _currentTurfId;
  int? _currentCourtNumber;
  String? _currentDate;
  String? _currentPaymentType;

  bool _isProcessing = false;
  bool _paymentSuccessReceived = false;
  String? _successPaymentId;
  String? _successOrderId;

  @override
  void onInit() {
    super.onInit();
    _initRazorpay();

    final args = Get.arguments as Map<String, dynamic>;
    turf = args['turf'];
    selectedSlots = args['selectedSlots'];
    selectedCourt = args['selectedCourt'];
    selectedDate = args['selectedDate'];
    selectedPaymentType = args['selectedPaymentType'];
    totalAmount = args['totalAmount'];

    // ✅ FIX: Convert to double first, then round
    double rawPayableAmount = args['payableAmount'] is double
        ? args['payableAmount']
        : double.tryParse(args['payableAmount'].toString()) ?? 0.0;
    payableAmount = double.parse(rawPayableAmount.toStringAsFixed(2));

    // ✅ FIX: Convert to double first, then round
    double rawMinimumAdvance = args['requiredAdvance'] is double
        ? args['requiredAdvance']
        : double.tryParse(args['requiredAdvance'].toString()) ?? 0.0;
    minimumAdvance = double.parse(rawMinimumAdvance.toStringAsFixed(2));

    // 🔥 Facebook View Content Event
    _logViewContentEvent();

    print('\n=== BOOKING SUMMARY VIEW MODEL ===');
    print('Turf: ${turf.name}');
    print('Selected Payment Type: $selectedPaymentType');
    print('Total Amount: $totalAmount');
    print('Payable Amount: $payableAmount');
    print('Minimum Advance Required: $minimumAdvance');
    print('==================================\n');
  }

  // 🔥 Facebook View Content Event
  Future<void> _logViewContentEvent() async {
    try {
      await facebookAppEvents.logEvent(
        name: 'fb_mobile_view_content',
        parameters: {
          'content_type': 'turf_booking_summary',
          'content_id': turf.id.toString(),
          'content_name': turf.name,
          'content_category': turf.gameType,
          'currency': 'INR',
          'num_items': selectedSlots.length.toString(),
          'booking_type': selectedPaymentType,
        },
        valueToSum: totalAmount,
      );
      print('✅ Facebook view content event logged');
    } catch (e) {
      print('❌ Facebook view content error: $e');
    }
  }

  // ✅ Helper: Format price with proper rounding
  String _formatPrice(double price) {
    // Round to 2 decimal places first
    double roundedPrice = double.parse(price.toStringAsFixed(2));
    if (roundedPrice == roundedPrice.toInt()) {
      return roundedPrice.toInt().toString();
    }
    String formatted = roundedPrice.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  // ✅ Helper: Get properly formatted amount for API (2 decimal places)
  String _getFormattedAmount(double amount) {
    return amount.toStringAsFixed(2);
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  String get formattedDate {
    return "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  }

  List<SlotModel> get sortedSlots {
    List<SlotModel> sorted = List.from(selectedSlots);
    sorted.sort((a, b) {
      if (a.isNextDay != b.isNextDay) {
        return a.isNextDay ? 1 : -1;
      }
      return a.startTime.compareTo(b.startTime);
    });
    return sorted;
  }

  // ==================== WALLET PAYMENT - FIXED ====================
  Future<void> initiateWalletPayment() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to complete booking',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // ✅ Check token validity
    if (!SharedPrefsHelper.isTokenValid()) {
      Get.snackbar('Session Expired', 'Please login again',
          backgroundColor: Colors.red, colorText: Colors.white);
      await SharedPrefsHelper.clearToken();
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    final profileVm = Get.find<ProfileViewModel>();

    // ✅ Refresh wallet balance before checking
    await profileVm.fetchUser(forceRefresh: true);

    // ✅ Check if wallet balance is sufficient
    if (profileVm.walletBalance.value < payableAmount) {
      Get.snackbar(
        'Insufficient Balance',
        'Please recharge your wallet\nBalance: ₹${_formatPrice(profileVm.walletBalance.value)}\nRequired: ₹${_formatPrice(payableAmount)}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (isLoading.value) return;

    isLoading.value = true;
    isUILocked.value = true;

    // Store initial balance to check if payment went through
    final double initialBalance = profileVm.walletBalance.value;

    try {
      final dio = Get.find<Dio>();
      final dateStr = formattedDate;

      // ✅ Format slots data correctly with 2 decimal places
      final slotsData = selectedSlots.map((slot) => ({
        'start_time': slot.startTime,
        'end_time': slot.endTime,
        // ✅ Use priceAsDouble which is already a double
        'price': slot.priceAsDouble.toStringAsFixed(2),
      })).toList();

      // ✅ FIX: Format amounts to 2 decimal places for API
      final formattedTotalAmount = totalAmount.toStringAsFixed(2);
      final formattedPayableAmount = payableAmount.toStringAsFixed(2);

      // ✅ Prepare request body with proper field names
      final requestBody = {
        'turf_id': turf.id,
        'court_number': selectedCourt,
        'date': dateStr,
        'slots': slotsData,
        'total_amount': formattedTotalAmount,
        'amount_to_pay': formattedPayableAmount,
      };

      print('📤 Wallet Booking Request:');
      print('   turf_id: ${turf.id}');
      print('   court_number: $selectedCourt');
      print('   date: $dateStr');
      print('   slots: ${slotsData.length} slots');
      print('   total_amount: $formattedTotalAmount');
      print('   amount_to_pay: $formattedPayableAmount');

      final response = await dio.post(
        '/user/bookings/wallet-book/',
        data: requestBody,
      );

      print('📥 Wallet Booking Response Status: ${response.statusCode}');
      print('📥 Wallet Booking Response Data: ${response.data}');

      final data = response.data;
      final result = data is Map ? data['result'] : null;

      if (result == 'success') {
        _handleWalletSuccess();
      } else {
        // ✅ If failed, check if balance was deducted anyway
        await Future.delayed(const Duration(milliseconds: 500));
        await profileVm.fetchUser(forceRefresh: true);

        if (profileVm.walletBalance.value < initialBalance) {
          print('✅ Wallet payment successful - balance decreased');
          _handleWalletSuccess();
        } else {
          String errorMsg = data['message'] ?? 'Payment failed. Please try again.';
          _showWalletError(errorMsg);
        }
      }
    } on DioException catch (e) {
      print('❌ Wallet Booking Dio Error: ${e.response?.statusCode}');
      print('❌ Error Data: ${e.response?.data}');

      String errorMsg = 'Something went wrong. Please try again.';
      if (e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          errorMsg = data['message'];
        }
        // ✅ Check if it's a validation error
        if (data is Map && data['data'] != null) {
          final errorData = data['data'];
          if (errorData is Map) {
            final errors = errorData.entries.map((e) => '${e.key}: ${e.value}').join('\n');
            errorMsg = 'Validation Error:\n$errors';
          }
        }
      }

      // ✅ Check if balance was deducted despite error
      await Future.delayed(const Duration(milliseconds: 500));
      await profileVm.fetchUser(forceRefresh: true);

      if (profileVm.walletBalance.value < initialBalance) {
        print('✅ Wallet payment successful despite error - balance decreased');
        _handleWalletSuccess();
      } else {
        _showWalletError(errorMsg);
      }
    } catch (e) {
      print('❌ Wallet Booking Error: $e');

      // ✅ Check if balance was deducted despite error
      await Future.delayed(const Duration(milliseconds: 500));
      await profileVm.fetchUser(forceRefresh: true);

      if (profileVm.walletBalance.value < initialBalance) {
        print('✅ Wallet payment successful despite error - balance decreased');
        _handleWalletSuccess();
      } else {
        _showWalletError('Payment failed. Please try again.');
      }
    }
  }

  void _handleWalletSuccess() async {
    paymentSuccessConfirmed.value = true;

    if (!hasShownSuccessPopup.value) {
      hasShownSuccessPopup.value = true;
      _showWalletSuccessDialog();
    }

    // ✅ Refresh profile and bookings
    await Get.find<ProfileViewModel>().fetchUser(forceRefresh: true);
    if (Get.isRegistered<BookingViewModel>()) {
      await Get.find<BookingViewModel>().refreshBookings();
    }

    isUILocked.value = false;
    isLoading.value = false;
  }

  void _showWalletError(String message) {
    isUILocked.value = false;
    isLoading.value = false;
    Get.snackbar(
      'Payment Failed',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  void _showWalletSuccessDialog() {
    if (Get.isDialogOpen ?? false) return;

    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
              ),
              const SizedBox(height: 16),
              const Text(
                'PAYMENT SUCCESSFUL! 🎉',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              Text('Amount: ₹${_formatPrice(payableAmount)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              if (selectedPaymentType == 'advance')
                const Text(
                  'Advance payment confirmed!\nBalance to be paid at venue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                )
              else
                const Text(
                  'Your booking has been fully confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        Get.offAllNamed(AppRoutes.mainPage);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (Get.isRegistered<MainPageViewModel>()) {
                            Get.find<MainPageViewModel>().changeTab(0);
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('GO HOME', style: TextStyle(color: Colors.green)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.offAllNamed(AppRoutes.mainPage);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (Get.isRegistered<MainPageViewModel>()) {
                            Get.find<MainPageViewModel>().changeTab(1);
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('VIEW BOOKINGS', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // ==================== ONLINE PAYMENT (Razorpay) ====================
  Future<void> initiatePayment() async {
    if (_isProcessing) return;
    if (payableAmount <= 0) {
      Get.snackbar('Error', 'Invalid payment amount',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // 🔥 Facebook Add to Cart Event
    try {
      await facebookAppEvents.logEvent(
        name: 'fb_mobile_add_to_cart',
        parameters: {
          'content_type': 'turf_booking',
          'content_id': turf.id.toString(),
          'content_name': turf.name,
          'content_category': turf.gameType,
          'currency': 'INR',
          'num_items': selectedSlots.length.toString(),
          'booking_type': selectedPaymentType,
        },
        valueToSum: totalAmount,
      );
      print('✅ Facebook add to cart event logged');
    } catch (e) {
      print('❌ Facebook add to cart error: $e');
    }

    _isProcessing = true;
    isLoading.value = true;
    isUILocked.value = true;

    try {
      final dio = Get.find<Dio>();
      final dateStr = formattedDate;

      final slotsData = selectedSlots.map((slot) => ({
        'start_time': slot.startTime,
        'end_time': slot.endTime,
        'price': slot.priceAsDouble.toStringAsFixed(2),
      })).toList();

      Map<String, dynamic> requestBody = {
        'turf_id': turf.id,
        'court_number': selectedCourt,
        'date': dateStr,
        'slots': slotsData,
        'total_amount': totalAmount.toStringAsFixed(2),
      };

      if (selectedPaymentType == 'advance') {
        requestBody['advance_amount'] = payableAmount.toStringAsFixed(2);
      } else {
        requestBody['advance_amount'] = payableAmount.toStringAsFixed(2);
      }

      print('📤 Initiate Booking Request: $requestBody');

      final response = await dio.post(
        '/user/bookings/initiate/',
        data: requestBody,
      );

      print('📥 Initiate Response: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data['result'] == 'success') {
          final orderData = response.data['data'];
          _currentOrderId = orderData['razorpay_order_id'];
          _currentSlotsData = slotsData;
          _currentTotalAmount = totalAmount;
          _currentPayableAmount = payableAmount;
          _currentTurfId = turf.id;
          _currentCourtNumber = selectedCourt;
          _currentDate = dateStr;
          _currentPaymentType = selectedPaymentType;

          // 🔥 Facebook Initiate Checkout Event
          try {
            await facebookAppEvents.logEvent(
              name: 'fb_mobile_initiated_checkout',
              parameters: {
                'content_type': 'turf_booking',
                'content_id': turf.id.toString(),
                'content_name': turf.name,
                'content_category': turf.gameType,
                'currency': 'INR',
                'num_items': selectedSlots.length.toString(),
                'payment_method': 'razorpay',
                'booking_type': selectedPaymentType,
                'amount': payableAmount.toStringAsFixed(2),
              },
              valueToSum: payableAmount,
            );
            print('✅ Facebook initiate checkout event logged');
          } catch (e) {
            print('❌ Facebook initiate checkout error: $e');
          }

          isLoading.value = false;
          _openRazorpayCheckout(orderData, payableAmount);
        } else {
          String errorMsg = response.data['message'] ?? 'Failed to initiate payment';
          Get.snackbar('Error', errorMsg,
              backgroundColor: Colors.red, colorText: Colors.white);
          isLoading.value = false;
          isUILocked.value = false;
          _isProcessing = false;
        }
      } else {
        String errorMsg = 'Payment initiation failed';
        if (response.data != null && response.data['message'] != null) {
          errorMsg = response.data['message'];
        }
        Get.snackbar('Payment Error', errorMsg,
            backgroundColor: Colors.red, colorText: Colors.white);
        isLoading.value = false;
        isUILocked.value = false;
        _isProcessing = false;
      }
    } on DioException catch (e) {
      print('❌ Dio Exception: ${e.response?.data}');
      String errorMsg = 'Something went wrong. Please try again.';
      if (e.response?.data != null) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
      }
      Get.snackbar('Payment Error', errorMsg,
          backgroundColor: Colors.red, colorText: Colors.white);
      isLoading.value = false;
      isUILocked.value = false;
      _isProcessing = false;
    } catch (e) {
      print('❌ Initiate Payment Error: $e');
      Get.snackbar('Error', 'Something went wrong. Please try again.',
          backgroundColor: Colors.red, colorText: Colors.white);
      isLoading.value = false;
      isUILocked.value = false;
      _isProcessing = false;
    }
  }

  void _openRazorpayCheckout(Map<String, dynamic> orderData, double amount) {
    const String razorpayKey = 'rzp_live_Rn1hHzY0kkjXFj';

    // ✅ Round amount properly for Razorpay
    double finalAmount = double.parse(amount.toStringAsFixed(2));
    if (finalAmount < 1) finalAmount = 1.0;
    int amountInPaise = (finalAmount * 100).toInt();
    isPaymentInitiated.value = true;

    String description = selectedPaymentType == 'advance'
        ? 'Advance Payment - ₹${_formatPrice(finalAmount)}'
        : 'Full Payment - ₹${_formatPrice(finalAmount)}';

    final options = {
      'key': razorpayKey,
      'amount': amountInPaise,
      'name': 'Book Your Turf',
      'description': description,
      'order_id': orderData['razorpay_order_id'],
      'prefill': {
        'contact': SharedPrefsHelper.getUserPhone() ?? '',
        'email': SharedPrefsHelper.getUserEmail() ?? '',
      },
      'theme': {'color': '#66BB6A'},
      'modal': {
        'confirm_close': true,
        'backdrop_dismiss': false,
      },
    };

    print('🎯 Opening Razorpay: ₹${_formatPrice(finalAmount)} (${amountInPaise} paise)');
    print('🎯 Order ID: ${orderData['razorpay_order_id']}');

    try {
      _razorpay.open(options);
    } catch (e) {
      print('❌ Razorpay open error: $e');
      Get.snackbar('Error', 'Could not open payment gateway',
          backgroundColor: Colors.red, colorText: Colors.white);
      isLoading.value = false;
      isPaymentInitiated.value = false;
      isUILocked.value = false;
      _isProcessing = false;
    }
  }

  // ==================== PAYMENT SUCCESS ====================
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('=== ✅ PAYMENT SUCCESS ===');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');

    if (_paymentSuccessReceived || paymentSuccessConfirmed.value) {
      print('Payment success already processed - ignoring');
      return;
    }

    _paymentSuccessReceived = true;
    paymentSuccessConfirmed.value = true;
    _successPaymentId = response.paymentId;
    _successOrderId = response.orderId;

    // 🔥 Facebook Purchase Event
    try {
      await facebookAppEvents.logPurchase(
        amount: _currentPayableAmount ?? payableAmount,
        currency: 'INR',
        parameters: {
          'content_type': 'turf_booking',
          'content_id': _currentTurfId?.toString() ?? turf.id.toString(),
          'content_name': turf.name,
          'content_category': turf.gameType,
          'num_items': selectedSlots.length.toString(),
          'payment_method': 'razorpay',
          'booking_type': _currentPaymentType ?? selectedPaymentType,
          'payment_id': response.paymentId ?? '',
          'order_id': response.orderId ?? '',
        },
      );
      print('✅ Facebook purchase event logged');
    } catch (e) {
      print('❌ Facebook purchase event error: $e');
    }

    if (!hasShownSuccessPopup.value) {
      hasShownSuccessPopup.value = true;
      _showWalletSuccessDialog();
    }

    try {
      final dio = Get.find<Dio>();

      Map<String, dynamic> confirmData = {
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': _currentOrderId,
        'razorpay_signature': response.signature ?? '',
        'turf_id': _currentTurfId,
        'court_number': _currentCourtNumber,
        'date': _currentDate,
        'slots': _currentSlotsData,
        'total_amount': _currentTotalAmount?.toStringAsFixed(2),
      };

      if (_currentPaymentType == 'advance') {
        confirmData['advance_amount'] = _currentPayableAmount?.toStringAsFixed(2);
      } else {
        confirmData['advance_amount'] = _currentPayableAmount?.toStringAsFixed(2);
      }

      print('📤 Confirm Booking: $confirmData');
      final confirmResponse = await dio.post('/user/bookings/confirm/', data: confirmData);

      if (confirmResponse.statusCode == 200 && confirmResponse.data['result'] == 'success') {
        print('✅ Booking confirmed');
      }
    } catch (e) {
      print('⚠️ Confirmation error: $e');
    }

    // ✅ Use refreshBookings instead of fetch
    await Get.find<BookingViewModel>().refreshBookings();
    await Get.find<ProfileViewModel>().fetchUser(forceRefresh: true);

    await Future.delayed(const Duration(seconds: 2));
    if (Get.isDialogOpen ?? false) Get.back();

    isUILocked.value = false;
    Get.offAllNamed(AppRoutes.mainPage);
    Get.find<MainPageViewModel>().changeTab(1);

    isLoading.value = false;
    isPaymentInitiated.value = false;
    _isProcessing = false;
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    print('=== ❌ PAYMENT ERROR ===');
    print('Code: ${response.code}');
    print('Message: ${response.message}');

    if (_paymentSuccessReceived || paymentSuccessConfirmed.value) {
      print('Payment already successful - ignoring error');
      return;
    }

    isPaymentInitiated.value = false;
    isLoading.value = false;
    isUILocked.value = false;
    _isProcessing = false;

    if (response.code != 0) {
      Get.snackbar(
        'Payment Failed',
        response.message ?? 'Payment failed. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }
}