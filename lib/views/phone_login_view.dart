// views/phone_login_view.dart
// ✅ Auto-detect SIM + Dual SIM choose + One-click OTP + Professional Design

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../themes/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../routes/app_routes.dart';
import '../services/phone_auto_detect_service.dart';

// -----------------------------------------------------------------------
// Design tokens — centralised so the whole screen stays visually consistent
// -----------------------------------------------------------------------
class _PLColors {
  static const primary = Color(0xFF0F9D58); // deep professional green
  static const primaryDark = Color(0xFF0B7A43);
  static const primarySoft = Color(0xFFE6F4EA);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F8FA);
  static const border = Color(0xFFE2E5E9);
  static const textPrimary = Color(0xFF14181F);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const error = Color(0xFFD64545);
  static const errorSoft = Color(0xFFFCEBEB);
}

class PhoneLoginView extends StatefulWidget {
  const PhoneLoginView({super.key});

  @override
  State<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends State<PhoneLoginView> {
  final AuthViewModel authVm = Get.find<AuthViewModel>();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  bool _isValid = false;
  bool _isLoading = true;
  bool _showManualEntry = false;
  String? _detectionError;

  List<String> _detectedNumbers = [];
  String? _selectedNumber;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
    authVm.resetPhoneAuth();
    _autoDetectPhoneNumber();
  }

  @override
  void dispose() {
    _phoneController.removeListener(_validatePhone);
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _autoDetectPhoneNumber() async {
    setState(() {
      _isLoading = true;
      _detectionError = null;
    });

    try {
      // First check stored number
      final stored = await PhoneAutoDetectService.getStoredNumber();
      if (stored != null && stored.isNotEmpty) {
        _detectedNumbers = [stored];
        _selectedNumber = stored;
        _showManualEntry = false;
        setState(() => _isLoading = false);
        return;
      }

      // Detect from SIM
      final numbers = await PhoneAutoDetectService.getSimPhoneNumbers();
      if (numbers.isNotEmpty) {
        _detectedNumbers = numbers;
        _selectedNumber = numbers.first;
        _showManualEntry = false;
      } else {
        _detectedNumbers = [];
        _selectedNumber = null;
        _showManualEntry = true;
        _detectionError = 'No SIM number detected. Please enter manually.';
      }
    } catch (e) {
      _detectedNumbers = [];
      _selectedNumber = null;
      _showManualEntry = true;
      _detectionError = 'Could not detect number. Please enter manually.';
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      PhoneAutoDetectService.setDetectedNumber(phone);
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
    if (cleaned.length <= 3) return cleaned;
    if (cleaned.length <= 6) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3)}';
    }
    return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 6)} ${cleaned.substring(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (authVm.otpSent.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offNamed(AppRoutes.phoneOtpVerification);
        });
      }

      return Scaffold(
        backgroundColor: _PLColors.background,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildBackButton(),
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 32),

                    if (_isLoading)
                      _buildLoadingState()
                    else if (!_showManualEntry && _detectedNumbers.isNotEmpty)
                      _buildDetectedNumbersList()
                    else
                      _buildManualEntryCard(),

                    if (_detectionError != null && _showManualEntry) ...[
                      const SizedBox(height: 14),
                      _buildErrorBanner(_detectionError!),
                    ],

                    const SizedBox(height: 28),
                    _buildSendOtpButton(),
                    const SizedBox(height: 14),
                    _buildToggleAction(),

                    const SizedBox(height: 230),
                    _buildFooter(),
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
  // Header
  // ---------------------------------------------------------------------

  Widget _buildBackButton() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _PLColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PLColors.border),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        splashRadius: 20,
        icon: const Icon(Icons.arrow_back_rounded, size: 20, color: _PLColors.textPrimary),
        onPressed: () => Get.back(),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _PLColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.phone_iphone_rounded, color: _PLColors.primary, size: 26),
        ),
        const SizedBox(height: 18),
        const Text(
          'Verify your mobile number',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _PLColors.textPrimary,
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'We\'ll send a one-time password (OTP) to verify\nyour number securely.',
          style: TextStyle(
            fontSize: 14,
            color: _PLColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44),
      decoration: BoxDecoration(
        color: _PLColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PLColors.border),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _PLColors.primary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Detecting SIM number…',
            style: TextStyle(
              fontSize: 13.5,
              color: _PLColors.textSecondary,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PLColors.errorSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PLColors.error.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _PLColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _PLColors.error,
                fontSize: 13,
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
  // Detected SIM numbers
  // ---------------------------------------------------------------------

  Widget _buildDetectedNumbersList() {
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
            color: _PLColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _PLColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _PLColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sim_card_rounded, size: 17, color: _PLColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasMultiple ? 'SIM number' : 'Detected number',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _PLColors.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+91 ${_formatPhone(selected)}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: _PLColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: _PLColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Compact professional confirmation dialog
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  color: _PLColors.surface,
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _PLColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sim_card_rounded, color: _PLColors.primary, size: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasMultiple ? 'Choose your number' : 'Confirm your number',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _PLColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (!hasMultiple)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _PLColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+91 ${_formatPhone(selected)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _PLColors.textPrimary,
                            letterSpacing: 0.3,
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
                                    color: isSelected ? _PLColors.primarySoft : _PLColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? _PLColors.primary : _PLColors.border,
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
                                          color: isSelected ? _PLColors.primaryDark : _PLColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        const Icon(Icons.check_circle_rounded, size: 17, color: _PLColors.primary),
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
                      height: 38,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: _PLColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        color: _PLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isValid ? _PLColors.primary : _PLColors.border,
          width: _isValid ? 1.6 : 1,
        ),
        boxShadow: _isValid
            ? [
          BoxShadow(
            color: _PLColors.primary.withOpacity(0.10),
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
                const Text(
                  '🇮🇳',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _PLColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 26, color: _PLColors.border),
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
                color: _PLColors.textPrimary,
                letterSpacing: 0.3,
              ),
              cursorColor: _PLColors.primary,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter mobile number',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _PLColors.textMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
                suffixIcon: _isValid
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.check_circle_rounded, color: _PLColors.primary, size: 22),
                )
                    : null,
              ),
              onChanged: (value) {
                final formatted = _formatPhone(value);
                if (formatted != _phoneController.text) {
                  _phoneController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Primary action button
  // ---------------------------------------------------------------------

  Widget _buildSendOtpButton() {
    final bool disabled = authVm.isLoading.value ||
        authVm.otpSent.value ||
        (_showManualEntry && !_isValid) ||
        (!_showManualEntry && _selectedNumber == null);

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: disabled ? null : _handleSendOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: _PLColors.primary,
          disabledBackgroundColor: _PLColors.primary.withOpacity(0.4),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: authVm.isLoading.value
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              (!_showManualEntry && _selectedNumber != null)
                  ? 'Send OTP to this number'
                  : 'Send OTP',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 19),
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
          style: TextButton.styleFrom(
            foregroundColor: _PLColors.textSecondary,
          ),
          child: const Text(
            'Use a different number',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } else if (_showManualEntry && _detectedNumbers.isNotEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () async {
            setState(() => _isLoading = true);
            await _autoDetectPhoneNumber();
          },
          style: TextButton.styleFrom(
            foregroundColor: _PLColors.primary,
          ),
          icon: const Icon(Icons.sim_card_rounded, size: 16),
          label: const Text(
            'Use detected number',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'Owned by',
            style: TextStyle(
              fontSize: 12,
              color: _PLColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NOTTAM INFOTECH PRIVATE LIMITED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}