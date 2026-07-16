// lib/view_models/booking_summary_view_model.dart
// ✅ Complete as per API documentation
// ✅ Full Payment Discount Support

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/turf_model.dart';
import '../models/slot_model.dart';
import '../models/discount_model.dart';
import '../services/price_formatter.dart';
import '../view_models/discount_view_model.dart';
import '../services/facebook_events.dart';
import '../services/notification_service.dart';
import '../services/shared_prefs_helper.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/booking_view_model.dart';
import '../view_models/main_page_view_model.dart';
import '../routes/app_routes.dart';
import 'package:book_your_turf/main.dart' show facebookAppEvents;

class RazorpayConfig {
  static const String key = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_live_Rn1hHzY0kkjXFj',
  );
}

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

  final DiscountViewModel discountVm = Get.find<DiscountViewModel>();
  final isLoadingDiscounts = false.obs;
  final discountedTotal = 0.0.obs;
  final discountedAdvanceAmount = 0.0.obs;

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

    selectedPaymentType = (args['selectedPaymentType'] ?? 'full')
        .toString()
        .trim()
        .toLowerCase();
    totalAmount = args['totalAmount'];

    double rawPayableAmount = args['payableAmount'] is double
        ? args['payableAmount']
        : double.tryParse(args['payableAmount'].toString()) ?? 0.0;
    payableAmount = double.parse(rawPayableAmount.toStringAsFixed(2));

    double rawMinimumAdvance = args['requiredAdvance'] is double
        ? args['requiredAdvance']
        : double.tryParse(args['requiredAdvance'].toString()) ?? 0.0;
    minimumAdvance = double.parse(rawMinimumAdvance.toStringAsFixed(2));

    discountedTotal.value = totalAmount;
    discountedAdvanceAmount.value = payableAmount;

    _logViewContentEvent();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadDiscounts(forceRefresh: true);
    });

    print('\n=== BOOKING SUMMARY VIEW MODEL ===');
    print('Turf: ${turf.name}');
    print('Selected Payment Type: $selectedPaymentType');
    print('Total Amount: $totalAmount');
    print('Payable Amount: $payableAmount');
    print('Minimum Advance Required: $minimumAdvance');
    print('==================================\n');
  }

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

  Future<void> loadDiscounts({bool forceRefresh = false}) async {
    if (selectedSlots.isEmpty) return;

    isLoadingDiscounts.value = true;

    try {
      await discountVm.fetchApplicableDiscounts(
        turfId: turf.id,
        date: selectedDate,
        slots: selectedSlots,
        totalAmount: totalAmount,
        forceRefresh: forceRefresh,
      );

      discountVm.clearAllSelections();
      discountedTotal.value = totalAmount;
      discountedAdvanceAmount.value = payableAmount;

      final adminCount = discountVm.adminDiscounts.length;
      final partnerCount = discountVm.partnerDiscounts.length;

      if (adminCount > 0 || partnerCount > 0) {
        print('✅ $adminCount admin discounts and $partnerCount partner discounts available');
        print('   ⚠️ User must tap to select');
      }

    } catch (e) {
      print('Error loading discounts: $e');
    } finally {
      isLoadingDiscounts.value = false;
    }
  }

  void toggleAdminDiscount(int discountId) {
    discountVm.toggleAdminDiscount(discountId);
    _updateDiscountedAmounts();
    _logDiscountApplied();
  }

  void togglePartnerDiscount(int discountId) {
    discountVm.togglePartnerDiscount(discountId);
    _updateDiscountedAmounts();
    _logDiscountApplied();
  }

  void _updateDiscountedAmounts() {
    final overallDiscount = discountVm.overallDiscountAmount;
    final payableDiscount = discountVm.payableDiscountAmount;

    print('========================================');
    print('✅ DISCOUNT CALCULATION:');
    print('   Overall Discount: ₹${overallDiscount.toStringAsFixed(2)}');
    print('   Payable Discount: ₹${payableDiscount.toStringAsFixed(2)}');
    print('   Total Amount: ₹$totalAmount');
    print('   Payable Amount (Original): ₹$payableAmount');
    print('   Payment Type: $selectedPaymentType');

    discountedTotal.value = totalAmount - overallDiscount;
    if (discountedTotal.value < 0) {
      discountedTotal.value = 0;
    }

    if (selectedPaymentType == 'full') {
      double discountedFullTotal = totalAmount - overallDiscount - payableDiscount;
      if (discountedFullTotal < 0) {
        discountedFullTotal = 0;
      }
      discountedTotal.value = discountedFullTotal;
      discountedAdvanceAmount.value = payableAmount;

      print('   Discounted Total (Full Payment): ₹${discountedTotal.value}');
      print('   (Overall Discount: ₹$overallDiscount + Payable Discount: ₹$payableDiscount)');
    } else {
      double discountedAdvance = payableAmount - overallDiscount - payableDiscount;
      if (discountedAdvance < 0) {
        discountedAdvance = 0;
      }
      discountedAdvanceAmount.value = discountedAdvance;

      print('   Original Advance: ₹$payableAmount');
      print('   Discounted Advance: ₹${discountedAdvanceAmount.value}');
      print('   (Overall Discount: ₹$overallDiscount + Payable Discount: ₹$payableDiscount)');
      print('   Discounted Total: ₹${discountedTotal.value}');
    }
    print('========================================');
  }

  void _logDiscountApplied() {
    if (!discountVm.hasSelectedDiscount) return;

    try {
      facebookAppEvents.logEvent(
        name: 'discount_applied',
        parameters: {
          'admin_discount_id': discountVm.selectedAdminDiscountId.value?.toString() ?? '',
          'partner_discount_id': discountVm.selectedPartnerDiscountId.value?.toString() ?? '',
          'total_discount': discountVm.totalDiscountAmount.toString(),
          'payment_type': selectedPaymentType,
          'turf_id': turf.id.toString(),
        },
      );
      print('✅ Discount usage logged to Facebook');
    } catch (e) {
      print('❌ Error logging discount: $e');
    }
  }

  void removeAllDiscounts() {
    discountVm.clearAllSelections();
    discountedTotal.value = totalAmount;
    discountedAdvanceAmount.value = payableAmount;
    print('✅ All discounts removed');
  }

  String _formatPrice(double price) => PriceFormatter.format(price);

  String _getFormattedAmount(double amount) {
    if (amount < 0) return '0.00';
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

  Future<void> initiateWalletPayment() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to complete booking',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      Get.snackbar('Session Expired', 'Please login again',
          backgroundColor: Colors.red, colorText: Colors.white);
      await SharedPrefsHelper.clearToken();
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    final profileVm = Get.find<ProfileViewModel>();
    await profileVm.fetchUser(forceRefresh: true);

    final amountToPay = _getAmountToPay();

    if (amountToPay <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Amount cannot be zero or negative. Please adjust.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (profileVm.walletBalance.value < amountToPay) {
      Get.snackbar(
        'Insufficient Balance',
        'Please recharge your wallet\nBalance: ₹${_formatPrice(profileVm.walletBalance.value)}\nRequired: ₹${_formatPrice(amountToPay)}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    if (isLoading.value) return;

    isLoading.value = true;
    isUILocked.value = true;

    final double initialBalance = profileVm.walletBalance.value;

    try {
      final dio = Get.find<Dio>();
      final dateStr = formattedDate;

      final slotsData = selectedSlots.map((slot) => ({
        'start_time': slot.startTime,
        'end_time': slot.endTime,
        'price': slot.priceAsDouble.toStringAsFixed(2),
      })).toList();

      final requestBody = {
        'turf_id': turf.id,
        'court_number': selectedCourt,
        'date': dateStr,
        'slots': slotsData,
        'total_amount': totalAmount.toStringAsFixed(2),
        'amount_to_pay': _getFormattedAmount(amountToPay),
      };

      if (discountVm.selectedAdminDiscountId.value != null) {
        requestBody['admin_discount_id'] = discountVm.selectedAdminDiscountId.value!;
      }
      if (discountVm.selectedPartnerDiscountId.value != null) {
        requestBody['partner_discount_id'] = discountVm.selectedPartnerDiscountId.value!;
      }

      print('📤 Wallet Booking Request: $requestBody');
      print('   Payment Type: $selectedPaymentType');
      print('   Amount to Pay: $amountToPay');

      final response = await dio.post(
        '/user/bookings/wallet-book/',
        data: requestBody,
      );

      print('📥 Wallet Booking Response: ${response.data}');

      final data = response.data;
      final result = data is Map ? data['result'] : null;

      if (result == 'success') {
        _handleWalletSuccess();
      } else {
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
      print('❌ Wallet Booking Error: ${e.response?.data}');
      String errorMsg = 'Something went wrong. Please try again.';
      if (e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          errorMsg = data['message'];
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await profileVm.fetchUser(forceRefresh: true);

      if (profileVm.walletBalance.value < initialBalance) {
        print('✅ Wallet payment successful despite error');
        _handleWalletSuccess();
      } else {
        _showWalletError(errorMsg);
      }
    } catch (e) {
      print('❌ Wallet Booking Error: $e');
      await Future.delayed(const Duration(milliseconds: 500));
      await profileVm.fetchUser(forceRefresh: true);

      if (profileVm.walletBalance.value < initialBalance) {
        print('✅ Wallet payment successful despite error');
        _handleWalletSuccess();
      } else {
        _showWalletError('Payment failed. Please try again.');
      }
    }
  }

  double _getAmountToPay() {
    if (selectedPaymentType == 'advance') {
      if (discountVm.hasSelectedDiscount && discountedAdvanceAmount.value < payableAmount) {
        return discountedAdvanceAmount.value;
      }
      return payableAmount;
    } else {
      if (discountVm.hasSelectedDiscount && discountedTotal.value < totalAmount) {
        return discountedTotal.value;
      }
      return payableAmount;
    }
  }

  void _handleWalletSuccess() async {
    paymentSuccessConfirmed.value = true;

    if (!hasShownSuccessPopup.value) {
      hasShownSuccessPopup.value = true;
      _showWalletSuccessDialog();
    }

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

    final amountPaid = _getAmountToPay();

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
              Text('Amount: ₹${_formatPrice(amountPaid)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              if (discountVm.hasSelectedDiscount)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Total Discount: ₹${_formatPrice(discountVm.totalDiscountAmount)}',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                  ),
                ),
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

  Future<void> initiatePayment() async {
    if (_isProcessing) return;

    final amountToPay = _getAmountToPay();

    if (amountToPay <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Amount cannot be zero or negative. Please adjust.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
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
        'advance_amount': _getFormattedAmount(amountToPay),
      };

      if (discountVm.selectedAdminDiscountId.value != null) {
        requestBody['admin_discount_id'] = discountVm.selectedAdminDiscountId.value;
      }
      if (discountVm.selectedPartnerDiscountId.value != null) {
        requestBody['partner_discount_id'] = discountVm.selectedPartnerDiscountId.value;
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
          _currentPayableAmount = amountToPay;
          _currentTurfId = turf.id;
          _currentCourtNumber = selectedCourt;
          _currentDate = dateStr;
          _currentPaymentType = selectedPaymentType;

          isLoading.value = false;
          _openRazorpayCheckout(orderData, amountToPay);
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
    const String razorpayKey = RazorpayConfig.key;

    double finalAmount = double.parse(amount.toStringAsFixed(2));
    if (finalAmount < 1) finalAmount = 1.0;
    int amountInPaise = (finalAmount * 100).toInt();
    isPaymentInitiated.value = true;

    String description = selectedPaymentType == 'advance'
        ? 'Advance Payment - ₹${_formatPrice(finalAmount)}'
        : 'Full Payment - ₹${_formatPrice(finalAmount)}';

    if (discountVm.hasSelectedDiscount) {
      description += ' (Discount Applied)';
    }

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

    final amountPaid = _currentPayableAmount ?? _getAmountToPay();

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
        'advance_amount': _currentPayableAmount?.toStringAsFixed(2),
      };

      if (discountVm.selectedAdminDiscountId.value != null) {
        confirmData['admin_discount_id'] = discountVm.selectedAdminDiscountId.value;
      }
      if (discountVm.selectedPartnerDiscountId.value != null) {
        confirmData['partner_discount_id'] = discountVm.selectedPartnerDiscountId.value;
      }

      print('📤 Confirm Booking: $confirmData');
      final confirmResponse = await dio.post('/user/bookings/confirm/', data: confirmData);

      if (confirmResponse.statusCode == 200 && confirmResponse.data['result'] == 'success') {
        print('✅ Booking confirmed');
      }
    } catch (e) {
      print('⚠️ Confirmation error: $e');
    }

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

  double get walletAmountToPay => _getAmountToPay();
  double get razorpayAmountToPay => _getAmountToPay();

  bool get isDiscountApplied {
    return discountVm.hasSelectedDiscount && discountVm.totalDiscountAmount > 0;
  }

  String get discountDisplayText {
    if (!discountVm.hasSelectedDiscount) return '';

    final admin = discountVm.selectedAdminDiscount;
    final partner = discountVm.selectedPartnerDiscount;
    final parts = <String>[];
    if (admin != null) parts.add('${admin.getDisplayText()} (Platform)');
    if (partner != null) parts.add('${partner.getDisplayText()} (Venue)');
    return parts.join(' + ');
  }

  String get discountAmountText {
    if (!discountVm.hasSelectedDiscount) return '';
    return '₹${_formatPrice(discountVm.totalDiscountAmount)}';
  }

  bool isAdminDiscountSelected(int discountId) {
    return discountVm.selectedAdminDiscountId.value == discountId;
  }

  bool isPartnerDiscountSelected(int discountId) {
    return discountVm.selectedPartnerDiscountId.value == discountId;
  }

  double get discountedAdvance => discountedAdvanceAmount.value;
}