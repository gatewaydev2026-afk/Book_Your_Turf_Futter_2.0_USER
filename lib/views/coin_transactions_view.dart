// views/coin_transactions_view.dart - UPDATED

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/coin_transaction_model.dart';
import '../view_models/coin_view_model.dart';

class CoinTransactionsView extends StatelessWidget {
  const CoinTransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final CoinViewModel vm = Get.find<CoinViewModel>();

    // ✅ Load coin data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.loadCoinData();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin Transactions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: () {
              vm.loadCoinData(forceRefresh: true); // ✅ Using loadCoinData
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
                Icon(Icons.monetization_on, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No coin transactions found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Obx(() => Text(
                  'Current Coins: ${vm.gameCoins.value}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                )),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    vm.loadCoinData(forceRefresh: true);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh', style: TextStyle(color: Colors.white)),
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
            await vm.loadCoinData(forceRefresh: true);
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

  Widget _buildFilterChips(CoinViewModel vm) {
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

  Widget _filterChip(CoinViewModel vm, String label, String value) {
    return Obx(() => FilterChip(
      label: Text(label),
      selected: vm.selectedFilter.value == value,
      onSelected: (_) => vm.setFilter(value),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green,
    ));
  }

  Widget _buildTransactionCard(CoinTransactionModel txn) {
    final isCredit = txn.isCredit;

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
                  txn.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  txn.formattedDateTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (txn.referenceId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ref: ${txn.referenceId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Balance: ${txn.previousBalance} → ${txn.currentBalance}',
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
                child: Text(
                  '${isCredit ? '+' : '-'} ${txn.amount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
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