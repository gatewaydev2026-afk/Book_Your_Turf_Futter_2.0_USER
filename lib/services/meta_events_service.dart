// lib/services/meta_events_service.dart
// ============================================================
// ✅ ONE PLACE FOR ALL META (FACEBOOK) APP EVENTS
// ------------------------------------------------------------
// Funnel (as per "BYT Funnel Leakages & Fixes", Sep 2026):
//   Home screen      → home_view                        (custom)
//   Home search      → fb_mobile_search                 (standard)
//   Turf details     → fb_mobile_content_view (ViewContent) (standard) ← NEW
//   Slot screen open → slot_view                        (custom)    ← NEW
//   Slot tap         → fb_mobile_add_to_cart            (standard)  ← NEW
//   Booking summary  → fb_mobile_initiated_checkout     (standard)  ← RENAMED (was view_content)
//   Pay tap          → payment_initiated                (custom)    ← NEW
//   Payment failed   → payment_failed                   (custom)    ← NEW
//   Send OTP         → otp_requested (user_type new/existing)  (custom) ← NEW
//   Verify OTP       → new user:      fb_mobile_complete_registration + new_user_signup
//                      existing user: existing_user_login           (custom) ← NEW
//   (new / existing comes from send-otp  data.is_registered:
//    true = old user, false = new user)
//   Booking success  → fb_mobile_purchase (+ payment_method, counts)
//                      + wallet_booking_success / online_booking_success
//   Booking history  → booking_history_view (+ total / upcoming / cancelled)
//   Balance payment  → balance_payment_success / balance_payment_failed
//   Cancel booking   → booking_cancelled
//   Wallet recharge  → wallet_recharge_initiated / _success / _failed
//   Favourite        → fb_mobile_add_to_wishlist / favorite_removed
//   Dashboard etc.   → dashboard_view, wallet_history_view, coin_history_view,
//                      notifications_view, app_shared
//
// ⚠️ SAFETY: every method here catches its own errors and nothing in the app
//    awaits them in a payment/UI path → Meta can never crash or slow the app.
//
// Every screen event also carries `visit_count` = how many times THIS
// device opened that screen. In Meta Events Manager you get:
//   • Total events  → how many visits
//   • Unique users  → how many people came
// No personal data (phone / email / name) is ever sent to Meta.
// ============================================================

import 'dart:convert';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/slot_model.dart';
import '../models/turf_model.dart';
import 'facebook_events.dart';

class MetaEvents {
  MetaEvents._();

  // ---- Standard Meta event names ----
  // (taken from the facebook_app_events plugin so they always match Meta)
  static const String evViewContent = FacebookAppEvents.eventNameViewedContent; // fb_mobile_content_view
  static const String evAddToCart = FacebookAppEvents.eventNameAddedToCart; // fb_mobile_add_to_cart
  static const String evInitiatedCheckout = FacebookAppEvents.eventNameInitiatedCheckout; // fb_mobile_initiated_checkout
  static const String evCompleteRegistration = FacebookAppEvents.eventNameCompletedRegistration; // fb_mobile_complete_registration
  static const String evSearch = 'fb_mobile_search'; // standard Search (no constant in plugin 0.19.7)

  // ---- Custom event names ----
  static const String evHomeView = 'home_view';
  static const String evSlotView = 'slot_view';
  static const String evPaymentInitiated = 'payment_initiated';
  static const String evPaymentFailed = 'payment_failed';

  // ---- Booking counter keys (per device / install) ----
  static const String _kBookTotal = 'meta_count_booking_total';
  static const String _kBookWallet = 'meta_count_booking_wallet';
  static const String _kBookOnline = 'meta_count_booking_online';
  static const String _kBalanceWallet = 'meta_count_balance_wallet';
  static const String _kBalanceOnline = 'meta_count_balance_online';
  static const String _kCancel = 'meta_count_booking_cancelled';
  static const String _kRecharge = 'meta_count_wallet_recharge';
  static const String _kHistory = 'meta_count_history_view';

  // one purchase event per payment id / order – never twice
  static final Set<String> _loggedPurchaseKeys = <String>{};

  // ---- Counter keys (per device) ----
  static const String _kHome = 'meta_count_home_view';
  static const String _kTurf = 'meta_count_turf_view';
  static const String _kSlot = 'meta_count_slot_view';
  static const String _kSummary = 'meta_count_summary_view';

  // Home is kept alive in an IndexedStack, so only count it again
  // after this gap (avoids counting every app resume twice).
  static const Duration _homeThrottle = Duration(minutes: 10);
  static DateTime? _lastHomeLog;

  // ============================================================
  // Helpers
  // ============================================================
  static Future<int> _bump(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(key) ?? 0) + 1;
      await prefs.setInt(key, next);
      return next;
    } catch (_) {
      return 1;
    }
  }

  static Future<int> getCount(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  }

  static Future<int> get homeViewCount => getCount(_kHome);
  static Future<int> get turfViewCount => getCount(_kTurf);
  static Future<int> get slotViewCount => getCount(_kSlot);
  static Future<int> get summaryViewCount => getCount(_kSummary);

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Meta only accepts String / num values in parameters – clean the map.
  /// Lists / maps are JSON-encoded (newer plugin versions throw on them).
  static Map<String, dynamic> clean(Map<String, dynamic> params) {
    final out = <String, dynamic>{};
    params.forEach((k, v) {
      if (v == null) return;
      if (v is num || v is String) {
        out[k] = v;
      } else if (v is bool) {
        out[k] = v ? '1' : '0';
      } else if (v is List || v is Map) {
        out[k] = jsonEncode(v);
      } else {
        out[k] = v.toString();
      }
    });
    return out;
  }

  static Future<void> _log(
    String name,
    Map<String, dynamic> params, {
    double? valueToSum,
  }) async {
    try {
      await facebookAppEvents.logEvent(
        name: name,
        parameters: clean(params),
        valueToSum: valueToSum,
      );
      print('📊 [META] $name → $params ${valueToSum != null ? '(₹$valueToSum)' : ''}');
    } catch (e) {
      print('❌ [META] $name failed: $e');
    }
  }

  static Map<String, dynamic> _turfParams(TurfModel turf) {
    try {
      return {
        'turf_id': turf.id.toString(),
        'turf_name': turf.name,
        'city': turf.district,
        'state': turf.state,
        'sport': turf.gameType,
      };
    } catch (_) {
      return {'turf_id': turf.id.toString()};
    }
  }

  /// Runs an event body and swallows ANY error (bad data, SDK, prefs…).
  static Future<void> _safe(String name, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      print('❌ [META] $name skipped: $e');
    }
  }

  static double _round2(double v) =>
      v.isFinite ? double.parse(v.toStringAsFixed(2)) : 0;

  // ============================================================
  // 1. HOME SCREEN
  // ============================================================
  static Future<void> homeView({
    required bool isGuest,
    String? locationLabel,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastHomeLog != null &&
        now.difference(_lastHomeLog!) < _homeThrottle) {
      return;
    }
    _lastHomeLog = now;

    final count = await _bump(_kHome);
    await _log(evHomeView, {
      'screen': 'home',
      'user_type': isGuest ? 'guest' : 'logged_in',
      'location_label': locationLabel ?? '',
      'visit_count': count,
      'visit_date': _today(),
    });
  }

  /// Home search (API search button / keyboard enter / suggestion tap)
  static Future<void> search({
    required String query,
    required int resultCount,
  }) async {
    await _log(evSearch, {
      'fb_search_string': query,
      'fb_content_type': 'turf',
      'fb_success': resultCount > 0 ? 1 : 0,
      'result_count': resultCount,
    });
  }

  // ============================================================
  // 2. TURF DETAILS SCREEN  → View Content
  // ============================================================
  static Future<void> turfView(TurfModel turf, {String source = 'home'}) async {
    final count = await _bump(_kTurf);
    await _log(
      evViewContent,
      {
        // standard (Meta reads these)
        'fb_content_type': 'turf',
        'fb_content_id': turf.id.toString(),
        'fb_currency': 'INR',
        // readable copies (as per the tracking sheet)
        'content_type': 'turf',
        'content_id': turf.id.toString(),
        'content_name': turf.name,
        'content_category': turf.gameType,
        'currency': 'INR',
        ..._turfParams(turf),
        'source': source,
        'visit_count': count,
        'visit_date': _today(),
      },
    );
  }

  // ============================================================
  // 3. SLOT SCREEN
  // ============================================================
  static Future<void> slotView(TurfModel turf) async {
    final count = await _bump(_kSlot);
    await _log(evSlotView, {
      'screen': 'slot_selection',
      ..._turfParams(turf),
      'visit_count': count,
      'visit_date': _today(),
    });
  }

  /// Slot tapped (selected, not de-selected) → Add to Cart
  static Future<void> slotSelected({
    required TurfModel turf,
    required SlotModel slot,
    required String paymentType,
    required DateTime date,
    required int courtNumber,
    required int selectedCount,
  }) async {
    final amount = slot.priceAsDouble;
    await _log(
      evAddToCart,
      {
        'fb_content_type': 'turf_slot',
        'fb_content_id': turf.id.toString(),
        'fb_currency': 'INR',
        'fb_num_items': selectedCount,
        'content_type': 'turf_slot',
        'content_id': turf.id.toString(),
        'content_name': turf.name,
        'content_category': turf.gameType,
        'currency': 'INR',
        'num_items': selectedCount,
        ..._turfParams(turf),
        'slot_time': '${slot.startTime}-${slot.endTime}',
        'slot_date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'court_number': courtNumber,
        'amount': amount,
        'payment_type': paymentType,
      },
      valueToSum: amount,
    );
  }

  // ============================================================
  // 4. BOOKING SUMMARY  → Initiated Checkout
  // ============================================================
  static Future<void> initiatedCheckout({
    required TurfModel turf,
    required int slotsCount,
    required String paymentType,
    required double totalAmount,
    required double payableAmount,
    required String date,
    required int courtNumber,
  }) async {
    final count = await _bump(_kSummary);
    // ✅ How many bookings this user has completed so far (sent to Meta only,
    //    never shown in the app UI). Lets you split checkout events into
    //    first-time bookers vs repeat customers.
    final bookings = await getCount(_kBookTotal);
    final walletBookings = await getCount(_kBookWallet);
    final onlineBookings = await getCount(_kBookOnline);
    await _log(
      evInitiatedCheckout,
      {
        'fb_content_type': 'turf_booking_summary',
        'fb_content_id': turf.id.toString(),
        'fb_currency': 'INR',
        'fb_num_items': slotsCount,
        'fb_payment_info_available': 0,
        'content_type': 'turf_booking_summary',
        'content_id': turf.id.toString(),
        'content_name': turf.name,
        'content_category': turf.gameType,
        'currency': 'INR',
        'num_items': slotsCount,
        ..._turfParams(turf),
        'payment_type': paymentType,
        'booking_type': paymentType,
        'payable_amount': payableAmount,
        'slot_date': date,
        'court_number': courtNumber,
        'visit_count': count,
        'visit_date': _today(),
        // user's overall booking history (Meta only – not displayed anywhere)
        'user_booking_count': bookings,
        'booking_count': bookings,
        'wallet_booking_count': walletBookings,
        'online_booking_count': onlineBookings,
        'is_first_booking': bookings == 0 ? 1 : 0,
        'customer_type': bookings == 0 ? 'first_time' : 'repeat',
      },
      valueToSum: totalAmount,
    );
  }

  // ============================================================
  // 5. PAYMENT
  // ============================================================
  static Future<void> paymentInitiated({
    required TurfModel turf,
    required String method, // 'online' | 'wallet'
    required double amount,
    required String paymentType,
  }) async {
    await _log(
      evPaymentInitiated,
      {
        ..._turfParams(turf),
        'payment_method': method,
        'payment_type': paymentType,
        'fb_currency': 'INR',
        'amount': amount,
        'user_booking_count': await getCount(_kBookTotal),
        'customer_type': (await getCount(_kBookTotal)) == 0 ? 'first_time' : 'repeat',
      },
      valueToSum: amount,
    );
  }

  static Future<void> paymentFailed({
    required TurfModel turf,
    required String method,
    required double amount,
    required String reason,
    String? code,
  }) async {
    final safeReason = reason.length > 90 ? reason.substring(0, 90) : reason;
    await _log(evPaymentFailed, {
      ..._turfParams(turf),
      'payment_method': method,
      'fb_currency': 'INR',
      'amount': amount,
      'reason': safeReason,
      'error_code': code ?? '',
    });
  }

  // ============================================================
  // 5b. BOOKING SUCCESS – wallet vs online, with counts
  // ============================================================
  /// [method] must be 'wallet' or 'online'.
  static Future<void> bookingSuccess({
    required TurfModel turf,
    required String method,
    required String paymentType,
    required double amountPaid,
    required double totalAmount,
    required int slotsCount,
    required String date,
    required int courtNumber,
    String? paymentId,
    String? orderId,
    double discountAmount = 0,
    int? adminDiscountId,
    int? partnerDiscountId,
  }) =>
      _safe('booking_success', () async {
        final isWallet = method == 'wallet';
        final dedupeKey = paymentId ?? orderId ??
            '${turf.id}|$date|$courtNumber|$slotsCount|${_round2(amountPaid)}|${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
        if (!_loggedPurchaseKeys.add(dedupeKey)) {
          print('⏭️ [META] purchase already logged for $dedupeKey');
          return;
        }

        final total = await _bump(_kBookTotal);
        final methodCount = await _bump(isWallet ? _kBookWallet : _kBookOnline);
        final walletCount = isWallet ? methodCount : await getCount(_kBookWallet);
        final onlineCount = isWallet ? await getCount(_kBookOnline) : methodCount;
        final amount = _round2(amountPaid);

        final common = <String, dynamic>{
          ..._turfParams(turf),
          'payment_method': isWallet ? 'wallet' : 'online',
          'payment_type': paymentType, // advance / full
          'booking_type': paymentType,
          'slots_count': slotsCount,
          'slot_date': date,
          'court_number': courtNumber,
          'amount_paid': amount,
          'total_amount': _round2(totalAmount),
          'discount_amount': _round2(discountAmount),
          'booking_count': total, // all bookings from this device
          'total_bookings': total,
          'wallet_booking_count': walletCount,
          'online_booking_count': onlineCount,
          'is_first_booking': total == 1 ? 1 : 0,
          'booking_date': _today(),
        };
        if (adminDiscountId != null) common['admin_discount_id'] = adminDiscountId.toString();
        if (partnerDiscountId != null) common['partner_discount_id'] = partnerDiscountId.toString();

        // 1) Standard Purchase (ads / ROAS)
        await _log(
          'fb_mobile_purchase',
          {
            'fb_content_type': 'turf_booking',
            'fb_content_id': turf.id.toString(),
            'fb_currency': 'INR',
            'fb_num_items': slotsCount,
            if (orderId != null) 'fb_order_id': orderId,
            if (paymentId != null) 'payment_id': paymentId,
            'content_ids': [turf.id.toString()],
            ...common,
          },
          valueToSum: amount,
        );

        // 2) Separate custom event per payment method → easy counting
        await _log(
          isWallet ? 'wallet_booking_success' : 'online_booking_success',
          {
            'fb_currency': 'INR',
            ...common,
            'method_booking_count': methodCount,
          },
          valueToSum: amount,
        );
      });

  /// Razorpay paid but our confirm API failed – important to watch.
  static Future<void> bookingConfirmFailed({
    required TurfModel turf,
    required double amount,
    required String reason,
    String? orderId,
  }) =>
      _safe('booking_confirm_failed', () async {
        await _log('booking_confirm_failed', {
          ..._turfParams(turf),
          'fb_currency': 'INR',
          'amount': _round2(amount),
          'reason': reason.length > 90 ? reason.substring(0, 90) : reason,
          'order_id': orderId ?? '',
        });
      });

  // ============================================================
  // 5c. BOOKING HISTORY / BALANCE / CANCEL
  // ============================================================
  static Future<void> bookingHistoryView({
    required int totalBookings,
    required int upcoming,
    required int cancelled,
    required int pendingPayment,
  }) =>
      _safe('booking_history_view', () async {
        final count = await _bump(_kHistory);
        await _log('booking_history_view', {
          'screen': 'booking_history',
          'total_bookings': totalBookings,
          'upcoming_bookings': upcoming,
          'cancelled_bookings': cancelled,
          'pending_payment_bookings': pendingPayment,
          'has_bookings': totalBookings > 0 ? 1 : 0,
          'wallet_booking_count': await getCount(_kBookWallet),
          'online_booking_count': await getCount(_kBookOnline),
          'visit_count': count,
          'visit_date': _today(),
        });
      });

  /// [method] 'wallet' or 'online'
  static Future<void> balancePaymentSuccess({
    required int bookingId,
    required String method,
    required double amount,
  }) =>
      _safe('balance_payment_success', () async {
        final isWallet = method == 'wallet';
        final count = await _bump(isWallet ? _kBalanceWallet : _kBalanceOnline);
        await _log(
          'balance_payment_success',
          {
            'booking_id': bookingId.toString(),
            'payment_method': isWallet ? 'wallet' : 'online',
            'fb_currency': 'INR',
            'amount': _round2(amount),
            'balance_payment_count': count,
          },
          valueToSum: _round2(amount),
        );
      });

  static Future<void> balancePaymentFailed({
    required int? bookingId,
    required String method,
    required double amount,
    required String reason,
  }) =>
      _safe('balance_payment_failed', () async {
        await _log('balance_payment_failed', {
          'booking_id': bookingId?.toString() ?? '',
          'payment_method': method,
          'fb_currency': 'INR',
          'amount': _round2(amount),
          'reason': reason.length > 90 ? reason.substring(0, 90) : reason,
        });
      });

  static Future<void> bookingCancelled({
    required int bookingId,
    String? turfName,
    double? refundAmount,
  }) =>
      _safe('booking_cancelled', () async {
        final count = await _bump(_kCancel);
        await _log('booking_cancelled', {
          'booking_id': bookingId.toString(),
          'turf_name': turfName ?? '',
          'fb_currency': 'INR',
          'refund_amount': _round2(refundAmount ?? 0),
          'cancel_count': count,
        });
      });

  // ============================================================
  // 5d. WALLET RECHARGE
  // ============================================================
  static Future<void> walletRecharge({
    required String status, // initiated | success | failed
    required double amount,
    String? reason,
  }) =>
      _safe('wallet_recharge_$status', () async {
        final params = <String, dynamic>{
          'fb_currency': 'INR',
          'amount': _round2(amount),
        };
        if (status == 'success') {
          params['recharge_count'] = await _bump(_kRecharge);
        }
        if (reason != null) {
          params['reason'] = reason.length > 90 ? reason.substring(0, 90) : reason;
        }
        await _log('wallet_recharge_$status', params,
            valueToSum: status == 'success' ? _round2(amount) : null);
      });

  // ============================================================
  // 5e. FAVOURITES / SCREENS / SHARE
  // ============================================================
  static Future<void> favoriteChanged({
    required int turfId,
    required String turfName,
    required bool added,
  }) =>
      _safe('favorite', () async {
        await _log(
          added ? 'fb_mobile_add_to_wishlist' : 'favorite_removed',
          {
            'fb_content_type': 'turf',
            'fb_content_id': turfId.toString(),
            'fb_currency': 'INR',
            'turf_id': turfId.toString(),
            'turf_name': turfName,
          },
        );
      });

  static final Map<String, DateTime> _lastScreenLog = {};

  /// Throttled (30s per screen) so rebuilds of stateless screens don't
  /// count as new visits.
  static Future<void> screenView(String screen, [Map<String, dynamic>? extra]) =>
      _safe('${screen}_view', () async {
        final now = DateTime.now();
        final last = _lastScreenLog[screen];
        if (last != null && now.difference(last) < const Duration(seconds: 30)) return;
        _lastScreenLog[screen] = now;
        final count = await _bump('meta_count_${screen}_view');
        await _log('${screen}_view', {
          'screen': screen,
          ...?extra,
          'visit_count': count,
          'visit_date': _today(),
        });
      });

  static Future<void> appShared({required String type}) =>
      _safe('app_shared', () async {
        await _log('app_shared', {'share_type': type});
      });

  // ============================================================
  // 6. PHONE LOGIN – NEW vs EXISTING USER
  //    Based on send-otp response  data.is_registered
  //    true  → existing (old) user
  //    false → new user
  // ============================================================
  static const String evOtpRequested = 'otp_requested';
  static const String evNewUserSignup = 'new_user_signup';
  static const String evExistingUserLogin = 'existing_user_login';

  static String userTypeOf(bool isRegistered) =>
      isRegistered ? 'existing_user' : 'new_user';

  /// Send-OTP success. Meta Events Manager → filter by `user_type`
  /// to see how many new vs old numbers reached the OTP step.
  static Future<void> otpRequested({
    required bool isRegistered,
    required bool isResend,
  }) async {
    await _log(evOtpRequested, {
      'user_type': userTypeOf(isRegistered),
      'is_registered': isRegistered ? 1 : 0,
      'is_resend': isResend ? 1 : 0,
      'method': 'phone_otp',
    });
  }

  /// OTP verified → user is now logged in.
  /// New user   : fb_mobile_complete_registration (for ads) + new_user_signup
  /// Old user   : existing_user_login
  static Future<void> otpVerified({required bool isRegistered}) async {
    if (isRegistered) {
      await _log(evExistingUserLogin, {
        'user_type': 'existing_user',
        'is_registered': 1,
        'method': 'phone_otp',
        'visit_date': _today(),
      });
    } else {
      await completeRegistration(method: 'phone_otp');
      await _log(evNewUserSignup, {
        'user_type': 'new_user',
        'is_registered': 0,
        'method': 'phone_otp',
        'visit_date': _today(),
      });
    }
  }

  // ============================================================
  // 7. REGISTRATION (first-time phone number)
  // ============================================================
  static Future<void> completeRegistration({String method = 'phone_otp'}) async {
    await _log(evCompleteRegistration, {
      'fb_registration_method': method,
      'fb_success': 1,
    });
  }
}
