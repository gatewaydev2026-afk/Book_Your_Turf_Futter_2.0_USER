// signup_with_booking_view.dart - Email OTP removed, Phone only

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../../view_models/auth_view_model.dart';
import '../../services/shared_prefs_helper.dart';

Future<void> showGuestBookingAuthDialog({
  required Map<String, dynamic> bookingData,
  required VoidCallback onSuccess,
}) {
  // ✅ Check if user is already logged in - skip dialog
  final token = SharedPrefsHelper.getToken();
  if (token != null && token.isNotEmpty) {
    print('⚠️ User already logged in - skipping dialog');
    onSuccess();
    return Future.value();
  }

  return Get.dialog(
    GuestBookingAuthDialog(bookingData: bookingData, onSuccess: onSuccess),
    barrierDismissible: false,
  );
}

class GuestBookingAuthDialog extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final VoidCallback onSuccess;

  const GuestBookingAuthDialog({
    super.key,
    required this.bookingData,
    required this.onSuccess,
  });

  @override
  State<GuestBookingAuthDialog> createState() => _GuestBookingAuthDialogState();
}

class _GuestBookingAuthDialogState extends State<GuestBookingAuthDialog>
    with CodeAutoFill {
  final authVm = Get.find<AuthViewModel>();

  int _step = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isPasswordVisible = false;
  String _phone = '';
  String _password = '';

  Timer? _expiryTimer;
  int _remainingSeconds = 60;
  bool _isOtpExpired = false;
  bool _isBusy = false;

  // ✅ Flag to prevent multiple navigation attempts
  bool _isNavigating = false;

  @override
  void dispose() {
    _expiryTimer?.cancel();
    cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  void codeUpdated() {
    if (!mounted) return;
    final autoCode = code;
    if (autoCode == null || autoCode.isEmpty) return;

    setState(() {
      _otpController.text = autoCode;
    });

    if (autoCode.length == 6 && !_isBusy && !_isNavigating) {
      _onVerifyOtp();
    }
  }

  void _startExpiryCheck() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining = authVm.getRemainingSeconds();
      setState(() {
        _remainingSeconds = remaining;
        _isOtpExpired = remaining <= 0;
      });
      if (_isOtpExpired) timer.cancel();
    });
  }

  // ============================================================
  // STEP 0 -> Send OTP to Phone
  // ============================================================
  Future<void> _onSendOtp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      Get.snackbar('Error', 'Please enter your name', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (email.isEmpty || !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      Get.snackbar('Error', 'Enter a valid email', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      Get.snackbar('Error', 'Enter a valid 10-digit phone number', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (password.length < 6 || password.length > 20) {
      Get.snackbar('Error', 'Password must be 6-20 characters', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (password != _confirmController.text) {
      Get.snackbar('Error', 'Passwords do not match', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    _password = password;
    _phone = phone;

    setState(() => _isBusy = true);

    // ✅ Always use phone verification
    final success = await authVm.sendRegistrationOtp(
      name: name,
      email: email,
      phone: phone,
      password: password,
      referralCode: null,
      verificationMethod: 'phone', // ✅ Always phone
      showLoadingOverlay: false,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (success) {
      setState(() => _step = 1);
      _remainingSeconds = 60;
      _isOtpExpired = false;
      _startExpiryCheck();
      // ✅ Listen for SMS OTP
      _listenForSmsCode();
    }
  }

  // ✅ Listens via the SMS User Consent API
  Future<void> _listenForSmsCode() async {
    try {
      await SmsAutoFill().listenForCode();
    } catch (e) {
      print('SMS autofill listen failed: $e');
    }
  }

  // ============================================================
  // STEP 1 -> Verify OTP + auto-login
  // ============================================================
  Future<void> _onVerifyOtp() async {
    if (_isNavigating) return;

    if (_otpController.text.length != 6) {
      Get.snackbar('Error', 'Please enter the 6-digit OTP', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    setState(() => _isBusy = true);
    final verified = await authVm.verifyOtp(
      _otpController.text,
      _phone, // ✅ Always use phone
      showLoadingOverlay: false,
    );

    if (!mounted) return;

    if (!verified) {
      setState(() => _isBusy = false);
      _otpController.clear();
      return;
    }

    _expiryTimer?.cancel();

    // ✅ Login with phone
    final loggedIn = await authVm.login(
      _phone,
      _password,
      navigateOnSuccess: false,
      showLoadingOverlay: false,
    );

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (loggedIn) {
      _isNavigating = true;

      // ✅ Close dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // ✅ Navigate to booking summary
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSuccess();
        }
        _isNavigating = false;
      });
    } else {
      Get.snackbar(
        'Login Failed',
        'Account created but login failed. Please try logging in.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _onResendOtp() async {
    final success = await authVm.resendOtp(_phone, showLoadingOverlay: false);
    if (!mounted) return;
    if (success) {
      authVm.startResendTimer();
      _otpController.clear();
      setState(() {
        _isOtpExpired = false;
        _remainingSeconds = 60;
      });
      _startExpiryCheck();
      _listenForSmsCode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isBusy,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _step == 0 ? _buildSignupStep() : _buildOtpStep(),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI — STEP 0: Signup form
  // ============================================================
  Widget _buildSignupStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.person_add_alt_1, color: Colors.green.shade700, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Create Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Text(
          'Just a few details to confirm your slot',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        _field(_nameController, 'Full Name', Icons.person_outline),
        const SizedBox(height: 12),
        _field(_emailController, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _field(
          _phoneController,
          'Phone Number',
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        ),
        const SizedBox(height: 12),
        _field(
          _passwordController,
          'Password',
          Icons.lock_outline,
          obscure: !_isPasswordVisible,
          suffix: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, size: 18),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
        const SizedBox(height: 12),
        _field(_confirmController, 'Confirm Password', Icons.lock_outline, obscure: !_isPasswordVisible),
        const SizedBox(height: 20),

        // ✅ Removed OTP method selector - always uses phone

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isBusy ? null : _onSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isBusy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _field(
      TextEditingController c,
      String hint,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        bool obscure = false,
        Widget? suffix,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.green.shade700, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // ============================================================
  // UI — STEP 1: OTP
  // ============================================================
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() => _step = 0),
            ),
            const Expanded(
              child: Text('Verify OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'Enter the OTP sent to $_phone',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 18),

        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold, color: Colors.green),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (value) {
            if (value.length == 6 && !_isBusy && !_isNavigating) {
              _onVerifyOtp();
            }
          },
        ),
        const SizedBox(height: 10),

        if (!_isOtpExpired)
          Text('OTP expires in ${_remainingSeconds}s', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
        else
          Text('OTP expired — please resend', style: TextStyle(fontSize: 12, color: Colors.red.shade600)),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: (_isBusy || _isOtpExpired) ? null : _onVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isBusy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Verify & Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 10),

        Center(
          child: Obx(() => TextButton(
            onPressed: authVm.otpResendCooldown.value > 0 ? null : _onResendOtp,
            child: Text(
              authVm.otpResendCooldown.value > 0
                  ? 'Resend in ${authVm.otpResendCooldown.value}s'
                  : 'Resend OTP',
              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
            ),
          )),
        ),
      ],
    );
  }
}