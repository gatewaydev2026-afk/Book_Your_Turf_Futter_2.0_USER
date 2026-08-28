// views/demoview/GuestOrLoginView.dart
// ✅ Auto Detect runs automatically when page loads (one-time)
// ✅ Shows loading state while detecting
// ✅ Auto-clicks the detect button

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../themes/app_colors.dart';
import '../../view_models/auth_view_model.dart';
import '../../services/phone_auto_detect_service.dart';
import '../term_condition_view.dart';
import '../privacy_policy_view.dart';

// -----------------------------------------------------------------------
// Design tokens — centralised so the whole screen stays visually consistent
// -----------------------------------------------------------------------
class _GLColors {
  static const primary = Color(0xFF0F9D58);
  static const primaryDark = Color(0xFF0B7A43);
  static const primarySoft = Color(0xFFE6F4EA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E5E9);
  static const textPrimary = Color(0xFF14181F);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const error = Color(0xFFD64545);
  static const errorSoft = Color(0xFFFCEBEB);
}

class GuestOrLoginView extends StatefulWidget {
  const GuestOrLoginView({super.key});

  @override
  State<GuestOrLoginView> createState() => _GuestOrLoginViewState();
}

class _GuestOrLoginViewState extends State<GuestOrLoginView> {
  final AuthViewModel authVm = Get.find<AuthViewModel>();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  bool _isValid = false;
  bool _isLoading = true;
  bool _showManualEntry = false;
  bool _isDetecting = false;
  bool _autoDetectTriggered = false; // ✅ Track if auto-detect already triggered
  String? _detectionError;

  List<String> _detectedNumbers = [];
  String? _selectedNumber;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
    authVm.resetPhoneAuth();
    _loadStoredNumber();

    // ✅ Auto-trigger detection after page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoDetect();
    });
  }

  @override
  void dispose() {
    _phoneController.removeListener(_validatePhone);
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Load stored number
  // ---------------------------------------------------------------------

  Future<void> _loadStoredNumber() async {
    setState(() {
      _isLoading = true;
      _detectionError = null;
    });

    try {
      final stored = await PhoneAutoDetectService.getStoredNumber();

      if (stored != null && stored.isNotEmpty && stored.length == 10) {
        _detectedNumbers = [stored];
        _selectedNumber = stored;
        _showManualEntry = false;
        _detectionError = null;
        print('📱 GuestOrLoginView: Loaded stored number: $stored');
      } else {
        _detectedNumbers = [];
        _selectedNumber = null;
        _showManualEntry = true;
        _detectionError = 'No number detected. Please enter manually.';
        print('ℹ️ GuestOrLoginView: No stored number found');
      }
    } catch (e) {
      print('❌ GuestOrLoginView: Error loading number: $e');
      _detectedNumbers = [];
      _selectedNumber = null;
      _showManualEntry = true;
      _detectionError = 'Could not load number. Please enter manually.';
    } finally {
      if (mounted) setState(() => _isLoading = false);

      if (mounted && !_showManualEntry && _detectedNumbers.isNotEmpty) {
        _autoOpenNumberDialog();
      }
    }
  }

  // ---------------------------------------------------------------------
  // ✅ Auto Trigger Detection - Runs automatically on page load
  // ---------------------------------------------------------------------

  Future<void> _triggerAutoDetect() async {
    // ✅ Prevent multiple triggers
    if (_autoDetectTriggered) {
      print('⏭️ Auto-detect already triggered - skipping');
      return;
    }

    // ✅ If number already detected, skip
    if (_detectedNumbers.isNotEmpty) {
      print('✅ Number already detected - skipping auto-detect');
      _autoDetectTriggered = true;
      return;
    }

    // ✅ Wait a moment for UI to load
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    _autoDetectTriggered = true;

    // ✅ Call the auto-detect function
    await _autoDetectNumber();
  }

  // ---------------------------------------------------------------------
  // Auto Detect Phone Number
  // ---------------------------------------------------------------------

  Future<void> _autoDetectNumber() async {
    if (_isDetecting) return;
    if (_detectedNumbers.isNotEmpty) {
      print('✅ Number already detected - skipping');
      return;
    }

    setState(() {
      _isDetecting = true;
      _detectionError = null;
    });

    try {
      print('🔍 Auto-detecting phone number...');
      final number = await PhoneAutoDetectService.autoDetectOnce();

      if (number != null && number.isNotEmpty && mounted) {
        setState(() {
          _detectedNumbers = [number];
          _selectedNumber = number;
          _showManualEntry = false;
          _phoneController.clear();
          _detectionError = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Phone number detected successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        print('📱 Auto-detected number: $number');
      } else if (mounted) {
        setState(() {
          _showManualEntry = true;
          _detectionError = 'No number selected. Please enter manually.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ No number selected. Please enter manually.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Auto-detect error: $e');
      if (mounted) {
        setState(() {
          _showManualEntry = true;
          _detectionError = 'Failed to detect number. Please enter manually.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to detect: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  void _validatePhone() {
    final phone = _phoneController.text.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    final isValid = phone.length == 10 && RegExp(r'^[0-9]+$').hasMatch(phone);
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  void _handleSendOtp() {
    if (_isLoading || authVm.isLoading.value) return;

    String phone;
    if (!_showManualEntry && _selectedNumber != null) {
      phone = _selectedNumber!;
    } else {
      phone = _phoneController.text.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    }

    if (phone.length == 10) {
      PhoneAutoDetectService.savePhoneNumber(phone);
      authVm.sendPhoneOtp(number: phone);
    }
  }

  void _showManualNumberEntry() {
    setState(() {
      _showManualEntry = true;
      _phoneController.clear();
      _selectedNumber = null;
      _detectionError = null;
    });
    _phoneFocusNode.requestFocus();
  }

  String _formatPhone(String text) {
    String cleaned = text.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length > 10) cleaned = cleaned.substring(0, 10);
    return cleaned;
  }

  void _autoOpenNumberDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openNumberDialog();
    });
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (authVm.otpSent.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offNamed(AppRoutes.phoneOtpVerification);
        });
      }

      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✅ Logo
                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/images/BYTUSER.png',
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // ✅ "Welcome Player" with Gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF0F9D58), Color(0xFF0B7A43)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'Welcome Player',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ✅ Subtitle
                    const Text(
                      'Let\'s Play!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Logo Image
                    Image.asset(
                      'assets/images/logo.png',
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.sports_cricket,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ Phone number section
                    if (_isLoading)
                      _buildLoadingState()
                    else if (_isDetecting)
                      _buildAutoDetectingState()
                    else if (!_showManualEntry && _detectedNumbers.isNotEmpty)
                        _buildDetectedNumberRow()
                      else
                        _buildManualEntryCard(),

                    if (_detectionError != null && _showManualEntry) ...[
                      const SizedBox(height: 12),
                      _buildErrorBanner(_detectionError!),
                    ],

                    const SizedBox(height: 20),

                    // ✅ Send OTP Button
                    _buildSendOtpButton(),

                    const SizedBox(height: 10),
                    _buildToggleAction(),

                    const SizedBox(height: 22),

                    // ✅ Clickable Disclaimer
                    GestureDetector(
                      onTap: () => _showTermsAndPrivacyBottomSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            children: [
                              const TextSpan(text: 'By continuing, you agree to our '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _GLColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _GLColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _GLColors.primary,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Loading your number…',
            style: TextStyle(
              fontSize: 13,
              color: _GLColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Auto-detecting state
  // ---------------------------------------------------------------------

  Widget _buildAutoDetectingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: _GLColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _GLColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _GLColors.primary,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Auto-detecting your number…',
            style: TextStyle(
              fontSize: 13,
              color: _GLColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Error banner
  // ---------------------------------------------------------------------

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _GLColors.errorSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _GLColors.error.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _GLColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _GLColors.error,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Detected number row
  // ---------------------------------------------------------------------

  Widget _buildDetectedNumberRow() {
    final hasMultiple = _detectedNumbers.length > 1;
    final selected = _selectedNumber ?? _detectedNumbers.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openNumberDialog(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          decoration: BoxDecoration(
            color: _GLColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _GLColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _GLColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sim_card_rounded, size: 17, color: _GLColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasMultiple ? 'SIM number' : '✅ Auto-detected number',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+91 ${_formatPhone(selected)}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: _GLColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: _GLColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Number confirmation dialog
  // ---------------------------------------------------------------------

  void _openNumberDialog() {
    final hasMultiple = _detectedNumbers.length > 1;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final selected = _selectedNumber ?? _detectedNumbers.first;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 56),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: _GLColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: _GLColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sim_card_rounded, color: _GLColors.primary, size: 17),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasMultiple ? 'Choose your number' : 'Confirm your number',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _GLColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (!hasMultiple)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _GLColors.primarySoft,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '+91 ${_formatPhone(selected)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _GLColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _detectedNumbers.map((number) {
                          final isSelected = selected == number;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() => _selectedNumber = number);
                                  setDialogState(() {});
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _GLColors.primarySoft : const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? _GLColors.primary : _GLColors.border,
                                      width: isSelected ? 1.4 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '+91 ${_formatPhone(number)}',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? _GLColors.primaryDark : _GLColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        const Icon(Icons.check_circle_rounded, size: 17, color: _GLColors.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: _GLColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Manual entry
  // ---------------------------------------------------------------------

  Widget _buildManualEntryCard() {
    return Container(
      decoration: BoxDecoration(
        color: _GLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isValid ? _GLColors.primary : _GLColors.border,
          width: _isValid ? 1.6 : 1,
        ),
        boxShadow: _isValid
            ? [
          BoxShadow(
            color: _GLColors.primary.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ]
            : [],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _GLColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 26, color: _GLColors.border),
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              autofocus: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _GLColors.textPrimary,
                letterSpacing: 0.3,
              ),
              cursorColor: _GLColors.primary,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter mobile number',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _GLColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                suffixIcon: _isValid
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.check_circle_rounded, color: _GLColors.primary, size: 22),
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Send OTP button
  // ---------------------------------------------------------------------

  Widget _buildSendOtpButton() {
    final bool disabled = authVm.isLoading.value ||
        authVm.otpSent.value ||
        _isDetecting ||
        (_showManualEntry && !_isValid) ||
        (!_showManualEntry && _selectedNumber == null);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: disabled ? null : _handleSendOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: authVm.isLoading.value
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_android, size: 22),
            const SizedBox(width: 10),
            Text(
              (!_showManualEntry && _selectedNumber != null)
                  ? 'Login'
                  : 'Login',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleAction() {
    if (!_showManualEntry && _detectedNumbers.isNotEmpty) {
      return Center(
        child: TextButton(
          onPressed: _showManualNumberEntry,
          style: TextButton.styleFrom(foregroundColor: _GLColors.textSecondary),
          child: const Text(
            'Use a different number',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } else if (_showManualEntry && _detectedNumbers.isNotEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () => _loadStoredNumber(),
          style: TextButton.styleFrom(foregroundColor: _GLColors.primary),
          icon: const Icon(Icons.sim_card_rounded, size: 16),
          label: const Text(
            'Use detected number',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------
  // Terms & Privacy bottom sheet
  // ---------------------------------------------------------------------

  void _showTermsAndPrivacyBottomSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Terms & Privacy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              title: const Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                Get.back();
                Get.to(() => const TermConditionView());
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.privacy_tip,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              title: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                Get.back();
                Get.to(() => const PrivacyPolicyView());
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Get.back(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}