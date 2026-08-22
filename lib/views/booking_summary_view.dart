// lib/views/booking_summary_view.dart
// ✅ Ticket Style Discount Cards - Like the reference image
// ✅ Dashed middle line with punch-hole notches
// ✅ Left color box (discount value) + Right cream box (details)
// ✅ Professional coupon/ticket look
// ✅ Shows "Select minimum X slots" when discounts exist but slots < minSlots
// ✅ Shows "No discounts available" when no discounts exist at all
// ✅ NO requirements text in coupon card
// ✅ FIXED: UI locked during payment processing - No back button until navigation completes
// ✅ Fee Breakup - Click to show Platform Fee & Convenience Fee

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/discount_model.dart';
import '../services/price_formatter.dart';
import '../view_models/booking_summary_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/main_page_view_model.dart';
import '../routes/app_routes.dart';
import '../views/wallet_recharge_dialog.dart';

// ============================================================
// ✅ Dashed vertical line painter - used for the ticket perforation
// ============================================================
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({this.color = const Color(0xFFBBBBBB)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashHeight = 5.0;
    const dashSpace = 4.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BookingSummaryView extends StatelessWidget {
  BookingSummaryView({super.key});

  // ✅ Controller for fee breakup expansion
  final RxBool _showFeeBreakup = false.obs;

  bool _isDiscountValid(DiscountModel discount) {
    if (discount.discountType == 'percentage') {
      return discount.discountValue <= 99.0;
    }
    return true;
  }

  String? _getDiscountValidationMessage(DiscountModel discount) {
    if (discount.discountType == 'percentage' && discount.discountValue > 99.0) {
      return 'Maximum 99% discount allowed';
    }
    return null;
  }

  // ✅ Helper method to build styled rupee text (for String values)
  Widget _buildStyledRupeeText(String amount, {Color? color, double? fontSize, FontWeight? fontWeight}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '₹',
            style: TextStyle(
              color: color ?? Colors.green.shade700,
              fontSize: fontSize ?? 14,
              fontWeight: fontWeight ?? FontWeight.bold,
              fontFamily: 'Times New Roman',
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: amount,
            style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize ?? 14,
              fontWeight: fontWeight ?? FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Helper method to build styled rupee text (for double values)
  Widget _buildStyledRupeeAmount(double amount, {Color? color, double? fontSize, FontWeight? fontWeight}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '₹',
            style: TextStyle(
              color: color ?? Colors.green.shade700,
              fontSize: fontSize ?? 14,
              fontWeight: fontWeight ?? FontWeight.bold,
              fontFamily: 'Georgia',
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: PriceFormatter.format(amount),
            style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize ?? 14,
              fontWeight: fontWeight ?? FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(BookingSummaryViewModel(), permanent: false);
    final profileVm = Get.find<ProfileViewModel>();

    return PopScope(
      canPop: !vm.isUILocked.value && !vm.paymentSuccessConfirmed.value,
      onPopInvoked: (didPop) async {
        if (vm.isUILocked.value || vm.paymentSuccessConfirmed.value) {
          // ✅ Show a message to user when they try to go back during payment
          Get.snackbar(
            'Please Wait',
            vm.paymentSuccessConfirmed.value
                ? 'Your payment is successful. Please complete the process.'
                : 'Your payment is being processed...',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 1),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Booking Summary'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          leading: Obx(() => IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: (vm.isUILocked.value || vm.paymentSuccessConfirmed.value)
                ? null
                : () => Get.back(),
          )),
        ),
        body: Obx(() => Stack(
          children: [
            IgnorePointer(
              ignoring: vm.isUILocked.value || vm.paymentSuccessConfirmed.value,
              child: Opacity(
                opacity: (vm.isUILocked.value || vm.paymentSuccessConfirmed.value) ? 0.2 : 1.0,
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/byt-bg.png'),
                      fit: BoxFit.cover,
                      opacity: 0.3,
                    ),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: (vm.isUILocked.value || vm.paymentSuccessConfirmed.value)
                          ? const NeverScrollableScrollPhysics()
                          : const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTurfCard(vm),
                          const SizedBox(height: 16),
                          _buildBookingInfoCard(vm),
                          const SizedBox(height: 16),
                          _buildPaymentSummaryCard(vm),
                          const SizedBox(height: 16),
                          _buildDiscountSection(vm),
                          const SizedBox(height: 16),
                          const SizedBox(height: 24),
                          _buildBothPaymentButtons(context, vm, profileVm),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ✅ Show loading overlay during payment processing
            if (vm.isUILocked.value && !vm.paymentSuccessConfirmed.value)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing Payment...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait, do not press back',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        )),
      ),
    );
  }

  // ============================================================
  // ✅ Helper method to format requirements from discount model
  // ============================================================
  String _formatRequirements(Map<String, dynamic>? requirements) {
    if (requirements == null || requirements.isEmpty) return '';

    final parts = <String>[];
    if (requirements['min_slots'] != null) {
      parts.add('Min ${requirements['min_slots']} slots');
    }
    if (requirements['min_amount'] != null) {
      parts.add('Min ₹${requirements['min_amount']}');
    }
    if (requirements['time_range'] != null) {
      parts.add('${requirements['time_range']}');
    }
    if (requirements['days'] != null) {
      parts.add('${requirements['days']}');
    }
    return parts.join(' • ');
  }

  // ============================================================
  // ✅ DISCOUNT SECTION
  // ============================================================
  Widget _buildDiscountSection(BookingSummaryViewModel vm) {
    return Obx(() {
      if (vm.isLoadingDiscounts.value) {
        return _buildDiscountShimmer();
      }

      // ✅ Get number of selected slots
      final int selectedSlots = vm.selectedSlots.length;
      final int minSlots = vm.turf.minSlots;

      // ✅ Filter by payment type
      final validAdminDiscounts = vm.discountVm.adminDiscounts
          .where((d) =>
      _isDiscountValid(d) &&
          d.isApplicableForPaymentType(vm.selectedPaymentType)
      )
          .toList();

      final validPartnerDiscounts = vm.discountVm.partnerDiscounts
          .where((d) =>
      _isDiscountValid(d) &&
          d.isApplicableForPaymentType(vm.selectedPaymentType)
      )
          .toList();

      final hasValidAdmin = validAdminDiscounts.isNotEmpty;
      final hasValidPartner = validPartnerDiscounts.isNotEmpty;
      final bool hasDiscounts = hasValidAdmin || hasValidPartner;

      // ✅ CASE 1: Discounts exist but NOT enough slots - Show "Select minimum X slots"
      if (hasDiscounts && selectedSlots < minSlots) {
        return _buildMinimumSlotsMessage(vm);
      }

      // ✅ CASE 2: NO discounts available at all - Show "No discounts available"
      if (!hasDiscounts) {
        return _buildNoDiscountsMessage(vm);
      }

      // ✅ CASE 3: Discounts exist AND enough slots - Show coupon cards
      final hasSelected = vm.discountVm.hasSelectedDiscount;

      return Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasSelected ? Colors.green.shade200 : Colors.grey.shade100,
            width: hasSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: hasSelected
                  ? Colors.green.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: hasSelected ? Colors.green.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasSelected ? Icons.check_circle : Icons.local_offer,
                      size: 18,
                      color: hasSelected ? Colors.green.shade700 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hasSelected ? 'Offers Applied' : 'Available Offers',
                    style: TextStyle(
                      fontWeight: hasSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                      color: hasSelected ? Colors.green.shade700 : Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  // Payment type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: vm.selectedPaymentType == 'advance'
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      vm.selectedPaymentType == 'advance' ? 'Advance' : 'Full',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: vm.selectedPaymentType == 'advance'
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasSelected)
                    GestureDetector(
                      onTap: vm.removeAllDiscounts,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Remove All',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey.shade100),

            // Admin Discounts - Coupon Style
            if (hasValidAdmin) ...[
              _buildDiscountSectionHeader('App Offers', Icons.verified, Colors.blue),
              ...validAdminDiscounts.map((discount) {
                final isSelected = vm.isAdminDiscountSelected(discount.id);
                final validationMsg = _getDiscountValidationMessage(discount);
                return _buildCouponDiscountCard(
                  discount: discount,
                  isSelected: isSelected,
                  sourceLabel: 'App Discount',
                  onTap: () {
                    if (validationMsg != null) {
                      _showInvalidDiscountDialog(validationMsg);
                      return;
                    }
                    vm.toggleAdminDiscount(discount.id);
                  },
                  isLast: discount == validAdminDiscounts.last && !hasValidPartner,
                  validationMessage: validationMsg,
                );
              }).toList(),
            ],

            // Partner Discounts - Coupon Style
            if (hasValidPartner) ...[
              if (hasValidAdmin) const Divider(height: 1, color: Colors.grey),
              _buildDiscountSectionHeader('Venue Offers', Icons.storefront, Colors.purple),
              ...validPartnerDiscounts.map((discount) {
                final isSelected = vm.isPartnerDiscountSelected(discount.id);
                final validationMsg = _getDiscountValidationMessage(discount);
                return _buildCouponDiscountCard(
                  discount: discount,
                  isSelected: isSelected,
                  sourceLabel: 'Venue Discount',
                  onTap: () {
                    if (validationMsg != null) {
                      _showInvalidDiscountDialog(validationMsg);
                      return;
                    }
                    vm.togglePartnerDiscount(discount.id);
                  },
                  isLast: discount == validPartnerDiscounts.last,
                  validationMessage: validationMsg,
                );
              }).toList(),
            ],

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tap_and_play,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap any coupon to apply',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ✅ Minimum Slots Required Message (when discounts exist but slots < minSlots)
  Widget _buildMinimumSlotsMessage(BookingSummaryViewModel vm) {
    final int minSlots = vm.turf.minSlots;
    final int selectedSlots = vm.selectedSlots.length;
    final String paymentType = vm.selectedPaymentType == 'advance' ? 'Advance' : 'Full';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.info_outline,
              color: Colors.blue.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💰 Minimum Slots Required',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select minimum $minSlots slot${minSlots > 1 ? 's' : ''} to unlock discounts for $paymentType Payment (Currently selected: $selectedSlots slot${selectedSlots > 1 ? 's' : ''})',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ No Discounts Message (when no discounts exist at all)
  Widget _buildNoDiscountsMessage(BookingSummaryViewModel vm) {
    final String paymentType = vm.selectedPaymentType == 'advance' ? 'Advance' : 'Full';

    // ✅ Get requirements from any discount (even if not valid for this payment type)
    String requirementsText = '';
    if (vm.discountVm.adminDiscounts.isNotEmpty) {
      requirementsText = _formatRequirements(vm.discountVm.adminDiscounts.first.requirements);
    } else if (vm.discountVm.partnerDiscounts.isNotEmpty) {
      requirementsText = _formatRequirements(vm.discountVm.partnerDiscounts.first.requirements);
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No discounts available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          // ✅ Show requirements if exists
          if (requirementsText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📋 $requirementsText',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscountShimmer() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(2, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDiscountSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showInvalidDiscountDialog(String message) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Invalid Discount',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please select a discount with 99% or lower value.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // ============================================================
  // ✅ TICKET STYLE DISCOUNT CARD - NO REQUIREMENTS TEXT
  // ============================================================
  Widget _buildCouponDiscountCard({
    required DiscountModel discount,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLast,
    required String sourceLabel,
    String? validationMessage,
  }) {
    final isInvalid = validationMessage != null;

    final Color leftBoxColor = isInvalid
        ? Colors.grey.shade400
        : isSelected
        ? Colors.green.shade600
        : const Color(0xFFE8385A);

    final Color rightBgColor = isInvalid
        ? Colors.grey.shade100
        : isSelected
        ? Colors.green.shade50
        : const Color(0xFFF3EADD);

    final Color outerBg = isInvalid
        ? Colors.grey.shade200
        : isSelected
        ? Colors.green.shade100
        : const Color(0xFFEFE6D8);

    return Semantics(
      label:
      'Discount: ${discount.name}, ${discount.getDisplayText()}, ${isSelected ? 'Selected' : 'Tap to select'}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          height: 100,
          decoration: BoxDecoration(
            color: outerBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // ================= 1. LEFT: Percentage / value badge =================
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: leftBoxColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      discount.getDisplayText(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),

              // ================= MIDDLE: Perforated divider with notches =================
              SizedBox(
                width: 18,
                height: 100,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 1.5,
                      height: 100,
                      child: CustomPaint(
                        painter: _DashedLinePainter(
                          color: isInvalid
                              ? Colors.grey.shade400
                              : isSelected
                              ? Colors.green.shade300
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= RIGHT: Details (source label + name + save amount) =================
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: rightBgColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        sourceLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isInvalid
                              ? Colors.grey.shade600
                              : isSelected
                              ? Colors.green.shade800
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        discount.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isInvalid
                              ? Colors.grey.shade500
                              : isSelected
                              ? Colors.green.shade600
                              : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!isInvalid &&
                          discount.calculatedDiscount != null &&
                          discount.calculatedDiscount! > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 14,
                              color: isSelected
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Save ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.green.shade700
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '₹',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Georgia',
                                      color: isSelected
                                          ? Colors.green.shade800
                                          : Colors.black87,
                                    ),
                                  ),
                                  TextSpan(
                                    text: PriceFormatter.format(
                                        discount.calculatedDiscount!),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.green.shade800
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      if (isInvalid)
                        Text(
                          '⚠️ $validationMessage',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ================= 4. Selection indicator =================
              Container(
                width: 44,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rightBgColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isInvalid
                          ? Colors.grey.shade300
                          : isSelected
                          ? Colors.green
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected && !isInvalid ? Colors.green : Colors.transparent,
                  ),
                  child: isSelected && !isInvalid
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ PAYMENT SUMMARY - With Advance percentage next to label
  // ✅ Shows App Discount & Venue Discount separately
  // ✅ Fee Breakup - Click to expand and show Platform Fee & Convenience Fee
  // ============================================================
// ============================================================
// ✅ PAYMENT SUMMARY - With Advance percentage next to label
// ✅ Shows App Discount & Venue Discount separately
// ✅ Fee Breakup - Click to expand and show Platform Fee & Convenience Fee
// ✅ FIXED: RenderFlex overflow issue
// ============================================================
  Widget _buildPaymentSummaryCard(BookingSummaryViewModel vm) {
    // Calculate advance WITHOUT discount
    final double advanceWithoutDiscount = vm.totalAmount * (_calculateAdvancePercentageValue(vm) / 100);

    // Calculate discount amount
    final double totalDiscount = vm.isDiscountApplied ? vm.discountVm.totalDiscountAmount : 0.0;

    // ✅ Advance Remaining Balance = Advance Amount - Total Discount (only if discount is applied)
    final double advanceRemainingBalance = vm.isDiscountApplied
        ? advanceWithoutDiscount - totalDiscount
        : advanceWithoutDiscount;

    // Payable Now depends on payment type
    // For Advance: Advance Amount - Discount
    // For Full: Total Amount - Discount
    final double payableNow = vm.selectedPaymentType == 'advance'
        ? advanceWithoutDiscount - totalDiscount
        : vm.totalAmount - totalDiscount;

    // Balance to pay after advance (Total - Advance)
    final double balanceAfterAdvance = vm.totalAmount - advanceWithoutDiscount;

    // ✅ Get advance percentage
    final double advancePercentage = _calculateAdvancePercentageValue(vm);

    // ✅ Get individual discount amounts
    double appDiscountAmount = 0.0;
    double venueDiscountAmount = 0.0;

    if (vm.discountVm.selectedAdminDiscount != null) {
      appDiscountAmount = vm.discountVm.selectedAdminDiscount!.calculatedDiscount ?? 0.0;
    }
    if (vm.discountVm.selectedPartnerDiscount != null) {
      venueDiscountAmount = vm.discountVm.selectedPartnerDiscount!.calculatedDiscount ?? 0.0;
    }

    // ✅ Platform Fee & Convenience Fee (hardcoded to 0 for now)
    final double platformFee = 0.0;
    final double convenienceFee = 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // ✅ FIX: Use min to prevent overflow
          children: [
            const Text('Payment Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 12),

            // ✅ 1. Payment Method
            _infoRow(
              Icons.payment,
              'Payment Method',
              vm.selectedPaymentType == 'advance' ? 'Advance Payment' : 'Full Payment',
              iconColor: Colors.blue,
            ),
            const SizedBox(height: 8),

            const Divider(),
            const SizedBox(height: 8),

            // ✅ 2. Total Amount
            _buildStyledInfoRow(
              Icons.currency_rupee,
              'Total Amount',
              vm.totalAmount,
              iconColor: Colors.grey.shade700,
              bold: true,
              rupeeColor: Colors.blue.shade700,
              rupeeSize: 16,
            ),
            const SizedBox(height: 8),

            // ✅ 3. App Discount (if applied)
            if (appDiscountAmount > 0) ...[
              _buildStyledInfoRow(
                Icons.verified,
                'App Discount',
                -appDiscountAmount,
                iconColor: Colors.blue,
                rupeeColor: Colors.blue.shade800,
                bold: false,
                isNegative: true,
              ),
              const SizedBox(height: 4),
            ],

            // ✅ 4. Venue Discount (if applied)
            if (venueDiscountAmount > 0) ...[
              _buildStyledInfoRow(
                Icons.storefront,
                'Venue Discount',
                -venueDiscountAmount,
                iconColor: Colors.purple,
                rupeeColor: Colors.purple.shade800,
                bold: false,
                isNegative: true,
              ),
              const SizedBox(height: 4),
            ],

            // ✅ 5. Fee Breakup - Clickable text (FIXED: No overflow)
            Obx(() => Column(
              mainAxisSize: MainAxisSize.min, // ✅ FIX: Use min
              children: [
                GestureDetector(
                  onTap: () {
                    _showFeeBreakup.toggle();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ' Breakup',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showFeeBreakup.value
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
                // ✅ Expanded fee details - FIXED with SizeTransition or simple visibility
                if (_showFeeBreakup.value) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Platform Fee
                  _buildStyledInfoRow(
                    Icons.account_balance,
                    'Platform Fee',
                    platformFee,
                    iconColor: Colors.grey.shade600,
                    rupeeColor: Colors.grey.shade600,
                    bold: false,
                    fontSize: 13,
                    rupeeSize: 13,
                  ),
                  const SizedBox(height: 4),
                  // Convenience Fee
                  _buildStyledInfoRow(
                    Icons.handshake,
                    'Convenience Fee',
                    convenienceFee,
                    iconColor: Colors.grey.shade600,
                    rupeeColor: Colors.grey.shade600,
                    bold: false,
                    fontSize: 13,
                    rupeeSize: 13,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            )),

            const Divider(),

            // ✅ 6. Total Discount (if any discount applied)
            if (vm.selectedPaymentType == 'advance') ...[
              _buildAdvanceRowWithPercentage(
                Icons.forward,
                'Advance (${advancePercentage.toStringAsFixed(0)}%)',
                advanceWithoutDiscount,
                iconColor: Colors.orange,
                bold: true,
              ),
              const SizedBox(height: 8),
              if (vm.isDiscountApplied) ...[
                _buildStyledInfoRow(
                  Icons.local_offer,
                  'Total Discount',
                  -totalDiscount,
                  iconColor: Colors.green,
                  rupeeColor: Colors.green.shade800,
                  bold: true,
                  isNegative: true,
                ),
                const SizedBox(height: 8),
              ],
              // ✅ 7. Advance to Pay (Advance - Discount)
              _buildStyledInfoRow(
                Icons.account_balance,
                'Advance to Pay',
                advanceRemainingBalance,
                iconColor: Colors.purple,
                rupeeColor: Colors.purple.shade800,
                bold: true,
                fontSize: 14,
                rupeeSize: 15,
              ),
              const SizedBox(height: 8),
              const Divider(),

              // ✅ 8. Balance to Pay (Total - Advance)
              _buildStyledInfoRow(
                Icons.balance,
                'Balance to Pay',
                balanceAfterAdvance,
                iconColor: Colors.red,
                rupeeColor: Colors.red.shade800,
                bold: true,
              ),
              const SizedBox(height: 8),
            ],

            // ✅ 9. Payable Now (Final amount)
            const Divider(),
            _buildStyledInfoRow(
              Icons.account_balance_wallet,
              'Payable Now',
              payableNow,
              iconColor: Colors.green,
              rupeeColor: Colors.green.shade800,
              bold: true,
              fontSize: 16,
              rupeeSize: 18,
            ),
            const SizedBox(height: 4), // ✅ Small bottom padding
          ],
        ),
      ),
    );
  }
  // ✅ Advance Row - Shows AMOUNT only (percentage in label)
  Widget _buildAdvanceRowWithPercentage(
      IconData icon,
      String label,  // Now includes percentage like "Advance (50%)"
      double amount, {
        Color? iconColor,
        bool bold = false,
        double fontSize = 14,
      }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.green),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey, fontSize: 14))),
        Expanded(
          child: RichText(
            textAlign: TextAlign.end,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '₹',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                TextSpan(
                  text: PriceFormatter.format(amount),
                  style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    fontSize: fontSize,
                    color: bold ? Colors.black87 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Styled Info Row
  Widget _buildStyledInfoRow(
      IconData icon,
      String label,
      double amount, {
        Color? iconColor,
        bool bold = false,
        double fontSize = 14,
        Color? rupeeColor,
        double? rupeeSize,
        String? suffix,
        bool isNegative = false,
      }) {
    final displayAmount = isNegative ? amount.abs() : amount;
    final prefix = isNegative ? '-' : '';

    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.green),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey, fontSize: 14))),
        Expanded(
          child: RichText(
            textAlign: TextAlign.end,
            text: TextSpan(
              children: [
                if (prefix.isNotEmpty)
                  TextSpan(
                    text: prefix,
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                      fontSize: fontSize,
                      color: Colors.black87,
                    ),
                  ),
                TextSpan(
                  text: '₹',
                  style: TextStyle(
                    color: rupeeColor ?? Colors.green.shade700,
                    fontSize: rupeeSize ?? fontSize,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                    letterSpacing: 0.5,
                  ),
                ),
                TextSpan(
                  text: PriceFormatter.format(displayAmount),
                  style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    fontSize: fontSize,
                    color: bold ? Colors.black87 : Colors.black54,
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                      fontSize: fontSize,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Helper method to get advance percentage value as double
  double _calculateAdvancePercentageValue(BookingSummaryViewModel vm) {
    if (vm.totalAmount <= 0) return 0.0;

    final advanceType = vm.turf.advanceType ?? 'percentage';
    final advanceValue = vm.turf.advanceValue ?? 0.0;

    // Safely convert to double
    final double advanceValueDouble = (advanceValue is double)
        ? advanceValue
        : (advanceValue is int)
        ? advanceValue.toDouble()
        : (advanceValue is String)
        ? double.tryParse(advanceValue) ?? 0.0
        : 0.0;

    if (advanceType == 'percentage') {
      return advanceValueDouble;
    } else if (advanceType == 'fixed') {
      if (vm.totalAmount > 0) {
        return (advanceValueDouble / vm.totalAmount) * 100;
      }
    }

    // Default: calculate from walletAmountToPay
    if (vm.totalAmount > 0) {
      return (vm.walletAmountToPay / vm.totalAmount) * 100;
    }
    return 0.0;
  }

  // ============================================================
  // REST OF THE UI
  // ============================================================

  Widget _buildTurfCard(BookingSummaryViewModel vm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sports_cricket, size: 30, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vm.turf.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(vm.turf.gameType,
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(vm.turf.address,
                    style: const TextStyle(color: Colors.grey, fontSize: 14))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingInfoCard(BookingSummaryViewModel vm) {
    final courtTurfLabel = vm.turf.gameType.toLowerCase().contains('cricket') ||
        vm.turf.gameType.toLowerCase().contains('football')
        ? "Turf"
        : "Court";

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booking Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 12),
            _infoRow(Icons.calendar_today, 'Date', _formatDate(vm.selectedDate)),
            const SizedBox(height: 8),
            _infoRow(Icons.sports, 'Sport', vm.turf.gameType),
            const SizedBox(height: 8),
            _infoRow(Icons.sports_tennis, courtTurfLabel, '$courtTurfLabel ${vm.selectedCourt}'),
            const SizedBox(height: 8),
            _slotsInfoRow(vm),
          ],
        ),
      ),
    );
  }

  Widget _buildBothPaymentButtons(BuildContext context, BookingSummaryViewModel vm, ProfileViewModel profileVm) {
    final amountToPay = vm.walletAmountToPay;

    final bool isValidAmount = amountToPay > 0 && amountToPay <= vm.totalAmount;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('BYT Wallet Balance:', style: TextStyle(fontSize: 14)),
              Obx(() => RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '₹',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: profileVm.walletBalance.value >= amountToPay && isValidAmount
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    TextSpan(
                      text: PriceFormatter.format(profileVm.walletBalance.value),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: profileVm.walletBalance.value >= amountToPay && isValidAmount
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Obx(() => SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: (vm.isLoading.value || vm.isUILocked.value || vm.paymentSuccessConfirmed.value || !isValidAmount)
                ? null
                : () {
              if (profileVm.walletBalance.value < amountToPay) {
                _showInsufficientBalanceDialog(context, amountToPay, profileVm);
              } else {
                _showWalletPaymentConfirmation(context, vm, profileVm);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isValidAmount ? Colors.green : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: vm.isLoading.value
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Pay ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow.shade200,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  TextSpan(
                    text: PriceFormatter.format(amountToPay),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: ' via Wallet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )),
        if (!isValidAmount && vm.isDiscountApplied)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total amount cannot be zero or negative. Please remove some discounts.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Obx(() => SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: (vm.isLoading.value || vm.isUILocked.value || vm.paymentSuccessConfirmed.value || !isValidAmount)
                ? null
                : () => _showOnlinePaymentConfirmation(context, vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: isValidAmount ? Colors.blue : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: vm.isLoading.value
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Pay ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow.shade200,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  TextSpan(
                    text: PriceFormatter.format(vm.razorpayAmountToPay),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: ' via Online',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )),
        const SizedBox(height: 8),
        const Text('UPI | Credit/Debit Cards | Netbanking',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showOnlinePaymentConfirmation(BuildContext context, BookingSummaryViewModel vm) {
    final amountToPay = vm.razorpayAmountToPay;

    if (amountToPay <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Amount cannot be zero or negative. Please adjust discounts.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Online Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Amount: ',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  TextSpan(
                    text: PriceFormatter.format(amountToPay),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (vm.isDiscountApplied)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Total Discount: ${vm.discountAmountText}',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                ),
              ),
            const SizedBox(height: 8),
            const Text('You will be redirected to Razorpay payment gateway.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              vm.initiatePayment();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showWalletPaymentConfirmation(BuildContext context, BookingSummaryViewModel vm, ProfileViewModel profileVm) {
    final amountToPay = vm.walletAmountToPay;

    if (amountToPay <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Amount cannot be zero or negative. Please adjust discounts.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Wallet Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Amount: ',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  TextSpan(
                    text: PriceFormatter.format(amountToPay),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (vm.isDiscountApplied)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Total Discount: ${vm.discountAmountText}',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                ),
              ),
            if (vm.selectedPaymentType == 'advance')
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'BYT Wallet Balance: ',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    TextSpan(
                      text: '₹',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    TextSpan(
                      text: PriceFormatter.format(profileVm.walletBalance.value),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'After Payment: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  TextSpan(
                    text: PriceFormatter.format(profileVm.walletBalance.value - amountToPay),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              vm.initiateWalletPayment();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showInsufficientBalanceDialog(BuildContext context, double amountToPay, ProfileViewModel profileVm) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Insufficient Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Required: ',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  TextSpan(
                    text: PriceFormatter.format(amountToPay),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Balance: ',
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
                  TextSpan(
                    text: '₹',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  TextSpan(
                    text: PriceFormatter.format(profileVm.walletBalance.value),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Please recharge your BYT wallet to continue.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              showDialog(context: context, builder: (context) => const WalletRechargeDialog());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Recharge Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? iconColor, bool bold = false, double fontSize = 14}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.green),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey, fontSize: 14))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
              color: bold ? Colors.black87 : Colors.black54,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _slotsInfoRow(BookingSummaryViewModel vm) {
    final sortedSlots = vm.sortedSlots;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.access_time, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text('Slots', style: const TextStyle(color: Colors.grey, fontSize: 14))),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(sortedSlots.length, (index) {
              final slot = sortedSlots[index];
              final timeRange = slot.formattedTimeRange;
              final isNextDay = slot.isNextDay;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isNextDay ? Colors.purple.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isNextDay ? Colors.purple.shade300 : Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_filled, size: 14,
                          color: isNextDay ? Colors.purple.shade700 : Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text(timeRange,
                          style: TextStyle(fontWeight: FontWeight.w600,
                              color: isNextDay ? Colors.purple.shade800 : Colors.green.shade800))),
                      if (isNextDay)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(20)),
                          child: const Text("Next Day",
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day} ${_getMonthName(date.month)} ${date.year}";
  }

  String _getMonthName(int month) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[month - 1];
  }
}