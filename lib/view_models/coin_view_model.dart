// view_models/coin_view_model.dart - FIXED DUPLICATE API CALLS

import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/coin_transaction_model.dart';
import '../services/shared_prefs_helper.dart';
import 'profile_view_model.dart';

class CoinViewModel extends GetxController {
  final transactions = <CoinTransactionModel>[].obs;
  final filteredTransactions = <CoinTransactionModel>[].obs;
  final selectedFilter = 'all'.obs;
  final isLoading = false.obs;
  final gameCoins = 0.obs;

  // ✅ Cache and loading flags
  static bool _transactionsLoaded = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 1);
  static bool _isFetching = false; // ✅ NEW: Prevent duplicate calls

  @override
  void onInit() {
    super.onInit();
    print('📋 CoinViewModel initialized (lazy loading - will fetch when needed)');

    if (Get.isRegistered<ProfileViewModel>()) {
      gameCoins.value = Get.find<ProfileViewModel>().gameCoins.value;
    }
  }

  // ✅ Call this method ONLY when user opens Coins screen
  Future<void> loadCoinData({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 No token, skipping coin data load');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping coin data load');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // ✅ Prevent duplicate calls while fetching
    if (_isFetching) {
      print('⏭️ Coin data already being fetched, skipping duplicate...');
      return;
    }

    // Get coins from profile if available
    if (Get.isRegistered<ProfileViewModel>()) {
      final profileVm = Get.find<ProfileViewModel>();
      gameCoins.value = profileVm.gameCoins.value;
      print('✅ Coin balance from profile: ${gameCoins.value}');
    }

    // Check cache before fetching transactions
    if (!forceRefresh && _transactionsLoaded && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration) {
        print('⏭️ Coin transactions cached (${age.inSeconds}s old) - using cache');
        return;
      }
    }

    if (!forceRefresh && _transactionsLoaded && transactions.isNotEmpty) {
      print('⏭️ Coin transactions already loaded (${transactions.length} transactions)');
      return;
    }

    await _fetchTransactions(forceRefresh: forceRefresh);
  }

  // ✅ Private method with loading flag
  Future<void> _fetchTransactions({bool forceRefresh = false}) async {
    // ✅ Prevent duplicate calls
    if (_isFetching) {
      print('⏭️ Coin transactions fetch already in progress...');
      return;
    }

    _isFetching = true;
    print('📡 Fetching coin transactions from API...');
    isLoading.value = true;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/coins/transactions/');

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];
        transactions.value = data
            .map((json) => CoinTransactionModel.fromJson(json))
            .toList();

        _applyFilter();
        _transactionsLoaded = true;
        _lastFetchTime = DateTime.now();

        print('✅ Coin transactions fetched: ${transactions.length} transactions');
      }
    } catch (e) {
      print('❌ Error fetching coin transactions: $e');
    } finally {
      isLoading.value = false;
      _isFetching = false;
    }
  }

  void _applyFilter() {
    if (selectedFilter.value == 'all') {
      filteredTransactions.value = transactions;
    } else {
      filteredTransactions.value = transactions
          .where((t) => t.transactionType.toLowerCase() == selectedFilter.value)
          .toList();
    }
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilter();
  }

  Future<void> refreshCoins() async {
    _transactionsLoaded = false;
    await loadCoinData(forceRefresh: true);
  }

  static void resetCache() {
    _transactionsLoaded = false;
    _lastFetchTime = null;
    _isFetching = false;
  }
}