// services/app_initializer.dart
// ✅ Only loads essential data ONCE

import 'package:get/get.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import '../view_models/booking_view_model.dart';
import '../view_models/coin_view_model.dart';
import '../view_models/discount_view_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/home_view_model.dart';
import '../view_models/auth_view_model.dart';
import '../services/shared_prefs_helper.dart';
import '../view_models/wallet_view_model.dart';

class AppInitializer {
  static bool _isInitialized = false;
  static DateTime? _initializationTime;
  static bool _isInitializing = false;

  static Future<void> initializeApp() async {
    // ✅ Prevent multiple initializations
    if (_isInitialized) {
      print('⏭️ App already initialized (${DateTime.now().difference(_initializationTime!).inSeconds}s ago)');
      return;
    }

    if (_isInitializing) {
      print('⏭️ App initialization already in progress');
      return;
    }

    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 User not logged in, skipping data load');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping data load');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // ✅ Check if app was already initialized before logout
    if (!SharedPrefsHelper.isAppInitialized()) {
      print('🔄 App not initialized - fresh start');
    }

    _isInitializing = true;

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║        LOADING ESSENTIAL DATA (ONLY ONCE)                 ║');
    print('╚════════════════════════════════════════════════════════════╝');

    final startTime = DateTime.now();

    try {
      final cacheManager = Get.isRegistered<CacheManager>()
          ? Get.find<CacheManager>()
          : CacheManager();

      // ✅ Check if data is already cached and fresh
      bool needProfile = !cacheManager.hasCachedProfile || !cacheManager.isProfileFresh();
      bool needTurfs = !cacheManager.hasCachedTurfs || !cacheManager.isTurfsFresh();

      // 1️⃣ Load profile only if needed
      if (needProfile) {
        print('📡 Loading profile...');
        final profileVm = Get.find<ProfileViewModel>();
        await profileVm.fetchUser(forceRefresh: true);
      } else {
        print('⏭️ Profile already cached - using cache');
      }

      // 2️⃣ Load turfs only if needed
      if (needTurfs) {
        print('📡 Loading turfs...');
        final homeVm = Get.find<HomeViewModel>();
        await homeVm.loadHomeData(forceRefresh: true);
      } else {
        print('⏭️ Turfs already cached - using cache');
      }

      // ✅ DO NOT LOAD: Bookings, Wallet, Coins - Lazy loaded on demand

      final elapsed = DateTime.now().difference(startTime);
      print('✅ Essential data loaded in ${elapsed.inMilliseconds}ms');

      _isInitialized = true;
      _initializationTime = DateTime.now();

      // ✅ Mark app as initialized
      await SharedPrefsHelper.setAppInitialized(true);

    } catch (e) {
      print('❌ App initialization error: $e');
    } finally {
      _isInitializing = false;
    }

    print('═══════════════════════════════════════════════════════════════\n');
  }

  static void reset() {
    _isInitialized = false;
    _initializationTime = null;
    _isInitializing = false;

    // ✅ Reset app initialized flag
    SharedPrefsHelper.setAppInitialized(false);

    // ✅ Clear all caches
    if (Get.isRegistered<CacheManager>()) {
      Get.find<CacheManager>().clearAllCaches();
    }

    // Reset all ViewModel caches
    ProfileViewModel.resetCache();
    BookingViewModel.resetCache();
    WalletViewModel.resetCache();
    CoinViewModel.resetCache();
    FavoritesViewModel.resetCache();
    DiscountViewModel.resetCache();

    print('🔄 App caches reset - Fresh start on next login');
  }

  static bool isInitialized() {
    return _isInitialized;
  }
}