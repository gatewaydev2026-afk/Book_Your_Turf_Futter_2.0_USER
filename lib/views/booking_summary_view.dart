// lib/views/booking_summary_view.dart
// ✅ Fixed: Full payment discounts (isFull: true) are now displayed properly

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/discount_model.dart';
import '../services/price_formatter.dart';
import '../view_models/booking_summary_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/main_page_view_model.dart';
import '../routes/app_routes.dart';
import '../views/wallet_recharge_dialog.dart';

class BookingSummaryView extends StatelessWidget {
  BookingSummaryView({super.key});

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

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(BookingSummaryViewModel(), permanent: false);
    final profileVm = Get.find<ProfileViewModel>();

    ever(vm.paymentSuccessConfirmed, (success) {
      if (success && !vm.hasShownSuccessPopup.value) {
        vm.hasShownSuccessPopup.value = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (Get.context != null) {
            _showPaymentSuccessPopup(vm);
          }
        });
      }
    });

    return PopScope(
      canPop: !vm.isUILocked.value,
      onPopInvoked: (didPop) async {
        if (vm.isUILocked.value) {
          if (vm.paymentSuccessConfirmed.value && !vm.hasShownSuccessPopup.value) {
            vm.hasShownSuccessPopup.value = true;
            _showPaymentSuccessPopup(vm);
          } else if (!vm.paymentSuccessConfirmed.value) {
            Get.snackbar(
              'Payment in Progress',
              'Please wait, your payment is being processed.',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
          }
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
            onPressed: vm.isUILocked.value ? null : () => Get.back(),
          )),
        ),
        body: Obx(() => Stack(
          children: [
            IgnorePointer(
              ignoring: vm.isUILocked.value,
              child: Opacity(
                opacity: vm.isUILocked.value ? 0.2 : 1.0,
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
                      physics: vm.isUILocked.value
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
                        'Please wait',
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

  void _showPaymentSuccessPopup(BookingSummaryViewModel vm) {
    if (Get.isDialogOpen ?? false) return;

    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 60,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PAYMENT SUCCESSFUL! 🎉',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Amount: ₹${PriceFormatter.format(vm.walletAmountToPay)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              if (vm.isDiscountApplied)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Total Discount: ${vm.discountAmountText}',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                vm.selectedPaymentType == 'advance'
                    ? 'Advance payment confirmed!\nBalance to be paid at venue.'
                    : 'Your booking has been fully confirmed!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        Get.offAllNamed(AppRoutes.mainPage);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (Get.isRegistered<MainPageViewModel>()) {
                            Get.find<MainPageViewModel>().changeTab(0);
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'GO HOME',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.offAllNamed(AppRoutes.mainPage);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (Get.isRegistered<MainPageViewModel>()) {
                            Get.find<MainPageViewModel>().changeTab(1);
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'VIEW BOOKINGS',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // ============================================================
  // ✅ DISCOUNT SECTION - FULL PAYMENT SUPPORT
  // ============================================================
  Widget _buildDiscountSection(BookingSummaryViewModel vm) {
    return Obx(() {
      if (vm.isLoadingDiscounts.value) {
        return _buildDiscountShimmer();
      }

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

      if (!hasValidAdmin && !hasValidPartner) {
        final paymentTypeDisplay = vm.selectedPaymentType == 'advance' ? 'Advance' : 'Full';
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No discounts available for $paymentTypeDisplay Payment.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        );
      }

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

            // Admin Discounts
            if (hasValidAdmin) ...[
              _buildDiscountSectionHeader('Platform Offers', Icons.verified, Colors.blue),
              ...validAdminDiscounts.map((discount) {
                final isSelected = vm.isAdminDiscountSelected(discount.id);
                final validationMsg = _getDiscountValidationMessage(discount);
                final isFull = discount.applicablePaymentType == 'full';
                return _buildDiscountCard(
                  discount: discount,
                  isSelected: isSelected,
                  onTap: () {
                    if (validationMsg != null) {
                      _showInvalidDiscountDialog(validationMsg);
                      return;
                    }
                    vm.toggleAdminDiscount(discount.id);
                  },
                  isLast: discount == validAdminDiscounts.last && !hasValidPartner,
                  validationMessage: validationMsg,
                  isFull: isFull,
                );
              }).toList(),
            ],

            // Partner Discounts
            if (hasValidPartner) ...[
              if (hasValidAdmin) const Divider(height: 1, color: Colors.grey),
              _buildDiscountSectionHeader('Venue Offers', Icons.storefront, Colors.purple),
              ...validPartnerDiscounts.map((discount) {
                final isSelected = vm.isPartnerDiscountSelected(discount.id);
                final validationMsg = _getDiscountValidationMessage(discount);
                final isFull = discount.applicablePaymentType == 'full';
                return _buildDiscountCard(
                  discount: discount,
                  isSelected: isSelected,
                  onTap: () {
                    if (validationMsg != null) {
                      _showInvalidDiscountDialog(validationMsg);
                      return;
                    }
                    vm.togglePartnerDiscount(discount.id);
                  },
                  isLast: discount == validPartnerDiscounts.last,
                  validationMessage: validationMsg,
                  isFull: isFull,
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
                      'Tap any valid offer to apply',
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
              height: 60,
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
  // ✅ DISCOUNT CARD - FULL PAYMENT SUPPORT (isFull: true)
  // ============================================================
  Widget _buildDiscountCard({
    required DiscountModel discount,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLast,
    String? validationMessage,
    bool isFull = false,
  }) {
    final isInvalid = validationMessage != null;

    return Semantics(
      label: 'Discount: ${discount.name}, ${discount.getDisplayText()}, ${isSelected ? 'Selected' : 'Tap to select'}',
      child: GestureDetector(
        onTap: isInvalid ? onTap : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isInvalid
                ? Colors.grey.shade50
                : isSelected
                ? Colors.green.shade50
                : isFull
                ? Colors.blue.shade50
                : Colors.white,
            border: isLast
                ? null
                : Border(
              bottom: BorderSide(
                color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ Discount Badge - Different color for Full Payment
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isInvalid
                      ? LinearGradient(
                    colors: [Colors.grey.shade400, Colors.grey.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : isSelected
                      ? LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : isFull
                      ? LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isSelected && !isInvalid ? Colors.green : isFull ? Colors.blue : Colors.orange)
                          .withOpacity(isInvalid ? 0.1 : 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        discount.getDisplayText().split(' ')[0],
                        style: TextStyle(
                          color: isInvalid ? Colors.grey.shade300 : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (discount.getDisplayText().split(' ').length > 1)
                        Text(
                          discount.getDisplayText().split(' ')[1],
                          style: TextStyle(
                            color: isInvalid ? Colors.grey.shade300 : Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ✅ Details - Expanded
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Name and badges
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          discount.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 13,
                            color: isInvalid
                                ? Colors.grey.shade500
                                : isSelected
                                ? Colors.green.shade700
                                : isFull
                                ? Colors.blue.shade700
                                : Colors.grey.shade900,
                          ),
                        ),
                        if (!isInvalid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: discount.getSourceColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              discount.getSourceBadge(),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: discount.getSourceColor(),
                              ),
                            ),
                          ),
                        // ✅ Payment Type Badge
                        if (!isInvalid && discount.applicablePaymentType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: discount.getPaymentTypeColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              discount.getPaymentTypeBadge(),
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                color: discount.getPaymentTypeColor(),
                              ),
                            ),
                          ),
                        // ✅ Application Type Badge (overall/payable)
                        if (!isInvalid && discount.discountApplicationType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: discount.getApplicationTypeColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              discount.getApplicationTypeBadge(),
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                color: discount.getApplicationTypeColor(),
                              ),
                            ),
                          ),
                        // ✅ Requirements Badge
                        if (!isInvalid && discount.requirements != null && discount.requirements!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Conditions Apply',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ),
                        // ✅ Usage Limit
                        if (!isInvalid && discount.usageLimit != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${discount.getRemainingUses() ?? 0} uses left',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        // ✅ Selected Badge
                        if (isSelected && !isInvalid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'SELECTED',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // ✅ FULL PAYMENT BADGE (shown when isFull is true)
                        if (isFull && !isInvalid && !isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.blueAccent],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.payment,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'FULL PAYMENT',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // ✅ "Full Only" badge (when payment type is full)
                        if (isFull && !isInvalid && !isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Full Only',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        if (isInvalid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 10,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'BLOCKED',
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Description
                    Text(
                      discount.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isInvalid ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                    // ✅ Requirements Display
                    if (!isInvalid && discount.requirements != null && discount.requirements!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _formatRequirements(discount.requirements!),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    // Validation message
                    if (validationMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '⚠️ $validationMessage',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Conditions
                    if (discount.getFullDescription().isNotEmpty && !isInvalid)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 11,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                discount.getFullDescription(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                  height: 1.3,
                                ),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ✅ Save amount
              if (discount.calculatedDiscount != null &&
                  discount.calculatedDiscount! > 0 &&
                  !isInvalid)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade100 : isFull ? Colors.blue.shade100 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.green.shade300 : isFull ? Colors.blue.shade300 : Colors.orange.shade300,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'Save ₹${PriceFormatter.format(discount.calculatedDiscount!)}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.green.shade700 : isFull ? Colors.blue.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),

              // ✅ Selection indicator
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isInvalid
                        ? Colors.grey.shade300
                        : isSelected
                        ? Colors.green
                        : isFull
                        ? Colors.blue
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                  color: isSelected && !isInvalid ? Colors.green : Colors.transparent,
                ),
                child: isSelected && !isInvalid
                    ? const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRequirements(Map<String, dynamic> requirements) {
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
  // ✅ PAYMENT BREAKDOWN
  // ============================================================

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

  Widget _buildPaymentSummaryCard(BookingSummaryViewModel vm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 12),
            _infoRow(Icons.currency_rupee, 'Total Amount', '₹${PriceFormatter.format(vm.totalAmount)}'),
            const SizedBox(height: 8),

            if (vm.isDiscountApplied)
              Column(
                children: [
                  if (vm.discountVm.selectedAdminDiscount != null)
                    _infoRow(
                      Icons.verified,
                      'Platform Discount',
                      '-₹${PriceFormatter.format(vm.discountVm.selectedAdminDiscount!.calculatedDiscount ?? 0)}',
                      iconColor: Colors.blue,
                    ),
                  if (vm.discountVm.selectedPartnerDiscount != null)
                    _infoRow(
                      Icons.storefront,
                      'Venue Discount',
                      '-₹${PriceFormatter.format(vm.discountVm.selectedPartnerDiscount!.calculatedDiscount ?? 0)}',
                      iconColor: Colors.purple,
                    ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.currency_rupee,
                    'Total Discount',
                    '-₹${PriceFormatter.format(vm.discountVm.totalDiscountAmount)}',
                    iconColor: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.currency_rupee,
                    'Discounted Total',
                    '₹${PriceFormatter.format(vm.discountedTotal.value)}',
                    iconColor: Colors.green,
                    bold: true,
                  ),
                  const SizedBox(height: 8),
                ],
              ),

            _infoRow(Icons.info_outline, 'Payment Type',
                vm.selectedPaymentType == 'advance' ? 'Advance Payment' : 'Full Payment'),

            if (vm.selectedPaymentType == 'advance') ...[
              const SizedBox(height: 8),
              _infoRow(Icons.numbers, 'Min Slots', '${vm.turf.minSlots} slot${vm.turf.minSlots > 1 ? 's' : ''}'),
              const SizedBox(height: 8),
              _infoRow(
                Icons.payment,
                'Advance to Pay',
                '₹${PriceFormatter.format(vm.walletAmountToPay)}',
                iconColor: Colors.green,
              ),
              const SizedBox(height: 8),
              _balanceToPayRow(vm),
            ],

            const Divider(),
            _infoRow(
              Icons.account_balance_wallet,
              'Payable Now',
              '₹${PriceFormatter.format(vm.walletAmountToPay)}',
              iconColor: Colors.green,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceToPayRow(BookingSummaryViewModel vm) {
    final amountToPay = vm.walletAmountToPay;
    final balanceToPay = vm.totalAmount - amountToPay;

    return Row(
      children: [
        const Icon(Icons.receipt, size: 18, color: Colors.red),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: const Text(
            'Balance to pay',
            style: TextStyle(color: Colors.red, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            '₹${PriceFormatter.format(balanceToPay)}',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.red,
            ),
          ),
        ),
      ],
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
              const Text('Wallet Balance:', style: TextStyle(fontSize: 14)),
              Obx(() => Text(
                '₹${PriceFormatter.format(profileVm.walletBalance.value)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: profileVm.walletBalance.value >= amountToPay && isValidAmount ? Colors.green : Colors.red,
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
            onPressed: (vm.isLoading.value || vm.isUILocked.value || !isValidAmount)
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
                : Text(
              isValidAmount
                  ? 'Pay ₹${PriceFormatter.format(amountToPay)} via Wallet'
                  : 'Invalid Amount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
            onPressed: (vm.isLoading.value || vm.isUILocked.value || !isValidAmount)
                ? null
                : () => _showOnlinePaymentConfirmation(context, vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: isValidAmount ? Colors.blue : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: vm.isLoading.value
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
              isValidAmount
                  ? 'Pay ₹${PriceFormatter.format(vm.razorpayAmountToPay)} via Razorpay'
                  : 'Invalid Amount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
            Text('Amount: ₹${PriceFormatter.format(amountToPay)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            Text('Amount: ₹${PriceFormatter.format(amountToPay)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (vm.isDiscountApplied)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Total Discount: ${vm.discountAmountText}',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                ),
              ),
            if (vm.selectedPaymentType == 'advance')
              Text('Wallet Balance: ₹${PriceFormatter.format(profileVm.walletBalance.value)}',
                  style: TextStyle(color: Colors.green.shade700)),
            const SizedBox(height: 8),
            Text('After Payment: ₹${PriceFormatter.format(profileVm.walletBalance.value - amountToPay)}',
                style: TextStyle(color: Colors.grey.shade700)),
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
            Text('Required: ₹${PriceFormatter.format(amountToPay)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Balance: ₹${PriceFormatter.format(profileVm.walletBalance.value)}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            const Text('Please recharge your wallet to continue.'),
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

  Widget _infoRow(IconData icon, String label, String value, {Color? iconColor, bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? Colors.green),
        const SizedBox(width: 8),
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14))),
        Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: 14))),
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
        SizedBox(width: 100, child: Text('Slots', style: const TextStyle(color: Colors.grey, fontSize: 14))),
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