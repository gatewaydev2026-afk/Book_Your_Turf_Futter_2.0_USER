// view_models/booking_view_model.dart - LAZY LOADING

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/booking_model.dart';
import '../services/shared_prefs_helper.dart';

class BookingViewModel extends GetxController {
  final bookings = <BookingModel>[].obs;
  final filteredBookings = <BookingModel>[].obs;
  final selectedTab = "upcoming".obs;
  final isLoading = false.obs;
  final isPayingBalance = false.obs;
  final isCancelling = false.obs;

  final selectedDate = Rx<DateTime?>(null);
  final startDate = Rx<DateTime?>(null);
  final endDate = Rx<DateTime?>(null);
  final selectedPaymentStatus = "All".obs;
  final hasActiveFilters = false.obs;

  final paymentStatusOptions = ["All", "Pending", "Advance Paid", "Fully Paid"];

  late Razorpay _razorpay;
  int? _currentBookingId;
  double? _currentBalanceAmount;

  static bool _dataLoaded = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 1);

  @override
  void onInit() {
    super.onInit();
    _initRazorpay();
    print('📋 BookingViewModel initialized (lazy loading - will fetch when needed)');
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleBalancePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleBalancePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // ✅ Call this method ONLY when user opens Booking screen
  Future<void> loadBookings({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 No token, skipping bookings fetch');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping bookings fetch');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // Check cache
    if (!forceRefresh && _dataLoaded && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration) {
        print('⏭️ Bookings cached (${age.inSeconds}s old) - using cache');
        return;
      }
    }

    if (!forceRefresh && _dataLoaded && bookings.isNotEmpty) {
      print('⏭️ Bookings already loaded (${bookings.length} bookings)');
      return;
    }

    print('📡 Fetching bookings from API...');
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
        _dataLoaded = true;
        _lastFetchTime = DateTime.now();

        print('✅ Bookings fetched: ${bookings.length} bookings');
      }
    } catch (e) {
      print('❌ Error fetching bookings: $e');
    } finally {
      isLoading.value = false;
    }
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    try {
      String cleanDate = dateStr.trim();

      if (cleanDate.contains('-')) {
        final parts = cleanDate.split('-');
        if (parts.length == 3) {
          int first = int.tryParse(parts[0]) ?? 0;
          int second = int.tryParse(parts[1]) ?? 0;
          int third = int.tryParse(parts[2]) ?? 0;

          if (first > 31) {
            return DateTime(third, second, first);
          } else {
            return DateTime(third, second, first);
          }
        }
      }

      return DateTime.tryParse(cleanDate);
    } catch (e) {
      print('⚠️ Error parsing date: $dateStr - $e');
      return null;
    }
  }

  bool _isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isDateAfter(DateTime? date, DateTime? reference) {
    if (date == null || reference == null) return false;
    return date.isAfter(reference);
  }

  void _applyAllFilters() {
    var filtered = List<BookingModel>.from(bookings);

    if (startDate.value != null && endDate.value != null) {
      filtered = filtered.where((b) {
        final bookingDate = _parseDate(b.formattedDate);
        if (bookingDate == null) return false;
        final isAfterStart = bookingDate.isAfter(startDate.value!.subtract(const Duration(days: 1)));
        final isBeforeEnd = bookingDate.isBefore(endDate.value!.add(const Duration(days: 1)));
        return isAfterStart && isBeforeEnd;
      }).toList();
    }
    else if (selectedDate.value != null) {
      filtered = filtered.where((b) {
        final bookingDate = _parseDate(b.formattedDate);
        if (bookingDate == null) return false;
        return _isSameDay(bookingDate, selectedDate.value);
      }).toList();
    }

    if (selectedPaymentStatus.value != "All") {
      filtered = filtered.where((b) => b.paymentStatus == selectedPaymentStatus.value).toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    switch (selectedTab.value) {
      case "today":
        filtered = filtered.where((b) {
          if (b.isCancelled) return false;
          final bookingDate = _parseDate(b.formattedDate);
          if (bookingDate == null) return false;
          return _isSameDay(bookingDate, today);
        }).toList();
        break;

      case "upcoming":
        filtered = filtered.where((b) {
          if (b.isCancelled) return false;
          final bookingDate = _parseDate(b.formattedDate);
          if (bookingDate == null) return false;
          final isToday = _isSameDay(bookingDate, today);
          final isFuture = bookingDate.isAfter(yesterday);
          return isToday || isFuture;
        }).toList();
        break;

      case "completed":
        filtered = filtered.where((b) {
          if (b.isCancelled) return false;
          final bookingDate = _parseDate(b.formattedDate);
          if (bookingDate == null) return false;
          return bookingDate.isBefore(today);
        }).toList();
        break;

      case "cancelled":
        filtered = filtered.where((b) => b.isCancelled).toList();
        break;
    }

    filteredBookings.value = filtered;

    print('\n=== FILTER DEBUG ===');
    print('Tab: ${selectedTab.value}');
    print('Total bookings: ${bookings.length}');
    print('Filtered bookings: ${filtered.length}');
    print('===================\n');
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

  Future<bool> cancelBooking(int bookingId) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to cancel booking',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    isCancelling.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        '/user/bookings/cancel/',
        data: {'booking_id': bookingId},
      );

      if (response.data['result'] == 'success') {
        _dataLoaded = false;
        await loadBookings(forceRefresh: true);
        Get.snackbar('Success', 'Booking cancelled successfully!',
            backgroundColor: Colors.green, colorText: Colors.white);
        return true;
      } else {
        Get.snackbar('Error', response.data['message'] ?? 'Cancellation failed',
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }
    } on DioException catch (e) {
      print('Cancel error: ${e.response?.statusCode} - ${e.response?.data}');

      try {
        final dio = Get.find<Dio>();
        final response2 = await dio.post(
          '/user/booking/cancel/',
          data: {'booking_id': bookingId},
        );
        if (response2.data['result'] == 'success') {
          _dataLoaded = false;
          await loadBookings(forceRefresh: true);
          Get.snackbar('Success', 'Booking cancelled successfully!',
              backgroundColor: Colors.green, colorText: Colors.white);
          return true;
        }
      } catch (e2) {
        print('Alternative endpoint also failed: $e2');
      }

      Get.snackbar('Error', 'Failed to cancel booking. Please try again.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    } catch (e) {
      print('Cancel error: $e');
      Get.snackbar('Error', 'Failed to cancel booking',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    } finally {
      isCancelling.value = false;
    }
  }

  Future<void> initiateBalancePayment(int bookingId, double amount) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to make payment',
          backgroundColor: Colors.orange, colorText: Colors.white);
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
        Get.snackbar('Error', response.data['message'] ?? 'Failed to initiate payment',
            backgroundColor: Colors.red, colorText: Colors.white);
        isPayingBalance.value = false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to initiate payment',
          backgroundColor: Colors.red, colorText: Colors.white);
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
      Get.snackbar('Error', 'Could not open payment gateway',
          backgroundColor: Colors.red, colorText: Colors.white);
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
        _dataLoaded = false;
        await loadBookings(forceRefresh: true);
        Get.snackbar('Success', 'Balance payment completed successfully!',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', confirmResponse.data['message'] ?? 'Payment confirmation failed',
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to confirm payment',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isPayingBalance.value = false;
      _currentBookingId = null;
      _currentBalanceAmount = null;
    }
  }

  void _handleBalancePaymentError(PaymentFailureResponse response) {
    print('Balance Payment Error: ${response.code} - ${response.message}');
    Get.snackbar('Payment Failed', response.message ?? 'Payment failed. Please try again.',
        backgroundColor: Colors.red, colorText: Colors.white);
    isPayingBalance.value = false;
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
  }

  int getTodayCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return bookings.where((b) {
      if (b.isCancelled) return false;
      final bookingDate = _parseDate(b.formattedDate);
      if (bookingDate == null) return false;
      return _isSameDay(bookingDate, today);
    }).length;
  }

  int getUpcomingCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    return bookings.where((b) {
      if (b.isCancelled) return false;
      final bookingDate = _parseDate(b.formattedDate);
      if (bookingDate == null) return false;
      final isToday = _isSameDay(bookingDate, today);
      final isFuture = bookingDate.isAfter(yesterday);
      return isToday || isFuture;
    }).length;
  }

  int getCompletedCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return bookings.where((b) {
      if (b.isCancelled) return false;
      final bookingDate = _parseDate(b.formattedDate);
      if (bookingDate == null) return false;
      return bookingDate.isBefore(today);
    }).length;
  }

  int getCancelledCount() {
    return bookings.where((b) => b.isCancelled).length;
  }

  // ✅ Call this when user pulls to refresh
  Future<void> refreshBookings() async {
    _dataLoaded = false;
    await loadBookings(forceRefresh: true);
  }

  static void resetCache() {
    _dataLoaded = false;
    _lastFetchTime = null;
  }

  @override
  void onClose() {
    _razorpay.clear();
    super.onClose();
  }
}