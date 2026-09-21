// view_models/booking_view_model.dart - With Lazy Loading + Caching
// ✅ Duplicate API call prevention - FIXED
// ✅ Fixed: Removed unused _currentBalanceAmount
// ✅ Success snackbar - White background with black text

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_config.dart';
import '../models/booking_model.dart';
import '../services/shared_prefs_helper.dart';
import '../services/meta_events_service.dart';

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

  static bool _dataLoaded = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = AppConfig.bookingCacheDuration;

  // ✅ DUPLICATE API CALL PREVENTION
  static bool _isFetchingBookings = false;
  static DateTime? _lastFetchCallTime;
  static const _minFetchInterval = Duration(seconds: 3);
  Timer? _refreshDebounceTimer;
  static const _refreshDebounceDuration = Duration(milliseconds: 300); // Reduced from 500ms

  // ✅ NEW: Track if refresh is in progress
  static bool _isRefreshInProgress = false;
  // ✅ Single-flight: callers arriving during a fetch wait for it
  static Future<void>? _bookingsFetchFuture;
  static Future<void>? _refreshFuture;

  // ============================================================
  // ✅ SHOW CUSTOM SMALL SNACKBAR AT TOP
  // ============================================================
  void _showSmallSnackbar(String title, String message, Color color, {Color textColor = Colors.white}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: textColor,
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
        color: textColor,
        size: 18,
      ),
    );
  }

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
    final running = _bookingsFetchFuture;
    if (running != null) {
      print('⏳ Bookings fetch in progress - waiting for it');
      await running;
      if (!forceRefresh) return;
      final again = _bookingsFetchFuture;
      if (again != null) {
        await again;
        return;
      }
    }
    final completer = Completer<void>();
    _bookingsFetchFuture = completer.future;
    try {
      await _loadBookingsInternal(forceRefresh: forceRefresh);
    } finally {
      _bookingsFetchFuture = null;
      completer.complete();
    }
  }

  Future<void> _loadBookingsInternal({bool forceRefresh = false}) async {
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

    // ✅ FIX: Prevent concurrent fetches
    if (_isFetchingBookings) {
      print('⏭️ Bookings fetch already in progress - skipping duplicate (forceRefresh: $forceRefresh)');
      return;
    }

    // ✅ Check cache
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

      final rData = response.data;
      if (_isSuccess(rData)) {
        final inner = rData['data'];
        final List<dynamic> data =
            (inner is Map && inner['results'] is List) ? inner['results'] as List : const [];
        // ✅ one bad record no longer empties the whole list
        final parsed = <BookingModel>[];
        for (final json in data) {
          try {
            if (json is Map) {
              parsed.add(BookingModel.fromJson(Map<String, dynamic>.from(json)));
            }
          } catch (e) {
            print('⚠️ Skipped bad booking record: $e');
          }
        }
        bookings.value = parsed;

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

  // 📊 Meta: booking history screen opened (called by MainPage / history route)
  DateTime? _lastHistoryLog;
  void logHistoryView() {
    final now = DateTime.now();
    if (_lastHistoryLog != null && now.difference(_lastHistoryLog!) < const Duration(seconds: 30)) {
      return; // same visit
    }
    _lastHistoryLog = now;
    try {
      final list = bookings.toList();
      int upcoming = 0, cancelled = 0, pending = 0;
      for (final b in list) {
        if (b.isCancelled) {
          cancelled++;
          continue;
        }
        if (b.pendingAmount > 0) pending++;
        if (b.status == 'upcoming') upcoming++;
      }
      unawaited(MetaEvents.bookingHistoryView(
        totalBookings: list.length,
        upcoming: upcoming,
        cancelled: cancelled,
        pendingPayment: pending,
      ));
    } catch (e) {
      print('⚠️ history view event skipped: $e');
    }
  }

  Future<bool> cancelBooking(int bookingId) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      _showSmallSnackbar('Login Required', 'Please login to cancel booking', Colors.orange);
      return false;
    }

    isCancelling.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        AppConfig.cancelBooking,
        data: {'booking_id': bookingId},
      );

      if (_isSuccess(response.data)) {
        // 📊 Meta: booking cancelled
        BookingModel? cancelled;
        for (final b in bookings) {
          if (b.id == bookingId) {
            cancelled = b;
            break;
          }
        }
        unawaited(MetaEvents.bookingCancelled(
          bookingId: bookingId,
          turfName: cancelled?.turfName,
          refundAmount: cancelled?.paidAmount,
        ));

        _dataLoaded = false;
        // ✅ Use forceRefresh directly to bypass cache
        await loadBookings(forceRefresh: true);
        _showSmallSnackbar('Success', 'Booking cancelled and amount refunded to wallet!', Colors.white, textColor: Colors.black);
        return true;
      } else {
        _showSmallSnackbar('Error', _messageOf(response.data) ?? 'Cancellation failed', Colors.red);
        return false;
      }
    } on DioException catch (e) {
      print('Cancel error: ${e.response?.statusCode} - ${e.response?.data}');
      _showSmallSnackbar('Error', 'Failed to cancel booking. Please try again.', Colors.red);
      return false;
    } catch (e) {
      print('Cancel error: $e');
      _showSmallSnackbar('Error', 'Failed to cancel booking', Colors.red);
      return false;
    } finally {
      isCancelling.value = false;
    }
  }

  // ✅ Safe response helpers – a non-JSON / HTML error page must not crash
  bool _isSuccess(dynamic data) => data is Map && data['result'] == 'success';
  String? _messageOf(dynamic data) =>
      data is Map ? data['message']?.toString() : null;

  // ==================== BALANCE PAYMENT (Razorpay) ====================
  double _currentBalanceAmount = 0;

  Future<void> initiateBalancePayment(int bookingId, double amount) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      _showSmallSnackbar('Login Required', 'Please login to make payment', Colors.orange);
      return;
    }

    isPayingBalance.value = true;
    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        AppConfig.payBalance,
        data: {'booking_id': bookingId, 'amount': amount.toString()},
      );

      final rData = response.data;
      if (_isSuccess(rData) && rData['data'] is Map) {
        final orderData = Map<String, dynamic>.from(rData['data'] as Map);
        _currentBookingId = bookingId;
        _currentBalanceAmount = amount;
        _openRazorpayForBalance(orderData);
      } else {
        final msg = _messageOf(rData) ?? 'Failed to initiate payment';
        _showSmallSnackbar('Error', msg, Colors.red);
        isPayingBalance.value = false;
        unawaited(MetaEvents.balancePaymentFailed(
            bookingId: bookingId, method: 'online', amount: amount, reason: msg));
      }
    } catch (e) {
      _showSmallSnackbar('Error', 'Failed to initiate payment', Colors.red);
      isPayingBalance.value = false;
      unawaited(MetaEvents.balancePaymentFailed(
          bookingId: bookingId, method: 'online', amount: amount, reason: 'initiate_error'));
    }
  }

  void _openRazorpayForBalance(Map<String, dynamic> orderData) {
    // ✅ tryParse – a bad amount from the server must not crash the app
    final double orderAmount =
        double.tryParse(orderData['amount']?.toString() ?? '') ?? _currentBalanceAmount;
    if (orderAmount <= 0 || orderData['razorpay_order_id'] == null) {
      _showSmallSnackbar('Error', 'Invalid payment details. Please try again.', Colors.red);
      isPayingBalance.value = false;
      return;
    }
    int amountInPaise = (orderAmount * 100).round();

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
      _showSmallSnackbar('Error', 'Could not open payment gateway', Colors.red);
      isPayingBalance.value = false;
    }
  }

  // ============================================================
  // ✅ CONFIRM-BALANCE AFTER RAZORPAY (webhook-aware, called once)
  //  • 200 + result success → OK. data = { booking_id: "<code>" } in both the
  //    first-time and the already-done case.
  //  • 400 "Invalid booking" / "No pending reservation found..." → reload the
  //    bookings once; if this booking's pending balance is now cleared → SUCCESS.
  //  • Advance Paid is NOT Fully Paid – success is judged on the pending
  //    balance going down, never on the order being "fulfilled".
  // ============================================================
  static final Set<String> _confirmedBalancePayments = <String>{};

  void _handleBalancePaymentSuccess(PaymentSuccessResponse response) async {
    print('Balance Payment Success - Payment ID: ${response.paymentId}');

    final int? bookingId = _currentBookingId;
    final double amount = _currentBalanceAmount;

    // pending balance before this payment (to verify the fallback)
    double? pendingBefore;
    for (final b in bookings) {
      if (b.id == bookingId) {
        pendingBefore = b.pendingAmount;
        break;
      }
    }

    final String payKey = (response.paymentId ?? response.orderId ?? '').toString();
    if (payKey.isNotEmpty && !_confirmedBalancePayments.add(payKey)) {
      print('⏭️ confirm-balance already sent for $payKey - not calling again');
      return;
    }

    bool confirmed = false;
    String failReason = 'confirm_error';

    try {
      final dio = Get.find<Dio>();
      final confirmResponse = await dio.post(
        AppConfig.confirmBalance,
        data: {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id': response.orderId,
          'booking_id': bookingId,
        },
      );
      if (confirmResponse.statusCode == 200 && _isSuccess(confirmResponse.data)) {
        confirmed = true;
      } else {
        failReason = 'confirm: ${_messageOf(confirmResponse.data) ?? 'not_success'}';
      }
    } on DioException catch (e) {
      final msg = _messageOf(e.response?.data) ?? '';
      final lower = msg.toLowerCase();
      failReason = msg.isNotEmpty ? 'confirm: $msg' : 'http_${e.response?.statusCode ?? e.type.name}';

      if (e.response?.statusCode == 400 &&
          (lower.contains('invalid booking') ||
              lower.contains('no pending reservation found') ||
              lower.contains('already'))) {
        print('ℹ️ confirm-balance 400 "$msg" - checking bookings once');
        confirmed = await _balancePaidOnServer(bookingId, pendingBefore, amount);
      }
    } catch (e) {
      print('⚠️ confirm-balance error: $e');
    }

    try {
      if (confirmed) {
        unawaited(MetaEvents.balancePaymentSuccess(
          bookingId: bookingId ?? 0,
          method: 'online',
          amount: amount,
        ));
        _dataLoaded = false;
        await loadBookings(forceRefresh: true);
        _showSmallSnackbar('Success', 'Balance payment completed successfully!', Colors.white, textColor: Colors.black);
      } else {
        unawaited(MetaEvents.balancePaymentFailed(
            bookingId: bookingId, method: 'online', amount: amount, reason: failReason));
        // Money was taken by Razorpay – don't say "failed"; refresh and inform.
        _dataLoaded = false;
        await loadBookings(forceRefresh: true);
        _showSmallSnackbar(
          'Payment received',
          'We are updating your booking. Pull down to refresh if the balance still shows.',
          Colors.orange,
        );
      }
    } finally {
      isPayingBalance.value = false;
      _currentBookingId = null;
    }
  }

  /// Reloads bookings once and checks that this booking's pending balance
  /// went down by the amount just paid (Advance Paid ≠ Fully Paid).
  Future<bool> _balancePaidOnServer(int? bookingId, double? pendingBefore, double paid) async {
    if (bookingId == null) return false;
    try {
      _dataLoaded = false;
      await loadBookings(forceRefresh: true);
      for (final b in bookings) {
        if (b.id != bookingId) continue;
        if (pendingBefore == null) return b.pendingAmount <= 0.01;
        return b.pendingAmount <= (pendingBefore - paid) + 0.01;
      }
    } catch (e) {
      print('⚠️ Balance verification failed: $e');
    }
    return false;
  }

  void _handleBalancePaymentError(PaymentFailureResponse response) {
    print('Balance Payment Error: ${response.code} - ${response.message}');
    unawaited(MetaEvents.balancePaymentFailed(
      bookingId: _currentBookingId,
      method: 'online',
      amount: _currentBalanceAmount,
      reason: response.code == Razorpay.PAYMENT_CANCELLED
          ? 'user_cancelled'
          : (response.message ?? 'unknown'),
    ));
    _showSmallSnackbar('Payment Failed', response.message ?? 'Payment failed. Please try again.', Colors.red);
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

      if (_isSuccess(response.data)) {
        unawaited(MetaEvents.balancePaymentSuccess(
          bookingId: bookingId,
          method: 'wallet',
          amount: amount,
        ));
        _dataLoaded = false;
        // ✅ Use forceRefresh directly to bypass cache
        await loadBookings(forceRefresh: true);
        _showSmallSnackbar(
          'Payment Successful',
          '₹${amount.toStringAsFixed(2)} deducted from wallet',
          Colors.white,
          textColor: Colors.black,
        );
      } else {
        final msg = _messageOf(response.data) ?? 'Something went wrong';
        unawaited(MetaEvents.balancePaymentFailed(
            bookingId: bookingId, method: 'wallet', amount: amount, reason: msg));
        _showSmallSnackbar(
          'Payment Failed',
          msg,
          Colors.red,
        );
      }
    } catch (e) {
      print('Wallet balance payment error: $e');
      String msg = 'Payment failed. Please try again.';
      if (e is DioException) msg = _messageOf(e.response?.data) ?? msg;
      unawaited(MetaEvents.balancePaymentFailed(
          bookingId: bookingId, method: 'wallet', amount: amount, reason: msg));
      _showSmallSnackbar(
        'Error',
        msg,
        Colors.red,
      );
    } finally {
      isPayingBalance.value = false;
    }
  }

  // ==================== REFRESH ====================

  Future<void> refreshBookings() async {
    // ✅ A refresh is running → wait for it (callers get fresh data)
    final running = _refreshFuture;
    if (running != null) {
      print('⏳ Refresh already in progress - waiting for it');
      await running;
      return;
    }
    final completer = Completer<void>();
    _refreshFuture = completer.future;
    try {
      await _refreshBookingsInternal();
    } finally {
      _refreshFuture = null;
      completer.complete();
    }
  }

  Future<void> _refreshBookingsInternal() async {

    _isRefreshInProgress = true;
    _refreshDebounceTimer?.cancel();

    // ✅ Use a small delay to debounce multiple rapid calls
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      _dataLoaded = false;
      await loadBookings(forceRefresh: true);
      print('✅ Refresh completed successfully');
    } catch (e) {
      print('❌ Refresh error: $e');
    } finally {
      _isRefreshInProgress = false;
    }
  }

  // ✅ Simplified refresh method without Completer
  // The caller can await refreshBookings() directly now

  static void resetCache() {
    _dataLoaded = false;
    _lastFetchTime = null;
    _isFetchingBookings = false;
    _lastFetchCallTime = null;
    _isRefreshInProgress = false;
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