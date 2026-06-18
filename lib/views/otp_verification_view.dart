// otp_verification_view.dart - NO AUTO-SUBMIT (User must click button)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../view_models/auth_view_model.dart';
import '../routes/app_routes.dart';

class OtpVerificationView extends StatefulWidget {
  const OtpVerificationView({super.key});

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isConfirmVisible = false;
  late String identifier;
  late bool isRegistration;
  late String verificationMethod;
  final authVm = Get.find<AuthViewModel>();

  Timer? _expiryCheckTimer;
  bool _isOtpExpired = false;
  int _remainingSeconds = 60;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    identifier = args?['identifier'] ?? '';
    isRegistration = args?['isRegistration'] ?? false;
    verificationMethod = args?['verificationMethod'] ?? 'email';

    _startExpiryCheck();
  }

  void _startExpiryCheck() {
    _expiryCheckTimer?.cancel();
    _expiryCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final remaining = authVm.getRemainingSeconds();
        setState(() {
          _remainingSeconds = remaining;
          _isOtpExpired = remaining <= 0;
        });

        if (_isOtpExpired) {
          timer.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade800, Colors.green.shade400],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBackButton(),
                const SizedBox(height: 10),
                _buildIcon(),
                const SizedBox(height: 30),
                _buildTitle(),
                const SizedBox(height: 10),
                _buildSubtitle(),
                const SizedBox(height: 30),
                _buildOtpField(),

                // OTP Expiry Timer Display
                if (!_isOtpExpired && _remainingSeconds > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'OTP expires in ${_remainingSeconds}s',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_isOtpExpired) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_off, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: const Text(
                            'OTP has expired. Please resend OTP to continue.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                if (!isRegistration) _buildPasswordFields(),

                const SizedBox(height: 20),

                if (!_isOtpExpired) ...[
                  _buildVerifyButton(),
                  const SizedBox(height: 20),
                ],

                _buildResendButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        verificationMethod == 'email' ? Icons.mark_email_read : Icons.smartphone,
        size: 60,
        color: Colors.green.shade700,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      isRegistration ? 'Verify Your Account' : 'Reset Password',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Enter OTP sent to $identifier',
        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOtpField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade800.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        style: const TextStyle(fontSize: 20, letterSpacing: 10, fontWeight: FontWeight.bold, color: Colors.green),
        decoration: const InputDecoration(
          hintText: '••••••',
          hintStyle: TextStyle(letterSpacing: 10, fontSize: 18, color: Colors.grey),
          border: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.all(16),
        ),
        // ✅ REMOVED onChanged auto-submit - User must click button
      ),
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      children: [
        const Divider(color: Colors.white70, height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Create New Password',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 15),
        _buildPasswordField(passwordController, 'New Password (6-20 characters)', isPasswordVisible,
                () => setState(() => isPasswordVisible = !isPasswordVisible)),
        const SizedBox(height: 15),
        _buildPasswordField(confirmPasswordController, 'Confirm Password', isConfirmVisible,
                () => setState(() => isConfirmVisible = !isConfirmVisible)),
      ],
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint, bool isVisible, VoidCallback toggle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade800.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        maxLength: 20,
        inputFormatters: [
          LengthLimitingTextInputFormatter(20),
        ],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: Icon(Icons.lock_outline, color: Colors.green.shade700),
          suffixIcon: IconButton(
            icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: Colors.green.shade700),
            onPressed: toggle,
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Obx(() => SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: authVm.isLoading.value ? null : _onVerifyPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.green.shade700,
          elevation: 3,
          shadowColor: Colors.green.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: authVm.isLoading.value
            ? const CircularProgressIndicator(color: Colors.green)
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isRegistration ? Icons.verified : Icons.lock_reset, color: Colors.green.shade700, size: 22),
            const SizedBox(width: 10),
            Text(
              isRegistration ? 'Verify OTP' : 'Reset Password',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildResendButton() {
    return Obx(() => TextButton(
      onPressed: authVm.otpResendCooldown.value > 0 || (!_isOtpExpired && _remainingSeconds > 0)
          ? null
          : () async {
        bool success = await authVm.resendOtp(identifier);
        if (success) {
          authVm.startResendTimer();
          setState(() {
            _isOtpExpired = false;
            _remainingSeconds = 60;
          });
          otpController.clear();
          _startExpiryCheck();
        }
      },
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(
        authVm.otpResendCooldown.value > 0
            ? 'Resend in ${authVm.otpResendCooldown.value}s'
            : 'Resend OTP',
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontWeight: FontWeight.w600,
        ),
      ),
    ));
  }

  void _onVerifyPressed() async {
    // ✅ User must click button - No auto verification

    if (_isOtpExpired) {
      Get.snackbar(
        'Error',
        'OTP has expired. Please resend OTP.',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (otpController.text.length != 6) {
      Get.snackbar(
        'Error',
        'Please enter the 6-digit OTP',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    if (isRegistration) {
      if (identifier.isEmpty) {
        Get.snackbar(
          'Error',
          'Unable to verify. Please try again.',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      bool success = await authVm.verifyOtp(otpController.text, identifier);
      if (success) {
        _expiryCheckTimer?.cancel();
        await Future.delayed(const Duration(seconds: 2));
        Get.offAllNamed(AppRoutes.login);
      } else {
        otpController.clear();
      }
    } else {
      // Password Reset Flow - User must click button
      if (passwordController.text.isEmpty) {
        Get.snackbar(
          'Error',
          'Please enter a new password',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      if (passwordController.text.length < 6) {
        Get.snackbar(
          'Error',
          'Password must be at least 6 characters',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      if (passwordController.text.length > 20) {
        Get.snackbar(
          'Error',
          'Password cannot exceed 20 characters',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      if (passwordController.text != confirmPasswordController.text) {
        Get.snackbar(
          'Error',
          'Passwords do not match',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      if (identifier.isEmpty) {
        Get.snackbar(
          'Error',
          'Unable to identify account',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      bool success = await authVm.resetPassword(otpController.text, passwordController.text, identifier: identifier);
      if (success) {
        _expiryCheckTimer?.cancel();
        await Future.delayed(const Duration(seconds: 2));
        Get.offAllNamed(AppRoutes.login);
      } else {
        otpController.clear();
      }
    }
  }
}