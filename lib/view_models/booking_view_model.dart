// view_models/booking_view_model.dart - COMPLETE WITH NOTIFICATIONS

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/booking_model.dart';
import '../services/notification_service.dart';
import '../services/shared_prefs_helper.dart';

class BookingViewModel extends GetxController {
  final bookings = <BookingModel>[].obs;
  final filteredBookings = <BookingModel>[].obs;
  final selectedTab = "upcoming".obs;
  final isLoading = false.obs;
  final isPayingBalance = false.obs;
  final isCancelling = false.obs;

  // Date filter observables
  final selectedDate = Rx<DateTime?>(null);
  final startDate = Rx<DateTime?>(null);
  final endDate = Rx<DateTime?>(null);
  final selectedPaymentStatus = "All".obs;
  final hasActiveFilters = false.obs;

  final paymentStatusOptions = ["All", "Pending", "Advance Paid", "Fully Paid"];

  late Razorpay _razorpay;
  int? _currentBookingId;
  double? _currentBalanceAmount;

  @override
  void onInit() {
    super.onInit();
    _initRazorpay();
    _checkLoginAndFetch();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleBalancePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleBalancePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _checkLoginAndFetch() async {
    final token = SharedPrefsHelper.getToken();
    if (token != null && token.isNotEmpty) {
      await fetch();
    } else {
      print('User not logged in, skipping bookings fetch');
    }
  }

  Future<void> fetch() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('User not logged in, skipping bookings fetch');
      return;
    }

    isLoading.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/bookings/');

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];
        bookings.value = data
            .map((json) => BookingModel.fromJson(json))
            .toList();
        _applyAllFilters();
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    } finally {
      isLoading.value = false;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}";
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _applyAllFilters() {
    var filtered = List<BookingModel>.from(bookings);

    if (startDate.value != null && endDate.value != null) {
      filtered = filtered.where((b) {
        final bookingDate = _parseDate(b.formattedDate);
        return bookingDate != null &&
            bookingDate.isAfter(startDate.value!.subtract(const Duration(days: 1))) &&
            bookingDate.isBefore(endDate.value!.add(const Duration(days: 1)));
      }).toList();
    }
    else if (selectedDate.value != null) {
      final filterDateStr = _formatDate(selectedDate.value!);
      filtered = filtered.where((b) => b.formattedDate == filterDateStr).toList();
    }

    if (selectedPaymentStatus.value != "All") {
      filtered = filtered.where((b) => b.paymentStatus == selectedPaymentStatus.value).toList();
    }

    final now = DateTime.now();

    switch (selectedTab.value) {
      case "today":
        filtered = filtered.where((b) {
          final bookingDate = _parseDate(b.formattedDate);
          return bookingDate != null &&
              bookingDate.year == now.year &&
              bookingDate.month == now.month &&
              bookingDate.day == now.day &&
              !b.isCancelled;
        }).toList();
        break;

      case "upcoming":
        filtered = filtered.where((b) {
          final bookingDate = _parseDate(b.formattedDate);
          final isFutureDate = bookingDate != null && bookingDate.isAfter(now.subtract(const Duration(days: 1)));
          final isToday = bookingDate != null &&
              bookingDate.year == now.year &&
              bookingDate.month == now.month &&
              bookingDate.day == now.day;
          return !b.isCancelled && (isFutureDate || isToday);
        }).toList();
        break;

      case "completed":
        filtered = filtered.where((b) => b.isCompleted).toList();
        break;

      case "cancelled":
        filtered = filtered.where((b) => b.isCancelled).toList();
        break;

      default:
        break;
    }

    filteredBookings.value = filtered;

    print('=== FILTER DEBUG ===');
    print('Tab: ${selectedTab.value}');
    print('Total bookings: ${bookings.length}');
    print('Filtered bookings: ${filtered.length}');
    print('===================');
  }

  void changeTab(String tab) {
    selectedTab.value = tab;
    _applyAllFilters();
  }

  void clearDateFilters() {
    selectedDate.value = null;
    startDate.value = null;
    endDate.value = null;
    selectedPaymentStatus.value = "All";
    hasActiveFilters.value = false;
    _applyAllFilters();
  }

  void filterByDateRange(DateTime start, DateTime end) {
    selectedDate.value = null;
    selectedPaymentStatus.value = "All";
    startDate.value = DateTime(start.year, start.month, start.day);
    endDate.value = DateTime(end.year, end.month, end.day);
    hasActiveFilters.value = true;
    _applyAllFilters();
  }

  void filterBySingleDate(DateTime date) {
    startDate.value = null;
    endDate.value = null;
    selectedPaymentStatus.value = "All";
    selectedDate.value = DateTime(date.year, date.month, date.day);
    hasActiveFilters.value = true;
    _applyAllFilters();
  }

  void filterByPaymentStatus(String status) {
    selectedPaymentStatus.value = status;
    hasActiveFilters.value = (status != "All") ||
        (selectedDate.value != null) ||
        (startDate.value != null);
    _applyAllFilters();
  }

  // ==================== CANCEL BOOKING WITH NOTIFICATION ====================
  Future<bool> cancelBooking(int bookingId) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar(
        'Login Required',
        'Please login to cancel booking',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return false;
    }

    isCancelling.value = true;
    try {
      final dio = Get.find<Dio>();

      print('Attempting to cancel booking ID: $bookingId');

      final response = await dio.post(
        '/user/bookings/cancel/',
        data: {'booking_id': bookingId},
      );

      print('Cancel response: ${response.statusCode} - ${response.data}');

      if (response.data['result'] == 'success') {
        await fetch();
        Get.snackbar(
          'Success',
          'Booking cancelled successfully! Refund credited to wallet',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        Get.snackbar(
          'Error',
          response.data['message'] ?? 'Cancellation failed',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } on DioException catch (e) {
      print('Cancel Dio error: ${e.response?.statusCode} - ${e.response?.data}');

      if (e.response?.statusCode == 404) {
        try {
          final dio = Get.find<Dio>();
          final response2 = await dio.post(
            '/user/booking/cancel/',
            data: {'booking_id': bookingId},
          );
          if (response2.data['result'] == 'success') {
            await fetch();
            Get.snackbar(
              'Success',
              'Booking cancelled successfully!',
              backgroundColor: Colors.green,
              colorText: Colors.white,
            );
            return true;
          }
        } catch (e2) {
          print('Alternative endpoint also failed: $e2');
        }
      }

      Get.snackbar(
        'Error',
        'Failed to cancel booking. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } catch (e) {
      print('Cancel error: $e');
      Get.snackbar(
        'Error',
        'Failed to cancel booking',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isCancelling.value = false;
    }
  }
  // ==================== BALANCE PAYMENT ====================
  Future<void> initiateBalancePayment(int bookingId, double amount) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar(
        'Login Required',
        'Please login to make payment',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    isPayingBalance.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        '/user/bookings/pay-balance/',
        data: {'booking_id': bookingId, 'amount': amount},
      );

      if (response.data['result'] == 'success') {
        final orderData = response.data['data'];
        _currentBookingId = bookingId;
        _currentBalanceAmount = amount;
        _openRazorpayForBalance(orderData);
      } else {
        Get.snackbar(
          'Error',
          response.data['message'] ?? 'Failed to initiate payment',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        isPayingBalance.value = false;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to initiate payment',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isPayingBalance.value = false;
    }
  }

  void _openRazorpayForBalance(Map<String, dynamic> orderData) {
    const String razorpayKey = 'rzp_live_Rn1hHzY0kkjXFj';
    int amountInPaise = (double.parse(orderData['amount'].toString()) * 100).toInt();

    final options = {
      'key': razorpayKey,
      'amount': amountInPaise,
      'name': 'Book Your Turf',
      'description': 'Balance Payment for Booking',
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
      Get.snackbar(
        'Error',
        'Could not open payment gateway',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isPayingBalance.value = false;
    }
  }

  void _handleBalancePaymentSuccess(PaymentSuccessResponse response) async {
    print('Balance Payment Success - Payment ID: ${response.paymentId}');

    try {
      final dio = Get.find<Dio>();
      final confirmResponse = await dio.post(
        '/user/bookings/confirm-balance/',
        data: {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'booking_id': _currentBookingId,
        },
      );

      if (confirmResponse.data['result'] == 'success') {
        await fetch();
        Get.snackbar(
          'Success',
          'Balance payment completed successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
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
      Get.snackbar(
        'Error',
        'Failed to confirm payment',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isPayingBalance.value = false;
      _currentBookingId = null;
      _currentBalanceAmount = null;
    }
  }
  void _handleBalancePaymentError(PaymentFailureResponse response) {
    print('Balance Payment Error: ${response.code} - ${response.message}');
    Get.snackbar(
      'Payment Failed',
      response.message ?? 'Payment failed. Please try again.',
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    isPayingBalance.value = false;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }

  int getTodayCount() {
    final now = DateTime.now();
    return bookings.where((b) {
      final bookingDate = _parseDate(b.formattedDate);
      return bookingDate != null &&
          bookingDate.year == now.year &&
          bookingDate.month == now.month &&
          bookingDate.day == now.day &&
          !b.isCancelled;
    }).length;
  }

  int getUpcomingCount() {
    final now = DateTime.now();
    return bookings.where((b) {
      final bookingDate = _parseDate(b.formattedDate);
      final isFutureDate = bookingDate != null && bookingDate.isAfter(now.subtract(const Duration(days: 1)));
      final isToday = bookingDate != null &&
          bookingDate.year == now.year &&
          bookingDate.month == now.month &&
          bookingDate.day == now.day;
      return !b.isCancelled && (isFutureDate || isToday);
    }).length;
  }

  int getCompletedCount() {
    return bookings.where((b) => b.isCompleted).length;
  }

  int getCancelledCount() {
    return bookings.where((b) => b.isCancelled).length;
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }
}