// booking_summary_view_model.dart - Complete with Booking Count for Meta
// ✅ Sep 2026 funnel fixes:
//   • Summary event renamed: fb_mobile_view_content → fb_mobile_initiated_checkout (+ visit count)
//   • "Complete your profile" popup REMOVED from the payment path (name/email not needed to pay)
//   • Best eligible offer is AUTO-APPLIED (user can still remove it)
//   • payment_initiated / payment_failed events added
//   • Purchase event: standard fb_currency / fb_content_type added, lists JSON-encoded

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_config.dart';
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
import '../services/meta_events_service.dart';

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
  final hasShownMinSlotsDialog = false.obs;

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

  // ✅ DUPLICATE API CALL PREVENTION FLAGS
  bool _isWalletPaymentInProgress = false;
  bool _isProfileFetchInProgress = false;
  bool _isBookingRefreshInProgress = false;
  bool _isSuccessDialogShown = false;
  bool _isPostPaymentProcessing = false;
  bool _isNavigating = false;
  bool _isCheckingProfile = false;

  // ✅ Store the booking action to call after profile update
  Future<void> Function()? _pendingBookingAction;

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

    _logInitiatedCheckoutEvent();

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

  // 📊 Meta: Booking summary opened → Initiated Checkout (was wrongly named View Content)
  Future<void> _logInitiatedCheckoutEvent() async {
    await MetaEvents.initiatedCheckout(
      turf: turf,
      slotsCount: selectedSlots.length,
      paymentType: selectedPaymentType,
      totalAmount: totalAmount,
      payableAmount: payableAmount,
      date: formattedDate,
      courtNumber: selectedCourt,
    );
  }

  // ✅ Log booking success to Meta (wallet / online counted separately).
  //    Fire-and-forget: never blocks or crashes the payment flow.
  bool _bookingSuccessLogged = false;

  // ✅ Confirm is sent at most ONCE per Razorpay order, even if the success
  //    callback fires twice or a second BookingSummaryViewModel exists.
  static final Set<String> _confirmedOrderIds = <String>{};

  /// 200 from confirm means the booking is saved – either the first-time
  /// response or "Booking already confirmed" with the booking object.
  // ============================================================
  // ✅ CONFIRM AFTER RAZORPAY (webhook-aware)
  // Flow: initiate → Razorpay → webhook saves booking → app confirm (backup).
  //  • 200 + result success  → OK. Data is either {booking_id, id} (first time)
  //    or "Booking already confirmed" with the full booking object.
  //  • 400 "No pending reservation found. It may have expired." / "Invalid
  //    booking" (old backend, slow users) → check GET /bookings once; if the
  //    booking for these slots exists → SUCCESS, no error popup.
  //  • Called exactly once. Request body = same JSON shape as before.
  // ============================================================
  static const List<String> _webhookAlreadySavedMessages = [
    'no pending reservation found',
    'invalid booking',
    'already confirmed',
  ];

  bool _isWebhookAlreadySavedMessage(String msg) {
    final lower = msg.toLowerCase();
    return _webhookAlreadySavedMessages.any(lower.contains);
  }

  /// Returns true when the booking is confirmed (by this call or by the webhook).
  Future<bool> _confirmBookingOnce(Map<String, dynamic> confirmData, double amountPaid) async {
    try {
      print('📤 Confirm Booking: $confirmData');
      final dio = Get.find<Dio>();
      final res = await dio.post(AppConfig.confirmBooking, data: confirmData);
      final data = res.data;

      if (res.statusCode == 200 && _confirmLooksSuccessful(data)) {
        final msg = data is Map ? (data['message']?.toString() ?? '') : '';
        print('✅ Booking confirmed${msg.isNotEmpty ? ' ($msg)' : ''}');
        return true;
      }

      final msg = (data is Map ? data['message']?.toString() : null) ?? 'confirm_not_success';
      unawaited(MetaEvents.bookingConfirmFailed(
        turf: turf, amount: amountPaid, reason: msg, orderId: _currentOrderId,
      ));
      return false;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map ? data['message']?.toString() : data?.toString()) ?? '';

      if (e.response?.statusCode == 400 && _isWebhookAlreadySavedMessage(msg)) {
        print('ℹ️ Confirm 400 "$msg" - checking bookings once');
        if (await _bookingExistsOnServer()) {
          print('✅ Booking already saved by the webhook - treating as success');
          return true;
        }
      }

      print('⚠️ Confirmation error (${e.response?.statusCode}): $msg');
      unawaited(MetaEvents.bookingConfirmFailed(
        turf: turf,
        amount: amountPaid,
        reason: msg.isNotEmpty ? msg : 'http_${e.response?.statusCode ?? e.type.name}',
        orderId: _currentOrderId,
      ));
      return false;
    } catch (e) {
      print('⚠️ Confirmation error: $e');
      unawaited(MetaEvents.bookingConfirmFailed(
        turf: turf, amount: amountPaid, reason: 'exception', orderId: _currentOrderId,
      ));
      return false;
    }
  }

  bool _confirmLooksSuccessful(dynamic data) {
    if (data is! Map) return false;
    if (data['result'] == 'success') return true;
    final inner = data['data'];
    if (inner is Map && (inner['booking_id'] != null || inner['id'] != null)) return true;
    return data['booking_id'] != null || data['id'] != null;
  }

  /// Reads the bookings list ONCE and checks whether this turf/date/slot is
  /// already booked (used when confirm answers 400 after a webhook save).
  Future<bool> _bookingExistsOnServer() async {
    try {
      if (!Get.isRegistered<BookingViewModel>()) return false;
      final bookingVm = Get.find<BookingViewModel>();
      await bookingVm.loadBookings(forceRefresh: true);

      final String date = formattedDate;
      final Set<String> startTimes =
          selectedSlots.map((s) => s.startTime.toString()).toSet();

      for (final b in bookingVm.bookings) {
        if (b.isCancelled) continue;
        if (b.turfName.trim().toLowerCase() != turf.name.trim().toLowerCase()) continue;
        for (final slot in b.slots) {
          final sameDate = (slot['date'] ?? '').toString() == date;
          final sameSlot = startTimes.contains((slot['start_time'] ?? '').toString());
          if (sameDate && sameSlot) return true;
        }
      }
    } catch (e) {
      print('⚠️ Booking verification failed: $e');
    }
    return false;
  }

  void _logBookingSuccessEvent({
    required String method, // 'wallet' | 'online'
    required double amountPaid,
    String? paymentId,
    String? orderId,
  }) {
    if (_bookingSuccessLogged) {
      print('⏭️ Booking success already logged for this checkout');
      return;
    }
    _bookingSuccessLogged = true;

    unawaited(() async {
      try {
        await _incrementBookingCount(); // keeps the old SharedPrefs counter in sync
        await MetaEvents.bookingSuccess(
          turf: turf,
          method: method,
          paymentType: selectedPaymentType,
          amountPaid: amountPaid,
          totalAmount: totalAmount,
          slotsCount: selectedSlots.length,
          date: formattedDate,
          courtNumber: selectedCourt,
          paymentId: paymentId,
          orderId: orderId,
          discountAmount: discountVm.hasSelectedDiscount ? discountVm.totalDiscountAmount : 0,
          adminDiscountId: discountVm.selectedAdminDiscountId.value,
          partnerDiscountId: discountVm.selectedPartnerDiscountId.value,
        );
        print('✅ Booking success sent to Meta ($method, ₹$amountPaid)');
      } catch (e) {
        print('❌ Error logging booking success event: $e');
      }
    }());
  }

  // ✅ NEW: Method to increment the booking count and return the new value
  Future<int> _incrementBookingCount() async {
    try {
      // Get the current count from SharedPreferences
      int currentCount = SharedPrefsHelper.getBookingCount();

      // ✅ Increment the count by 1 (for this new booking)
      currentCount += 1;

      // ✅ Save the updated count
      await SharedPrefsHelper.setBookingCount(currentCount);

      print('📊 Booking Count Incremented: $currentCount');
      return currentCount;
    } catch (e) {
      print('❌ Error incrementing booking count: $e');
      return 1; // Return 1 as default if there's an error
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
        // ✅ Funnel fix: apply the best offer automatically (user can still tap to remove)
        _autoApplyBestDiscounts();
      }

    } catch (e) {
      print('Error loading discounts: $e');
    } finally {
      isLoadingDiscounts.value = false;
    }
  }

  // ============================================================
  // ✅ AUTO-APPLY BEST OFFER (first-booking offer etc.)
  // ============================================================
  DiscountModel? _bestDiscount(List<DiscountModel> list) {
    DiscountModel? best;
    for (final d in list) {
      if (d.discountType == 'percentage' && d.discountValue > 99.0) continue;
      if (!d.isApplicableForPaymentType(selectedPaymentType)) continue;
      final value = d.calculatedDiscount ?? 0;
      if (value <= 0) continue;
      if (best == null || value > (best.calculatedDiscount ?? 0)) best = d;
    }
    return best;
  }

  void _autoApplyBestDiscounts() {
    // Same rule as the offers section: offers need the turf's minimum slots
    if (selectedSlots.length < turf.minSlots) return;

    final admin = _bestDiscount(discountVm.adminDiscounts);
    final partner = _bestDiscount(discountVm.partnerDiscounts);
    if (admin == null && partner == null) return;

    if (admin != null) discountVm.selectAdminDiscount(admin.id);
    if (partner != null) discountVm.selectPartnerDiscount(partner.id);
    _updateDiscountedAmounts();

    // Never auto-apply into a zero / negative amount
    if (_getAmountToPay() <= 0 && admin != null && partner != null) {
      discountVm.selectPartnerDiscount(null);
      _updateDiscountedAmounts();
    }
    if (_getAmountToPay() <= 0) {
      removeAllDiscounts();
      return;
    }

    print('🎁 Auto-applied offer(s): admin=${admin?.id} partner=${partner?.id}');
    _logDiscountApplied(auto: true);
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

  void _logDiscountApplied({bool auto = false}) {
    if (!discountVm.hasSelectedDiscount) return;

    try {
      facebookAppEvents.logEvent(
        name: 'discount_applied',
        parameters: {
          'auto_applied': auto ? '1' : '0',
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

  // ============================================================
  // ✅ SHOW CUSTOM SMALL SNACKBAR
  // ============================================================
  void _showSmallSnackbar(String title, String message, Color color) {
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
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
      animationDuration: const Duration(milliseconds: 400),
      icon: Icon(
        color == Colors.red ? Icons.error_outline : Icons.check_circle,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // ============================================================
  // ✅ PAYMENT ACTION RUNNER (used where no profile check is needed)
  // ============================================================
  // ignore: unused_element
  Future<void> _runPaymentAction(Future<void> Function() bookingAction) async {
    try {
      await bookingAction();
    } catch (e) {
      print('❌ Payment action error: $e');
      _showSmallSnackbar('Error', 'Something went wrong. Please try again.', Colors.red);
    }
  }

  // ============================================================
  // ✅ PROFILE CHECK BEFORE PAYMENT (restored Sep 2026 on request).
  // Shows the "Complete Your Profile" dialog only when the name/email are
  // missing; after saving, the payment continues by itself.
  // ============================================================
  Future<void> _checkProfileAndProceed(Future<void> Function() bookingAction) async {
    // ✅ Prevent duplicate profile checks
    if (_isCheckingProfile) {
      print('⏭️ Profile check already in progress - skipping duplicate');
      return;
    }

    _isCheckingProfile = true;

    try {
      final profileVm = Get.find<ProfileViewModel>();

      // ✅ First, fetch latest profile data
      await profileVm.fetchUser(forceRefresh: true);

      // ✅ Check if profile is complete (name + email)
      if (!profileVm.isProfileCompleteForBooking) {
        final missing = profileVm.getMissingFields();
        // ✅ Store the booking action for later use
        _pendingBookingAction = bookingAction;
        print('📝 Profile incomplete - showing dialog. Pending action stored.');
        await _showProfileRequiredDialog(missing);
        return;
      }

      // ✅ Profile is complete, proceed with booking
      print('✅ Profile complete - proceeding with booking');
      await bookingAction();

    } catch (e) {
      print('❌ Profile check error: $e');
      _showSmallSnackbar(
        'Error',
        'Unable to verify profile. Please try again.',
        Colors.red,
      );
    } finally {
      _isCheckingProfile = false;
    }
  }

  Future<void> _showProfileRequiredDialog(List<String> missing) async {
    final profileVm = Get.find<ProfileViewModel>();
    final nameController = TextEditingController(text: profileVm.name.value);
    final emailController = TextEditingController(text: profileVm.email.value);

    // ✅ Track if dialog is already closed
    bool isDialogClosed = false;

    // ✅ Show dialog and wait for result
    final result = await Get.dialog<bool>(
      PopScope(
        canPop: true,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.person, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Complete Your Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please provide the following details to continue with your booking:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              if (missing.contains('name'))
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              if (missing.contains('email')) ...[
                if (missing.contains('name')) const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'This information is required to confirm your booking',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!isDialogClosed) {
                  isDialogClosed = true;
                  Get.back(result: false);
                }
              },
              child: const Text('Cancel'),
            ),
            Obx(() {
              final profileVm2 = Get.find<ProfileViewModel>();
              return ElevatedButton(
                onPressed: profileVm2.isUpdating.value
                    ? null
                    : () async {
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();

                  if (name.isEmpty || email.isEmpty) {
                    _showSmallSnackbar(
                      'Error',
                      'Please fill all required fields',
                      Colors.red,
                    );
                    return;
                  }

                  if (!email.contains('@')) {
                    _showSmallSnackbar(
                      'Error',
                      'Please enter a valid email address',
                      Colors.red,
                    );
                    return;
                  }

                  // ✅ Update profile
                  print('📤 Updating profile: name=$name, email=$email');
                  final success = await profileVm2.updateProfileForBooking(
                    name: name,
                    email: email,
                  );

                  if (success) {
                    print('✅ Profile updated successfully - closing dialog');
                    // ✅ Close dialog immediately after success
                    if (!isDialogClosed) {
                      isDialogClosed = true;
                      // ✅ Force close the dialog
                      if (Get.isDialogOpen ?? false) {
                        Get.back(result: true);
                      }
                    }
                  } else {
                    _showSmallSnackbar(
                      'Error',
                      'Failed to update profile. Please try again.',
                      Colors.red,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: profileVm2.isUpdating.value
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Save & Continue'),
              );
            }),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    print('📝 Dialog closed with result: $result');

    // ✅ If profile was updated successfully, proceed with booking
    if (result == true) {
      final action = _pendingBookingAction;
      _pendingBookingAction = null;
      if (action != null) {
        print('✅ Executing pending booking action...');
        await action();
      } else {
        print('⚠️ No pending booking action found!');
      }
    } else {
      print('⚠️ Dialog result was false or null - booking cancelled');
      _pendingBookingAction = null;
    }
  }

  // ============================================================
  // ✅ WALLET PAYMENT WITH PROFILE CHECK
  // ============================================================
  Future<void> initiateWalletPayment() async {
    // ✅ New users are asked for name/email first (as in the original flow);
    //    for completed profiles it goes straight to payment.
    await _checkProfileAndProceed(() async {
      // ✅ Prevent duplicate wallet payment calls
      if (_isWalletPaymentInProgress) {
        print('⏭️ Wallet payment already in progress - skipping duplicate');
        return;
      }

      final token = SharedPrefsHelper.getToken();
      if (token == null || token.isEmpty) {
        _showSmallSnackbar(
          'Login Required',
          'Please login to complete booking',
          Colors.red,
        );
        return;
      }

      if (!SharedPrefsHelper.isTokenValid()) {
        _showSmallSnackbar(
          'Session Expired',
          'Please login again',
          Colors.red,
        );
        await SharedPrefsHelper.clearToken();
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      _isWalletPaymentInProgress = true;

      final profileVm = Get.find<ProfileViewModel>();
      await profileVm.fetchUser();

      final amountToPay = _getAmountToPay();
      MetaEvents.paymentInitiated(
        turf: turf,
        method: 'wallet',
        amount: amountToPay,
        paymentType: selectedPaymentType,
      );

      if (amountToPay <= 0) {
        _isWalletPaymentInProgress = false;
        _showSmallSnackbar(
          'Invalid Amount',
          'Amount cannot be zero or negative',
          Colors.red,
        );
        return;
      }

      if (profileVm.walletBalance.value < amountToPay) {
        _isWalletPaymentInProgress = false;
        _showSmallSnackbar(
          'Insufficient Balance',
          'Balance: ₹${_formatPrice(profileVm.walletBalance.value)}',
          Colors.red,
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
          AppConfig.walletBook,
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
            String errorMsg = data['message'] ?? 'Please try again.';
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
          _showWalletError('Please try again.');
        }
      } finally {
        _isWalletPaymentInProgress = false;
      }
    });
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

  // ✅ FIXED: Wallet success with UI locked until navigation completes
  void _handleWalletSuccess() {
    paymentSuccessConfirmed.value = true;

    // ✅ LOG THE BOOKING SUCCESS EVENT TO META
    final amountPaid = _getAmountToPay();
    _logBookingSuccessEvent(method: 'wallet', amountPaid: amountPaid);

    // ✅ Show success dialog only if not shown yet
    if (!hasShownSuccessPopup.value) {
      hasShownSuccessPopup.value = true;
      _showWalletSuccessDialog();
    }

    // ✅ Use a single post-payment processing method
    _processPostPayment();
  }

  // ✅ NEW: Single post-payment processing with duplicate prevention
  Future<void> _processPostPayment() async {
    if (_isPostPaymentProcessing) {
      print('⏭️ Post-payment processing already in progress - skipping duplicate');
      return;
    }

    _isPostPaymentProcessing = true;

    try {
      // ✅ Fetch profile only once
      if (!_isProfileFetchInProgress) {
        _isProfileFetchInProgress = true;
        await Get.find<ProfileViewModel>().fetchUser(forceRefresh: true);
        _isProfileFetchInProgress = false;
      }

      // ✅ Refresh bookings only once
      if (!_isBookingRefreshInProgress) {
        _isBookingRefreshInProgress = true;
        if (Get.isRegistered<BookingViewModel>()) {
          await Get.find<BookingViewModel>().refreshBookings();
        }
        _isBookingRefreshInProgress = false;
      }

    } catch (e) {
      print('❌ Post-payment processing error: $e');
    } finally {
      _isPostPaymentProcessing = false;
    }
  }

  void _showWalletError(String message) {
    MetaEvents.paymentFailed(
      turf: turf,
      method: 'wallet',
      amount: _getAmountToPay(),
      reason: message,
    );
    isUILocked.value = false;
    isLoading.value = false;
    _isWalletPaymentInProgress = false;
    _isPostPaymentProcessing = false;
    _showSmallSnackbar(
      'Payment Failed',
      message,
      Colors.red,
    );
  }

  // ✅ FIXED: Success dialog with booking count display
  void _showWalletSuccessDialog() {
    if (_isSuccessDialogShown || (Get.isDialogOpen ?? false)) {
      print('⏭️ Success dialog already showing - skipping duplicate');
      return;
    }

    _isSuccessDialogShown = true;
    final amountPaid = _getAmountToPay();
    final int bookingCount = SharedPrefsHelper.getBookingCount();

    Get.dialog(
      PopScope(
        canPop: false, // ✅ COMPLETELY BLOCKS BACK BUTTON
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                '🎉 Payment Successful!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '₹',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    TextSpan(
                      text: _formatPrice(amountPaid),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (discountVm.hasSelectedDiscount)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Total Discount: ₹${_formatPrice(discountVm.totalDiscountAmount)}',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                  ),
                ),
              // ✅ Show booking count
              const SizedBox(height: 8),
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
                        // ✅ Lock UI while navigating
                        isUILocked.value = true;
                        Get.back();
                        Get.offAllNamed(AppRoutes.mainPage);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (Get.isRegistered<MainPageViewModel>()) {
                            Get.find<MainPageViewModel>().changeTab(0);
                          }
                          // ✅ Unlock after navigation is complete
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            isUILocked.value = false;
                            isLoading.value = false;
                            _isSuccessDialogShown = false;
                          });
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
                        // ✅ Lock UI while navigating
                        isUILocked.value = true;
                        Get.back();
                        Get.offAllNamed(AppRoutes.mainPage);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (Get.isRegistered<MainPageViewModel>()) {
                            Get.find<MainPageViewModel>().changeTab(1);
                          }
                          // ✅ Unlock after navigation is complete
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            isUILocked.value = false;
                            isLoading.value = false;
                            _isSuccessDialogShown = false;
                          });
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
      barrierDismissible: false, // ✅ Prevents tap outside to dismiss
    ).whenComplete(() {
      // ✅ Only reset if not already handled by button press
      if (!_isNavigating) {
        _isSuccessDialogShown = false;
      }
    });
  }

  // ============================================================
  // ✅ RAZORPAY PAYMENT WITH PROFILE CHECK
  // ============================================================
  Future<void> initiatePayment() async {
    // ✅ New users are asked for name/email first (as in the original flow);
    //    once saved, Razorpay opens directly - no confirm popup.
    await _checkProfileAndProceed(() async {
      if (_isProcessing) return;

      final amountToPay = _getAmountToPay();

      if (amountToPay <= 0) {
        _showSmallSnackbar(
          'Invalid Amount',
          'Amount cannot be zero or negative',
          Colors.red,
        );
        return;
      }

      _isProcessing = true;
      isLoading.value = true;
      isUILocked.value = true;

      // 📊 Meta: pay tapped (online / UPI)
      MetaEvents.paymentInitiated(
        turf: turf,
        method: 'online',
        amount: amountToPay,
        paymentType: selectedPaymentType,
      );

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
          AppConfig.initiateBooking,
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
            _showSmallSnackbar('Error', errorMsg, Colors.red);
            isLoading.value = false;
            isUILocked.value = false;
            _isProcessing = false;
          }
        } else {
          String errorMsg = 'Payment initiation failed';
          if (response.data != null && response.data['message'] != null) {
            errorMsg = response.data['message'];
          }
          _showSmallSnackbar('Payment Error', errorMsg, Colors.red);
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
        _showSmallSnackbar('Payment Error', errorMsg, Colors.red);
        isLoading.value = false;
        isUILocked.value = false;
        _isProcessing = false;
      } catch (e) {
        print('❌ Initiate Payment Error: $e');
        _showSmallSnackbar('Error', 'Something went wrong. Please try again.', Colors.red);
        isLoading.value = false;
        isUILocked.value = false;
        _isProcessing = false;
      }
    });
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
      'timeout': 120,
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
      _showSmallSnackbar('Error', 'Could not open payment gateway', Colors.red);
      isLoading.value = false;
      isPaymentInitiated.value = false;
      isUILocked.value = false;
      _isProcessing = false;
    }
  }

  // ✅ FIXED: Payment success with UI locked until navigation completes
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

    // ✅ LOG THE BOOKING SUCCESS EVENT TO META WITH PAYMENT DETAILS
    _logBookingSuccessEvent(
      method: 'online',
      amountPaid: amountPaid,
      paymentId: response.paymentId,
      orderId: response.orderId ?? _currentOrderId,
    );

    try {
      // Same JSON shape the backend has always accepted
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

      // ✅ Confirm is sent ONCE per Razorpay order - never in a loop.
      final String orderKey =
          (_currentOrderId ?? response.orderId ?? response.paymentId ?? '').toString();
      final bool alreadySent = orderKey.isNotEmpty && !_confirmedOrderIds.add(orderKey);

      if (alreadySent) {
        print('⏭️ Confirm already sent for $orderKey - not calling the API again');
      } else {
        await _confirmBookingOnce(confirmData, amountPaid);
      }
    } catch (e) {
      print('⚠️ Confirm preparation error: $e');
    }

    // ✅ Show success dialog - UI remains LOCKED
    if (!hasShownSuccessPopup.value) {
      hasShownSuccessPopup.value = true;
      _showWalletSuccessDialog();
    }

    // ✅ Process post-payment in background while UI stays locked
    await _processPostPayment();

    // ✅ UI will be unlocked when user clicks a button in the dialog
    // The dialog buttons handle the navigation and unlocking
  }

  // ✅ FIXED: Payment error - unlock immediately
  void _handlePaymentError(PaymentFailureResponse response) async {
    print('=== ❌ PAYMENT ERROR ===');
    print('Code: ${response.code}');
    print('Message: ${response.message}');

    if (_paymentSuccessReceived || paymentSuccessConfirmed.value) {
      print('Payment already successful - ignoring error');
      return;
    }

    // 📊 Meta: payment failed / cancelled
    MetaEvents.paymentFailed(
      turf: turf,
      method: 'online',
      amount: _currentPayableAmount ?? _getAmountToPay(),
      reason: response.code == Razorpay.PAYMENT_CANCELLED
          ? 'user_cancelled'
          : response.code == Razorpay.NETWORK_ERROR
              ? 'network_error'
              : (response.message ?? 'unknown'),
      code: response.code?.toString(),
    );

    // ✅ Unlock UI immediately on error so user can retry
    isPaymentInitiated.value = false;
    isLoading.value = false;
    isUILocked.value = false;
    _isProcessing = false;

    if (response.code != 0) {
      // ✅ Show error after a small delay
      Future.delayed(const Duration(seconds: 3), () {
        _showSmallSnackbar(
          'Payment Failed',
          'Please try again. The slot will be unlocked after 120 seconds.',
          Colors.red,
        );
      });
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