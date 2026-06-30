// signup_view.dart - COMPLETE WITH EMAIL/PHONE OTP SELECTION & FACEBOOK EVENTS

import 'package:book_your_turf/views/privacy_policy_view.dart';
import 'package:book_your_turf/views/term_condition_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../view_models/auth_view_model.dart';
import '../services/deep_link_service.dart';
import '../routes/app_routes.dart';
// 🔥 Import Facebook App Events
import 'package:book_your_turf/main.dart' show facebookAppEvents;

class SignupView extends StatefulWidget {
  const SignupView({Key? key}) : super(key: key);

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final SignupController signupController = Get.put(SignupController());

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _agreeTerms = false;
  String _verificationMethod = 'email'; // 'email' or 'phone'
  final authVm = Get.find<AuthViewModel>();

  // Error messages
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmError;

  // Validation regex
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _nameRegex = RegExp(r'^[a-zA-Z\s]{2,50}$');

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateName);
    _emailController.addListener(_validateEmail);
    _phoneController.addListener(_validatePhone);
    _passwordController.addListener(_validatePassword);
    _confirmController.addListener(_validateConfirmPassword);
  }

  // Validation methods
  void _validateName() {
    setState(() {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _nameError = 'Full name is required';
      } else if (name.length < 2) {
        _nameError = 'Name must be at least 2 characters';
      } else if (name.length > 50) {
        _nameError = 'Name cannot exceed 50 characters';
      } else if (!_nameRegex.hasMatch(name)) {
        _nameError = 'Only letters and spaces allowed';
      } else {
        _nameError = null;
      }
    });
  }

  void _validateEmail() {
    setState(() {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = 'Email address is required';
      } else if (!_emailRegex.hasMatch(email)) {
        _emailError = 'Enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePhone() {
    setState(() {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        _phoneError = 'Phone number is required';
      } else if (phone.length != 10) {
        _phoneError = 'Phone number must be exactly 10 digits';
      } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
        _phoneError = 'Enter a valid Indian mobile number (starts with 6-9)';
      } else {
        _phoneError = null;
      }
    });
  }

  void _validatePassword() {
    setState(() {
      final password = _passwordController.text;
      if (password.isEmpty) {
        _passwordError = 'Password is required';
      } else if (password.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else if (password.length > 20) {
        _passwordError = 'Password cannot exceed 20 characters';
      } else {
        _passwordError = null;
      }
    });
    if (_confirmController.text.isNotEmpty) {
      _validateConfirmPassword();
    }
  }

  void _validateConfirmPassword() {
    setState(() {
      final password = _passwordController.text;
      final confirm = _confirmController.text;
      if (confirm.isEmpty) {
        _confirmError = 'Please confirm your password';
      } else if (password != confirm) {
        _confirmError = 'Passwords do not match';
      } else {
        _confirmError = null;
      }
    });
  }

  bool get _isFormValid {
    return _nameError == null &&
        _emailError == null &&
        _phoneError == null &&
        _passwordError == null &&
        _confirmError == null &&
        _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmController.text.isNotEmpty &&
        _agreeTerms;
  }

  @override
  void dispose() {
    _nameController.removeListener(_validateName);
    _emailController.removeListener(_validateEmail);
    _phoneController.removeListener(_validatePhone);
    _passwordController.removeListener(_validatePassword);
    _confirmController.removeListener(_validateConfirmPassword);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
            colors: [Colors.green.shade800, Colors.green.shade600, Colors.green.shade400],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildBackButton(),
                const SizedBox(height: 10),
                _buildHeader(),
                const SizedBox(height: 20),
                if (signupController.referralCodeController.text.isNotEmpty) _buildReferralBanner(),
                _buildInfoText(),
                const SizedBox(height: 15),
                _buildOtpMethodSelector(),
                const SizedBox(height: 15),
                _buildFormFields(),
                const SizedBox(height: 10),
                _buildTermsCheckbox(),
                const SizedBox(height: 30),
                _buildSignupButton(),
                const SizedBox(height: 25),
                _buildLoginLink(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Get.back(),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Create\nAccount', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
        const SizedBox(height: 6),
        Text('Join the sports community', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9))),
      ],
    );
  }

  Widget _buildReferralBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Referral Code Applied! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Code: ${signupController.referralCodeController.text}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => signupController.clearReferralCode(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Both Email and Phone will be saved. Choose where to receive OTP.',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpMethodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 4),
            child: Text('Receive OTP via', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Row(
            children: [
              _buildOtpOption('email', 'Email', Icons.email_outlined),
              _buildOtpOption('phone', 'Phone', Icons.phone_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpOption(String method, String label, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _verificationMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _verificationMethod == method ? Colors.green.shade100 : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _verificationMethod == method ? Colors.green.shade700 : Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: _verificationMethod == method ? Colors.green.shade700 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        children: [
          _buildTextFieldWithError(_nameController, Icons.person_outline, 'Full Name', 'Enter your name', _nameError),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildTextFieldWithError(_emailController, Icons.email_outlined, 'Email Address', 'Enter your email', _emailError, keyboardType: TextInputType.emailAddress),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildPhoneFieldWithError(),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildReferralField(),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildPasswordFieldWithError(_passwordController, 'Password', 'Create password (6-20 characters)', _isPasswordVisible, () => setState(() => _isPasswordVisible = !_isPasswordVisible), _passwordError),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildPasswordFieldWithError(_confirmController, 'Confirm Password', 'Confirm your password', _isConfirmVisible, () => setState(() => _isConfirmVisible = !_isConfirmVisible), _confirmError),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithError(
      TextEditingController c,
      IconData icon,
      String label,
      String hint,
      String? error, {
        TextInputType keyboardType = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: keyboardType,
            controller: c,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13),
              border: InputBorder.none,
              errorText: null,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: TextStyle(color: Colors.red.shade600, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneFieldWithError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_outlined, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Text('Phone Number', style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: 'Enter 10-digit phone number',
              hintStyle: const TextStyle(fontSize: 13),
              border: InputBorder.none,
              counterText: '',
              errorText: null,
            ),
          ),
          if (_phoneError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _phoneError!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReferralField() {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Text(
                'Referral Code ${signupController.hasReferralFromLink.value ? "(Applied from link)" : "(Optional)"}',
                style: TextStyle(
                  color: signupController.hasReferralFromLink.value ? Colors.green.shade700 : Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: signupController.referralCodeController,
            maxLength: 10,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              hintText: 'Enter 10-digit referral code',
              hintStyle: const TextStyle(fontSize: 13),
              border: InputBorder.none,
              counterText: '',
              suffixIcon: signupController.referralCodeController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => signupController.clearReferralCode(),
              )
                  : null,
            ),
          ),
          if (signupController.referralCodeController.text.isNotEmpty &&
              signupController.referralCodeController.text.length != 10)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Referral code must be exactly 10 digits',
                style: TextStyle(color: Colors.red.shade600, fontSize: 11),
              ),
            ),
        ],
      ),
    ));
  }

  Widget _buildPasswordFieldWithError(
      TextEditingController c,
      String label,
      String hint,
      bool isVisible,
      VoidCallback toggle,
      String? error,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.green, size: 20),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            obscureText: !isVisible,
            maxLength: 20,
            inputFormatters: [
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13),
              border: InputBorder.none,
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: toggle,
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                error,
                style: TextStyle(color: Colors.red.shade600, fontSize: 11),
              ),
            ),
          if (label == 'Password' && _passwordError == null && c.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '✓ Password strength: ${c.text.length} characters',
                style: TextStyle(color: Colors.green.shade600, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() => _agreeTerms = !_agreeTerms),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white, width: 1.5),
              color: _agreeTerms ? Colors.white : Colors.transparent,
            ),
            child: _agreeTerms ? Icon(Icons.check, size: 14, color: Colors.green.shade700) : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.4),
              children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => _showTermsAndConditions(),
                    child: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: Colors.white, fontSize: 12)),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: () => _showPrivacyPolicy(),
                    child: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: Colors.white, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton() {
    return Obx(() => SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _agreeTerms && !authVm.isLoading.value && _isFormValid ? _onSignupPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _agreeTerms ? Colors.white : Colors.white.withOpacity(0.6),
          foregroundColor: Colors.green.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: authVm.isLoading.value
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
            : Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _agreeTerms ? Colors.green.shade700 : Colors.green.shade300)),
      ),
    ));
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account? ", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
        GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.login),
          child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  void _onSignupPressed() async {
    // Additional validation before API call
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar('Error', 'Please enter your name', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    String email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      Get.snackbar('Error', 'Enter valid email', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    String phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
      Get.snackbar('Error', 'Enter valid 10-digit phone number', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    String password = _passwordController.text;
    if (password.isEmpty || password.length < 6) {
      Get.snackbar('Error', 'Password must be at least 6 characters', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (password.length > 20) {
      Get.snackbar('Error', 'Password cannot exceed 20 characters', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (password != _confirmController.text) {
      Get.snackbar('Error', 'Passwords do not match', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    String referralCode = signupController.referralCodeController.text.trim();
    if (referralCode.isNotEmpty && referralCode.length != 10) {
      Get.snackbar('Error', 'Referral code must be exactly 10 digits', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (!_agreeTerms) {
      Get.snackbar('Error', 'Please agree to Terms & Conditions and Privacy Policy', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // ✅ Use selected verification method (email or phone)
    bool success = await authVm.sendRegistrationOtp(
      name: _nameController.text.trim(),
      email: email,
      phone: phone,
      password: password,
      referralCode: referralCode.isNotEmpty ? referralCode : null,
      verificationMethod: _verificationMethod,
    );

    if (success) {
      String identifier = _verificationMethod == 'email' ? email : phone;
      Get.toNamed(
        AppRoutes.otpVerification,
        arguments: {
          'identifier': identifier,
          'email': email,
          'isRegistration': true,
          'verificationMethod': _verificationMethod,
        },
      );
    }
  }

  void _showTermsAndConditions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12), height: 5, width: 60, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20))),
              const Expanded(child: TermConditionView()),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Got it", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
              SizedBox(height: 30,)
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12), height: 5, width: 60, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20))),
              const Expanded(child: PrivacyPolicyView()),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text("Got it", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
              SizedBox(height: 30,)
            ],
          ),
        );
      },
    );
  }
}

class SignupController extends GetxController {
  final referralCodeController = TextEditingController();
  final hasReferralFromLink = false.obs;

  void clearReferralCode() {
    referralCodeController.clear();
    hasReferralFromLink.value = false;
  }

  void setReferralCode(String code) {
    referralCodeController.text = code;
    hasReferralFromLink.value = true;
  }

  @override
  void onClose() {
    referralCodeController.dispose();
    super.onClose();
  }
}