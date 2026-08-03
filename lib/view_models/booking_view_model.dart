// view_models/booking_view_model.dart - With Lazy Loading + Caching
// ✅ Duplicate API call prevention
// ✅ Fixed: Removed unused _currentBalanceAmount

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_config.dart';
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
  // ✅ REMOVED: double? _currentBalanceAmount; - Not used anywhere

  static bool _dataLoaded = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = AppConfig.bookingCacheDuration;

  // ✅ DUPLICATE API CALL PREVENTION
  static bool _isFetchingBookings = false;
  static DateTime? _lastFetchCallTime;  // ✅ Made static
  static const _minFetchInterval = Duration(seconds: 3);
  Timer? _refreshDebounceTimer;
  static const _refreshDebounceDuration = Duration(milliseconds: 500);

  @override
  void onInit() {
    super.onInit();
    _initRazorpay();
    print('📋 BookingViewModel initialized (lazy loading)');
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleBalancePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleBalancePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // ==================== LAZY LOADING ====================

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

    // ✅ FIX: Prevent duplicate calls within 3 seconds
    if (!forceRefresh && _lastFetchCallTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchCallTime!);
      if (elapsed < _minFetchInterval) {
        print('⏭️ Bookings fetch skipped (${elapsed.inMilliseconds}ms since last fetch)');
        return;
      }
    }

    // ✅ FIX: Prevent concurrent fetches. This lock now applies EVEN when
    // forceRefresh=true. Previously `_isFetchingBookings && !forceRefresh`
    // let forceRefresh bypass this lock entirely, so if two callers both
    // triggered a forceRefresh at nearly the same time (e.g. cancelBooking()
    // and a UI-level refresh call), BOTH fired the API back-to-back - visible
    // in logs as "Fetching bookings from API..." printed twice in a row.
    // forceRefresh should only skip the cache-freshness checks further below,
    // not allow two overlapping in-flight requests.
    if (_isFetchingBookings) {
      print('⏭️ Bookings fetch already in progress - skipping duplicate (forceRefresh: $forceRefresh)');
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

    _isFetchingBookings = true;
    print('📡 Fetching bookings from API...');
    isLoading.value = true;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get(AppConfig.bookings);

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data']['results'] ?? [];
        bookings.value = data
            .map((json) => BookingModel.fromJson(json))
            .toList();

        _applyAllFilters();
        _dataLoaded = true;
        _lastFetchTime = DateTime.now();
        _lastFetchCallTime = DateTime.now();

        print('✅ Bookings fetched: ${bookings.length} bookings');
      }
    } catch (e) {
      print('❌ Error fetching bookings: $e');
    } finally {
      isLoading.value = false;
      _isFetchingBookings = false;
    }
  }

  // ==================== FILTERS ====================

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

  // ==================== COUNT HELPERS ====================

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

  // ==================== CANCEL BOOKING ====================

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
        AppConfig.cancelBooking,
        data: {'booking_id': bookingId},
      );

      if (response.data['result'] == 'success') {
        _dataLoaded = false;
        await loadBookings(forceRefresh: true);
        Get.snackbar('Success', 'Booking cancelled and amount refunded to wallet!',
            backgroundColor: Colors.green, colorText: Colors.white);
        return true;
      } else {
        Get.snackbar('Error', response.data['message'] ?? 'Cancellation failed',
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }
    } on DioException catch (e) {
      print('Cancel error: ${e.response?.statusCode} - ${e.response?.data}');
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

  // ==================== BALANCE PAYMENT (Razorpay) ====================

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
        AppConfig.payBalance,
        data: {'booking_id': bookingId, 'amount': amount.toString()},
      );

      if (response.data['result'] == 'success') {
        final orderData = response.data['data'];
        _currentBookingId = bookingId;
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
    int amountInPaise = (double.parse(orderData['amount'].toString()) * 100).toInt();

    final options = {
      'key': AppConfig.razorpayKey,
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
        AppConfig.confirmBalance,
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

  // ==================== WALLET PAYMENT ====================

  Future<void> payBalanceWithWallet(int bookingId, double amount) async {
    if (isPayingBalance.value) return;

    isPayingBalance.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        AppConfig.payBalanceWallet,
        data: {
          'booking_id': bookingId,
          'amount': amount.toString(),
        },
      );

      if (response.data['result'] == 'success') {
        _dataLoaded = false;
        await loadBookings(forceRefresh: true);
        Get.snackbar(
          'Payment Successful',
          '₹${amount.toStringAsFixed(2)} deducted from wallet',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Payment Failed',
          response.data['message'] ?? 'Something went wrong',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Wallet balance payment error: $e');
      Get.snackbar(
        'Error',
        'Payment failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isPayingBalance.value = false;
    }
  }

  // ==================== REFRESH ====================

  Future<void> refreshBookings() async {
    _refreshDebounceTimer?.cancel();

    // ✅ FIX: previously this method returned immediately without waiting for the
    // debounced Timer to actually fire, so any `await refreshBookings()` caller
    // thought the refresh was done before the real API call even started - the UI
    // (dialogs / lists) then looked "stuck" on old/cached data right after payment.
    final completer = Completer<void>();
    _refreshDebounceTimer = Timer(_refreshDebounceDuration, () async {
      _dataLoaded = false;
      await loadBookings(forceRefresh: true);
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  static void resetCache() {
    _dataLoaded = false;
    _lastFetchTime = null;
    _isFetchingBookings = false;
    _lastFetchCallTime = null;
  }

  // ==================== DATE HELPERS ====================

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
            return DateTime(first, second, third);
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

  @override
  void onClose() {
    _razorpay.clear();
    _refreshDebounceTimer?.cancel();
    super.onClose();
  }
}