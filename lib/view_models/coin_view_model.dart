// view_models/coin_view_model.dart
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/coin_transaction_model.dart';
import '../services/shared_prefs_helper.dart';

class CoinViewModel extends GetxController {
  final transactions = <CoinTransactionModel>[].obs;
  final filteredTransactions = <CoinTransactionModel>[].obs;
  final selectedFilter = 'all'.obs; // all, credit, debit
  final isLoading = false.obs;
  final gameCoins = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchCoinBalance();
    fetchTransactions();
  }

  Future<void> fetchCoinBalance() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/profile/');
      if (response.data['result'] == 'success') {
        final user = response.data['data'];
        gameCoins.value = user['game_coins'] ?? 0;
        print('Coin balance fetched: ${gameCoins.value}');
      }
    } catch (e) {
      print('Error fetching coin balance: $e');
    }
  }

  Future<void> fetchTransactions({String? type, String? status}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('No token found for coin transactions');
      return;
    }

    isLoading.value = true;
    print('Fetching coin transactions...');

    try {
      final dio = Get.find<Dio>();
      final queryParams = <String, dynamic>{};
      if (type != null && type != 'all') {
        queryParams['type'] = type;
      }
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await dio.get(
        '/user/coins/transactions/',
        queryParameters: queryParams,
      );

      print('Coin transactions response: ${response.data}');

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];
        print('Coin transactions count: ${data.length}');

        transactions.value = data
            .map((json) => CoinTransactionModel.fromJson(json))
            .toList();
        _applyFilter();
      } else {
        print('Failed to fetch coin transactions: ${response.data['message']}');
      }
    } catch (e) {
      print('Error fetching coin transactions: $e');
      if (e is DioException) {
        print('Dio error response: ${e.response?.data}');
        print('Dio error status: ${e.response?.statusCode}');
      }
    } finally {
      isLoading.value = false;
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
    print('Filtered transactions: ${filteredTransactions.length}');
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilter();
  }

  Future<void> refresh() async {
    await fetchCoinBalance();
    await fetchTransactions();
  }
}