// views/wallet_transactions_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/wallet_transaction_model.dart';
import '../view_models/wallet_view_model.dart';

class WalletTransactionsView extends StatelessWidget {
  const WalletTransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final WalletViewModel vm = Get.find<WalletViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Transactions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: () {
              vm.fetchWalletBalance();
              vm.fetchTransactions();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: _buildFilterChips(vm),
        ),
      ),
      body: Obx(() {
        if (vm.isLoading.value && vm.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.filteredTransactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No transactions found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Obx(() => Text(
                  'Current Balance: ₹${vm.walletBalance.value.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                )),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    vm.fetchWalletBalance();
                    vm.fetchTransactions();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh',style: TextStyle(color: Colors.white),),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await vm.fetchWalletBalance();
            await vm.fetchTransactions();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.filteredTransactions.length,
            itemBuilder: (context, index) {
              final txn = vm.filteredTransactions[index];
              return _buildTransactionCard(txn);
            },
          ),
        );
      }),
    );
  }

  Widget _buildFilterChips(WalletViewModel vm) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip(vm, 'All', 'all'),
          const SizedBox(width: 8),
          _filterChip(vm, 'Credits', 'credit'),
          const SizedBox(width: 8),
          _filterChip(vm, 'Debits', 'debit'),
        ],
      ),
    );
  }

  Widget _filterChip(WalletViewModel vm, String label, String value) {
    return Obx(() => FilterChip(
      label: Text(label),
      selected: vm.selectedFilter.value == value,
      onSelected: (_) => vm.setFilter(value),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green,
    ));
  }

  Widget _buildTransactionCard(WalletTransactionModel txn) {
    final isCredit = txn.isCredit;

    // Get description from API
    String displayDescription = txn.description;
    if (displayDescription.isEmpty) {
      if (isCredit) {
        displayDescription = 'Amount Credited';
      } else {
        displayDescription = 'Amount Debited';
      }
    }

    // Get reference ID if available
    String refId = '';
    if (txn.referenceId.isNotEmpty) {
      refId = 'Ref: ${txn.referenceId}';
    } else if (txn.razorpayOrderId != null && txn.razorpayOrderId!.isNotEmpty) {
      String orderId = txn.razorpayOrderId!;
      refId = 'Order: ${orderId.length > 12 ? orderId.substring(0, 12) : orderId}...';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isCredit ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? Colors.green : Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayDescription,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Use formattedDateTime from model (converts UTC to local)
                Text(
                  txn.formattedDateTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (refId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      refId,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                // Show balance info from API
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Balance: ₹${txn.previousBalance.toStringAsFixed(2)} → ₹${txn.currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: txn.isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'} ₹${txn.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isCredit ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: txn.isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  txn.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: txn.isSuccess ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}