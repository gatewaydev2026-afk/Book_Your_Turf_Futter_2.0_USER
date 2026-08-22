// view_models/favorites_view_model.dart
// ✅ Complete as per API documentation
// ✅ Fetches all favorited turfs
// ✅ Uses same turf serializer as list API
// ✅ Sync with HomeViewModel

import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/turf_model.dart';
import '../services/shared_prefs_helper.dart';
import '../routes/app_routes.dart';
import 'home_view_model.dart';

class FavoritesViewModel extends GetxController {
  final favorites = <TurfModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // ✅ Cache control
  static bool _dataLoaded = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 1);

  // ✅ Reference to HomeViewModel for sync
  HomeViewModel? _homeVm;

  @override
  void onInit() {
    super.onInit();
    print('📋 FavoritesViewModel initialized');

    // ✅ Get reference to HomeViewModel
    try {
      _homeVm = Get.find<HomeViewModel>();
    } catch (e) {
      print('⚠️ HomeViewModel not yet available');
    }
  }

  // ✅ Sync with HomeViewModel favorites
  void syncWithHomeViewModel() {
    try {
      _homeVm ??= Get.find<HomeViewModel>();
      if (_homeVm != null) {
        final homeFavorites = _homeVm!.getFavoritedTurfs();
        if (homeFavorites.isNotEmpty && favorites.isEmpty) {
          favorites.assignAll(homeFavorites.map((t) => t.copyWith(isFavorite: true)));
          print('🔄 Synced ${favorites.length} favorites from HomeViewModel');
        }
      }
    } catch (e) {
      print('⚠️ Could not sync with HomeViewModel: $e');
    }
  }

  // ✅ Call this when user opens Favorites screen
  Future<void> loadFavorites({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 No token, skipping favorites fetch');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping favorites fetch');
      await SharedPrefsHelper.clearToken();
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    // ✅ Try to sync from HomeViewModel first
    if (!forceRefresh && favorites.isEmpty) {
      syncWithHomeViewModel();
      if (favorites.isNotEmpty) {
        print('✅ Using favorites from HomeViewModel');
        return;
      }
    }

    // ✅ Check cache
    if (!forceRefresh && _dataLoaded && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration) {
        print('⏭️ Favorites cached (${age.inSeconds}s old) - using cache');
        return;
      }
    }

    if (!forceRefresh && _dataLoaded && favorites.isNotEmpty) {
      print('⏭️ Favorites already loaded (${favorites.length} favorites)');
      return;
    }

    await _fetchFavorites(forceRefresh: forceRefresh);
  }

  // ✅ Private fetch method
  Future<void> _fetchFavorites({bool forceRefresh = false}) async {
    print('📡 Fetching favorites from API...');
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/favorites/');

      print('📥 Favorites API Response: ${response.data}');

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];

        // ✅ Parse turfs with is_favorited = true
        favorites.value = data.map((json) {
          final turf = TurfModel.fromJson(json);
          return turf.copyWith(isFavorite: true);
        }).toList();

        _dataLoaded = true;
        _lastFetchTime = DateTime.now();

        print('✅ Favorites fetched: ${favorites.length} turfs');

        // ✅ Update HomeViewModel favorites
        _updateHomeViewModelFavorites();

        // ✅ Log discount labels
        for (var turf in favorites) {
          if (turf.bestDiscountLabel != null && turf.bestDiscountLabel!.isNotEmpty) {
            print('   🏷️ ${turf.name}: ${turf.bestDiscountLabel}');
          }
        }
      } else {
        errorMessage.value = response.data['message'] ?? 'Failed to load favorites';
        print('❌ API error: ${errorMessage.value}');
      }
    } catch (e) {
      print('❌ Error fetching favorites: $e');
      errorMessage.value = 'Failed to load favorites';
    } finally {
      isLoading.value = false;
    }
  }

  // ✅ Update HomeViewModel favorites
  void _updateHomeViewModelFavorites() {
    try {
      _homeVm ??= Get.find<HomeViewModel>();
      if (_homeVm != null) {
        _homeVm!.refreshFavoritesList();
      }
    } catch (e) {
      print('⚠️ Could not update HomeViewModel: $e');
    }
  }

  // ✅ Remove a favorite locally (after unliking)
  void removeFavoriteLocally(int turfId) {
    favorites.removeWhere((t) => t.id == turfId);

    // ✅ Also remove from HomeViewModel
    try {
      _homeVm ??= Get.find<HomeViewModel>();
      if (_homeVm != null) {
        _homeVm!.removeFavoriteLocally(turfId);
      }
    } catch (e) {
    }
  }

  // ✅ Add a favorite locally (after liking)
  void addFavoriteLocally(TurfModel turf) {
    if (!favorites.any((t) => t.id == turf.id)) {
      favorites.add(turf.copyWith(isFavorite: true));

      // ✅ Also add to HomeViewModel
      try {
        _homeVm ??= Get.find<HomeViewModel>();
        if (_homeVm != null) {
          _homeVm!.addFavoriteLocally(turf);
        }
      } catch (e) {
      }
    }
  }

  // ✅ Refresh favorites
  Future<void> refreshFavorites() async {
    _dataLoaded = false;
    await loadFavorites(forceRefresh: true);
  }

  // ✅ Check if a turf is favorited
  bool isFavorited(int turfId) {
    return favorites.any((t) => t.id == turfId);
  }

  // ✅ Get favorite count
  int get favoriteCount => favorites.length;

  // ✅ Reset cache
  static void resetCache() {
    _dataLoaded = false;
    _lastFetchTime = null;
  }

  @override
  void onClose() {
    super.onClose();
  }
}