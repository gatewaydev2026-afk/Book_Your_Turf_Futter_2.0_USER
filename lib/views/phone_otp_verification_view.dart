import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:lottie/lottie.dart';
import 'package:smart_auth/smart_auth.dart';

import '../view_models/auth_view_model.dart';
import '../routes/app_routes.dart';

class PhoneOtpVerificationView extends StatefulWidget {
  const PhoneOtpVerificationView({super.key});

  @override
  State<PhoneOtpVerificationView> createState() =>
      _PhoneOtpVerificationViewState();
}

class _PhoneOtpVerificationViewState
    extends State<PhoneOtpVerificationView> {
  final AuthViewModel authVm = Get.find<AuthViewModel>();

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final SmartAuth smartAuth = SmartAuth.instance;

  bool _isVerifying = false;
  bool _isAutoReading = false;
  bool _autoReadFailed = false;

  int _otpRequestId = 0;
  bool _isVerificationComplete = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _otpFocusNode.requestFocus();
      _startNewOtpListener();
    });
  }

  @override
  void dispose() {
    _otpRequestId++;
    _isListening = false;

    try {
      smartAuth.removeUserConsentApiListener();
    } catch (_) {}

    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  // ============================================================
  // START NEW OTP LISTENER
  // ============================================================

  Future<void> _startNewOtpListener() async {
    if (_isListening) {
      print('⏭️ Already listening for OTP');
      return;
    }

    final int currentRequestId = _otpRequestId;

    debugPrint('==========================================');
    debugPrint('STARTING NEW OTP LISTENER');
    debugPrint('REQUEST ID: $currentRequestId');
    debugPrint('==========================================');

    // Remove previous listener first
    try {
      await smartAuth.removeUserConsentApiListener();
    } catch (e) {
      debugPrint('Old listener remove error: $e');
    }

    if (!mounted) return;

    _isListening = true;

    setState(() {
      _isAutoReading = true;
      _autoReadFailed = false;
    });

    try {
      final res = await smartAuth.getSmsWithUserConsentApi();

      _isListening = false;

      if (!mounted) return;

      if (currentRequestId != _otpRequestId) {
        debugPrint('OLD OTP RESULT IGNORED');
        return;
      }

      if (res.hasData) {
        final smsData = res.requireData;

        debugPrint('==========================================');
        debugPrint('✅ SMS RECEIVED');
        debugPrint('REQUEST ID: $currentRequestId');
        debugPrint('SMS: ${smsData.sms}');
        debugPrint('SMART AUTH CODE: ${smsData.code}');
        debugPrint('==========================================');

        String? otp;

        // ✅ FIRST: Get the SMS text
        final smsText = smsData.sms ?? '';
        debugPrint('📝 RAW SMS TEXT: "$smsText"');

        // ✅ SECOND: Try SmartAuth's code
        if (smsData.code != null && smsData.code!.length == 6) {
          otp = smsData.code;
          debugPrint('✅ OTP from SmartAuth: $otp');
        }

        // ✅ THIRD: Extract from SMS using patterns
        if (otp == null || otp.length != 6) {
          final patterns = [
            r'to BookYourTurf is (\d{6})',
            r'BookYourTurf is (\d{6})',
            r'is\s+(\d{6})[.\s]?',
            r'OTP\s*(?:is\s*)?(\d{6})',
            r'code\s*(?:is\s*)?(\d{6})',
            r'verification code\s*(?:is\s*)?(\d{6})',
            r'(?<!\d)(\d{6})(?!\d)',
          ];

          for (final pattern in patterns) {
            final regex = RegExp(pattern, caseSensitive: false);
            final match = regex.firstMatch(smsText);
            if (match != null) {
              final extracted = match.group(1) ?? match.group(0);
              if (extracted?.length == 6 && RegExp(r'^[0-9]+$').hasMatch(extracted!)) {
                otp = extracted;
                debugPrint('✅ OTP extracted using pattern: $otp');
                break;
              }
            }
          }
        }

        // ✅ FOURTH: Find any 6-digit number
        if (otp == null || otp.length != 6) {
          final matches = RegExp(r'(?<!\d)\d{6}(?!\d)').allMatches(smsText);
          if (matches.isNotEmpty) {
            otp = matches.last.group(0);
            debugPrint('✅ OTP found as standalone number: $otp');
          }
        }

        // ✅ FIFTH: Any 6 digits
        if (otp == null || otp.length != 6) {
          final regex = RegExp(r'\d{6}');
          final match = regex.firstMatch(smsText);
          if (match != null) {
            otp = match.group(0);
            debugPrint('✅ OTP found as first 6 digits: $otp');
          }
        }

        if (otp == null || otp.length != 6) {
          debugPrint('❌ Could not extract 6 digit OTP');
          setState(() {
            _isAutoReading = false;
            _autoReadFailed = true;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ℹ️ Please enter OTP manually'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        if (currentRequestId != _otpRequestId) {
          debugPrint('OLD OTP IGNORED BEFORE FILL');
          return;
        }

        // ✅ Fill OTP and verify
        await _setOtpAndVerify(otp, currentRequestId);

      } else if (res.isCanceled) {
        debugPrint('⚠️ SMS USER CONSENT CANCELLED');
        if (currentRequestId == _otpRequestId) {
          setState(() {
            _isAutoReading = false;
            _autoReadFailed = true;
          });
        }
      } else {
        debugPrint('❌ SMS USER CONSENT FAILED: $res');
        if (currentRequestId == _otpRequestId) {
          setState(() {
            _isAutoReading = false;
            _autoReadFailed = true;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ SMS AUTO READ ERROR: $e');
      _isListening = false;
      if (!mounted) return;
      if (currentRequestId != _otpRequestId) return;

      setState(() {
        _isAutoReading = false;
        _autoReadFailed = true;
      });
    }
  }

  // ============================================================
  // SET OTP + AUTO VERIFY
  // ============================================================

  Future<void> _setOtpAndVerify(String otp, int requestId) async {
    if (!mounted) return;

    if (requestId != _otpRequestId) {
      debugPrint('OLD OTP BLOCKED');
      return;
    }

    if (otp.length != 6) return;

    debugPrint('==========================================');
    debugPrint('✅ NEW OTP ACCEPTED');
    debugPrint('REQUEST ID: $requestId');
    debugPrint('OTP: $otp');
    debugPrint('==========================================');

    // ✅ FIX: Set OTP in text field
    _otpController.text = otp;
    _otpController.selection = TextSelection.collapsed(offset: otp.length);

    debugPrint('✅ OTP set in controller: ${_otpController.text}');

    // ✅ Update UI
    setState(() {
      _isAutoReading = false;
      _autoReadFailed = false;
    });

    // ✅ Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ OTP detected automatically!'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ),
      );
    }

    // ✅ Wait for UI to update
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // ✅ Check if still valid
    if (requestId != _otpRequestId) {
      debugPrint('OTP became OLD before verification');
      return;
    }

    // ✅ Auto-verify
    await _handleVerify(otp);
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _handleVerify([String? receivedOtp]) async {
    if (_isVerificationComplete) {
      debugPrint('⏭️ Verification already complete - skipping');
      return;
    }

    if (_isVerifying) return;

    final String otp = (receivedOtp ?? _otpController.text).trim();
    if (otp.length != 6) return;

    final String phone = authVm.phoneNumber.value.trim();
    if (phone.isEmpty) {
      debugPrint('Phone number is empty');
      return;
    }

    setState(() => _isVerifying = true);

    debugPrint('==========================================');
    debugPrint('VERIFYING OTP');
    debugPrint('PHONE: $phone');
    debugPrint('OTP: $otp');
    debugPrint('==========================================');

    try {
      final success = await authVm.verifyPhoneOtp(
        number: phone,
        otp: otp,
      );

      if (success) {
        debugPrint('✅ OTP VERIFICATION SUCCESS');
        _isVerificationComplete = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('❌ OTP VERIFICATION FAILED');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Invalid OTP. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ OTP VERIFICATION ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isVerifying = false);
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> _handleResend() async {
    if (authVm.isLoading.value) return;

    _isVerificationComplete = false;

    debugPrint('==========================================');
    debugPrint('RESEND OTP START');
    debugPrint('==========================================');

    _otpRequestId++;

    debugPrint('NEW REQUEST ID: $_otpRequestId');

    try {
      await smartAuth.removeUserConsentApiListener();
    } catch (e) {
      debugPrint('Listener remove error: $e');
    }

    if (!mounted) return;

    _otpController.clear();

    setState(() {
      _isAutoReading = true;
      _autoReadFailed = false;
      _isVerifying = false;
      _isListening = false;
    });

    try {
      await authVm.resendPhoneOtp();
      debugPrint('NEW OTP REQUEST SENT TO BACKEND');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 New OTP sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('RESEND ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend OTP'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await _startNewOtpListener();

    debugPrint('==========================================');
    debugPrint('RESEND OTP END');
    debugPrint('==========================================');
  }

  // ============================================================
  // CHANGE PHONE
  // ============================================================

  void _changePhoneNumber() {
    _otpRequestId++;
    _isListening = false;

    try {
      smartAuth.removeUserConsentApiListener();
    } catch (_) {}

    authVm.resetPhoneAuth();
    Get.offAllNamed(AppRoutes.guestOrLogin);
  }

  // ============================================================
  // PIN THEME
  // ============================================================

  PinTheme _pinTheme({
    required Color borderColor,
    Color? textColor,
  }) {
    return PinTheme(
      width: 48,
      height: 55,
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor ?? Colors.black,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: _changePhoneNumber,
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 80,
                child: Lottie.asset(
                  'assets/lottie/otp_verify.json',
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.sms,
                      size: 50,
                      color: Colors.green,
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              RichText(
                text: TextSpan(
                  text: 'We sent an OTP to ',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  children: [
                    TextSpan(
                      text: '+91 ${authVm.phoneNumber.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Center(
                child: Pinput(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  length: 6,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  showCursor: true,
                  defaultPinTheme: _pinTheme(
                    borderColor: _isAutoReading
                        ? Colors.green.shade200
                        : Colors.grey.shade300,
                  ),
                  focusedPinTheme: _pinTheme(
                    borderColor: Colors.green,
                    textColor: Colors.green,
                  ),
                  submittedPinTheme: _pinTheme(
                    borderColor: Colors.green.shade300,
                  ),
                  onChanged: (value) {
                    if (value.length == 6 && !_isVerificationComplete) {
                      _handleVerify(value);
                    }
                  },
                  onCompleted: (pin) {
                    debugPrint('PINPUT COMPLETED: $pin');
                    if (!_isVerificationComplete) {
                      _handleVerify(pin);
                    }
                  },
                ),
              ),

              const SizedBox(height: 14),

              if (_isAutoReading)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Waiting for OTP... Tap Allow when asked',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_autoReadFailed)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Enter OTP manually',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 18),

              Center(
                child: Obx(() {
                  final cooldown = authVm.otpResendCooldown.value;
                  final loading = authVm.isLoading.value;

                  if (cooldown > 0) {
                    return Text(
                      'Resend in ${cooldown}s',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    );
                  }

                  return GestureDetector(
                    onTap: loading ? null : _handleResend,
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        fontSize: 14,
                        color: loading ? Colors.grey.shade400 : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              Obx(() {
                final isExpired = authVm.isOtpTimeExpired();
                final isSent = authVm.otpSent.value;

                if (isExpired && isSent) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_off,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'OTP has expired. Please request a new one.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              }),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: Obx(() {
                  final loading = authVm.isLoading.value;
                  final otpReady = _otpController.text.length == 6;
                  final disabled = loading || _isVerifying || !otpReady || _isVerificationComplete;

                  return ElevatedButton(
                    onPressed: disabled ? null : () => _handleVerify(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: (loading || _isVerifying)
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}