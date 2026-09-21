// lib/services/otp_autofill_service.dart
// ============================================================
// ✅ OTP AUTO-READ WITH APP SIGNATURE (Google SMS Retriever API)
// ------------------------------------------------------------
// How it works
//  1. App gets its 11-character app signature hash (getAppHash()).
//  2. The hash is sent to the backend with send-otp  →  "app_hash".
//  3. Backend puts that hash at the END of the OTP SMS, e.g.
//        Your BookYourTurf OTP is 123456. Valid for 5 minutes.
//        FA+9qCX9VSu
//  4. Android hands that SMS directly to THIS app (no permission,
//     no popup) → OTP is filled and verified automatically.
//
// • The listener is started BEFORE send-otp is called, so an SMS that
//   arrives very fast is not missed.
// • Debug and release (Play Store) builds have DIFFERENT hashes – that's
//   why the app sends its own hash every time instead of hard-coding it.
// • If the hash cannot be read (or AppConfig.useSmsRetriever = false) the
//   OTP screen falls back to the old SMS User Consent popup.
// • Every call here is wrapped – OTP reading can never crash the app.
// ============================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:smart_auth/smart_auth.dart';

import '../config/app_config.dart';

class OtpAutofillService {
  OtpAutofillService._();

  static final SmartAuth _smartAuth = SmartAuth.instance;
  static final RegExp _hashPattern = RegExp(r'^[A-Za-z0-9+/]{11}$');

  static String? _appHash;
  static Future<String?>? _hashFuture;

  static Future<SmartAuthResult<SmartAuthSms>>? _retrieverFuture;
  static int _session = 0;

  static bool get _supported =>
      !kIsWeb && Platform.isAndroid && AppConfig.useSmsRetriever;

  /// Cached app hash (null until loaded / on iOS).
  static String? get appHash => _appHash;

  /// True when the SMS Retriever flow is active for the current OTP.
  static bool get isRetrieverActive => _retrieverFuture != null;

  // ------------------------------------------------------------
  // 1. APP SIGNATURE HASH
  // ------------------------------------------------------------
  static Future<String?> getAppHash() {
    if (!_supported) return Future.value(null);
    if (_appHash != null) return Future.value(_appHash);
    return _hashFuture ??= _loadHash();
  }

  static Future<String?> _loadHash() async {
    try {
      final res = await _smartAuth
          .getAppSignature()
          .timeout(const Duration(seconds: 3));
      final value = res.hasData ? res.requireData.trim() : null;
      if (value != null && _hashPattern.hasMatch(value)) {
        _appHash = value;
        debugPrint('╔══════════════════════════════════════════╗');
        debugPrint('║  📩 SMS APP HASH: $value            ║');
        debugPrint('║  (${kReleaseMode ? 'RELEASE' : 'DEBUG'} build – backend must end the OTP SMS with it)');
        debugPrint('╚══════════════════════════════════════════╝');
        return value;
      }
      debugPrint('⚠️ App hash not available: ${res.error}');
    } catch (e) {
      debugPrint('⚠️ getAppSignature failed: $e');
    }
    _hashFuture = null; // allow a retry next time
    return null;
  }

  // ------------------------------------------------------------
  // 2. START LISTENING (call right BEFORE send-otp / resend)
  // ------------------------------------------------------------
  static Future<void> startListening() async {
    if (!_supported) return;
    _session++;
    try {
      await _smartAuth.removeSmsRetrieverApiListener();
    } catch (_) {}
    try {
      final hash = await getAppHash();
      if (hash == null) {
        _retrieverFuture = null;
        return; // no hash → screen uses User Consent fallback
      }
      // Google listens for 5 minutes (same as OTP validity)
      _retrieverFuture = _smartAuth.getSmsWithRetrieverApi(matcher: r'\d{6}');
      debugPrint('📩 SMS Retriever started (session $_session)');
    } catch (e) {
      debugPrint('⚠️ SMS Retriever start failed: $e');
      _retrieverFuture = null;
    }
  }

  // ------------------------------------------------------------
  // 3. WAIT FOR THE OTP (OTP screen)
  //    Returns the 6-digit OTP, or null (timeout / stopped / error).
  // ------------------------------------------------------------
  static Future<String?> waitForOtp() async {
    final future = _retrieverFuture;
    final mySession = _session;
    if (future == null) return null;
    try {
      final res = await future;
      if (mySession != _session) return null; // a newer OTP was requested
      if (res.hasData) {
        final sms = res.requireData;
        return extractOtp(sms.sms ?? '', sms.code);
      }
      debugPrint('ℹ️ SMS Retriever ended without SMS: ${res.error}');
    } catch (e) {
      debugPrint('⚠️ SMS Retriever error: $e');
    }
    return null;
  }

  // ------------------------------------------------------------
  // 4. STOP (verify done / change number / screen closed)
  // ------------------------------------------------------------
  static Future<void> stop() async {
    _session++;
    _retrieverFuture = null;
    if (!_supported) return;
    try {
      await _smartAuth.removeSmsRetrieverApiListener();
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // OTP extraction (shared with the User Consent fallback)
  // ------------------------------------------------------------
  static String? extractOtp(String smsText, [String? code]) {
    if (code != null && RegExp(r'^\d{6}$').hasMatch(code)) return code;

    // remove the 11-char hash so it can never be mistaken for digits
    final text = smsText.replaceAll(RegExp(r'[A-Za-z0-9+/]{11}\s*$'), ' ');

    const patterns = [
      r'BookYourTurf is (\d{6})',
      r'OTP\s*(?:is|:)?\s*(\d{6})',
      r'code\s*(?:is|:)?\s*(\d{6})',
      r'is\s+(\d{6})',
      r'(?<!\d)(\d{6})(?!\d)',
    ];
    for (final p in patterns) {
      final m = RegExp(p, caseSensitive: false).firstMatch(text);
      final v = m?.group(1);
      if (v != null && v.length == 6) return v;
    }
    return null;
  }
}
