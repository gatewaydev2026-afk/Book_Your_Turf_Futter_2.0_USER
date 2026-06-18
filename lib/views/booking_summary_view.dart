// views/booking_summary_view.dart - COMPLETE FIXED VERSION
// Shows exact full amount with proper decimals (₹3 not ₹3.00, ₹1.50 not ₹2)
// Date format: "15 June 2026" (Date Month Year)
// Shows success popup ONLY ONCE and navigates to bookings tab without splash screen

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../view_models/booking_summary_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/main_page_view_model.dart';
import '../routes/app_routes.dart';
import '../views/wallet_recharge_dialog.dart';

class BookingSummaryView extends StatelessWidget {
  BookingSummaryView({super.key});

  // Helper: Format price with decimals only when needed
  String _formatPrice(double price) {
    if (price == price.toInt()) {
      return price.toInt().toString();
    }
    // For prices with decimals like 1.50, show as 1.50
    String formatted = price.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  // Helper: Format date as "15 June 2026"
  String _formatDate(DateTime date) {
    return "${date.day} ${_getMonthName(date.month)} ${date.year}";
  }

  // Helper: Get month name
  String _getMonthName(int month) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final vm = Get.put(BookingSummaryViewModel(), permanent: false);
    final profileVm = Get.find<ProfileViewModel>();

    // Listen for payment success and show popup ONLY ONCE
    ever(vm.paymentSuccessConfirmed, (success) {
      if (success && !vm.hasShownSuccessPopup.value) {
        vm.hasShownSuccessPopup.value = true;
        // Add a small delay to ensure all data is saved
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
    // Check if dialog is already open
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
                'Amount: ₹${_formatPrice(vm.payableAmount)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                        Get.back(); // Close dialog
                        // Navigate to Home tab
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
                        Get.back(); // Close dialog
                        // Navigate to Bookings tab (NO SPLASH SCREEN)
                        Get.offAllNamed(AppRoutes.mainPage);
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (Get.isRegistered<MainPageViewModel>()) {
                            Get.find<MainPageViewModel>().changeTab(1); // 1 = Bookings tab
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
            // FIXED: Date format as "15 June 2026"
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
            // FIXED: Show exact total amount with proper decimals
            _infoRow(Icons.currency_rupee, 'Total Amount', '₹${_formatPrice(vm.totalAmount)}'),
            const SizedBox(height: 8),
            _infoRow(Icons.info_outline, 'Payment Type',
                vm.selectedPaymentType == 'advance' ? 'Advance Payment' : 'Full Payment'),
            if (vm.selectedPaymentType == 'advance') ...[
              const SizedBox(height: 8),
              _infoRow(Icons.numbers, 'Min Slots', '${vm.turf.minSlots} slot${vm.turf.minSlots > 1 ? 's' : ''}'),
              const SizedBox(height: 8),
              // FIXED: Show exact advance amount with proper decimals
              _infoRow(Icons.payment, 'Advance to Pay', '₹${_formatPrice(vm.payableAmount)}',
                  iconColor: Colors.green),
              const SizedBox(height: 8),
              // FIXED: Show exact balance amount with proper decimals
              _infoRow(Icons.receipt, 'Balance to pay', '₹${_formatPrice(vm.totalAmount - vm.payableAmount)}',
                  iconColor: Colors.orange),
            ],
            const Divider(),
            // FIXED: Show exact payable amount with proper decimals
            _infoRow(Icons.account_balance_wallet, 'Payable Now', '₹${_formatPrice(vm.payableAmount)}',
                iconColor: Colors.green, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildBothPaymentButtons(BuildContext context, BookingSummaryViewModel vm, ProfileViewModel profileVm) {
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
                '₹${_formatPrice(profileVm.walletBalance.value)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: profileVm.walletBalance.value >= vm.payableAmount ? Colors.green : Colors.red,
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
            onPressed: (vm.isLoading.value || vm.isUILocked.value)
                ? null
                : () {
              if (profileVm.walletBalance.value < vm.payableAmount) {
                _showInsufficientBalanceDialog(context, vm.payableAmount, profileVm);
              } else {
                _showWalletPaymentConfirmation(context, vm, profileVm);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: vm.isLoading.value
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Pay ₹${_formatPrice(vm.payableAmount)} via Wallet',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        )),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        Obx(() => SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: (vm.isLoading.value || vm.isUILocked.value)
                ? null
                : () => _showOnlinePaymentConfirmation(context, vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: vm.isLoading.value
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Pay Online via Razorpay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Online Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₹${_formatPrice(vm.payableAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (vm.selectedPaymentType == 'advance')
              Text('Advance Payment: ₹${_formatPrice(vm.payableAmount)}',
                  style: const TextStyle(fontSize: 12)),
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
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Wallet Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₹${_formatPrice(vm.payableAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (vm.selectedPaymentType == 'advance')
              Text('Advance Payment: ₹${_formatPrice(vm.payableAmount)}',
                  style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Wallet Balance: ₹${_formatPrice(profileVm.walletBalance.value)}',
                style: TextStyle(color: Colors.green.shade700)),
            const SizedBox(height: 8),
            Text('After Payment: ₹${_formatPrice(profileVm.walletBalance.value - vm.payableAmount)}',
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

  void _showInsufficientBalanceDialog(BuildContext context, double payableAmount, ProfileViewModel profileVm) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Insufficient Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Required: ₹${_formatPrice(payableAmount)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Balance: ₹${_formatPrice(profileVm.walletBalance.value)}',
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
}