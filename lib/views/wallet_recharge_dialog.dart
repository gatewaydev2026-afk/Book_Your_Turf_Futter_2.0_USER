// lib/views/wallet_recharge_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../view_models/wallet_view_model.dart';
import '../services/notification_service.dart';

class WalletRechargeDialog extends StatefulWidget {
  const WalletRechargeDialog({super.key});

  @override
  State<WalletRechargeDialog> createState() => _WalletRechargeDialogState();
}

class _WalletRechargeDialogState extends State<WalletRechargeDialog> {
  final TextEditingController _amountController = TextEditingController();
  final WalletViewModel _walletVm = Get.find<WalletViewModel>();

  // Quick amounts including ₹1 and ₹5
  final List<double> _quickAmounts = [500, 1000, 2000, 5000, 10000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Recharge Wallet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.currency_rupee),
                hintText: 'Enter amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickAmounts.map((amount) {
                return ElevatedButton(
                  onPressed: () {
                    _amountController.text = amount.toStringAsFixed(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(40, 36),
                  ),
                  child: Text('₹${amount.toStringAsFixed(0)}'),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(
                        () => ElevatedButton(
                      onPressed: _walletVm.isRecharging.value
                          ? null
                          : () async {
                        final amount = double.tryParse(_amountController.text);
                        if (amount != null && amount >= 500) {
                          Get.back();
                          await _walletVm.initiateRecharge(amount);

                          // ✅ ADD NOTIFICATION AFTER SUCCESSFUL RECHARGE
                          // Note: This will be called after payment success
                          // The actual notification is already in wallet_view_model.dart
                          // This is just for reference
                        } else {
                          Get.snackbar(
                            'Invalid Amount',
                            'Please enter a valid amount (Minimum ₹500)',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _walletVm.isRecharging.value
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Proceed',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Minimum recharge amount is ₹500',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}