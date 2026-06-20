// services/app_initializer.dart
// ✅ Only loads essential data (Profile + Turfs)

import 'package:get/get.dart';
import '../view_models/booking_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/home_view_model.dart';
import '../view_models/auth_view_model.dart';
import '../services/shared_prefs_helper.dart';

class AppInitializer {
  static bool _isInitialized = false;
  static DateTime? _initializationTime;
  static bool _isInitializing = false;

  static Future<void> initializeApp() async {
    // Prevent multiple initializations
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

    _isInitializing = true;

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║        LOADING ESSENTIAL DATA (ONLY WHAT\'S NEEDED)           ║');
    print('╚════════════════════════════════════════════════════════════╝');

    final startTime = DateTime.now();

    try {
      // ✅ ONLY LOAD PROFILE AND TURFS (Home screen)
      // These are needed immediately when app opens

      // 1. Load profile (needed for Home screen header)
      print('📡 Loading profile...');
      final profileVm = Get.find<ProfileViewModel>();
      await profileVm.fetchUser(forceRefresh: true);

      // 2. Load turfs (needed for Home screen)
      print('📡 Loading turfs...');
      final homeVm = Get.find<HomeViewModel>();
      await homeVm.loadHomeData();

      // ✅ DO NOT LOAD:
      // - Bookings (only needed when user opens Bookings tab)
      // - Wallet transactions (only needed when user opens Wallet)
      // - Coin transactions (only needed when user opens Coins)
      // These will be lazy-loaded when user navigates to those screens

      final elapsed = DateTime.now().difference(startTime);
      print('✅ Essential data loaded in ${elapsed.inMilliseconds}ms');

      _isInitialized = true;
      _initializationTime = DateTime.now();

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

    // Reset all ViewModel caches
    ProfileViewModel.resetCache();
    BookingViewModel.resetCache();
    // WalletViewModel.resetCache();
    // CoinViewModel.resetCache();

    print('🔄 App caches reset');
  }

  static bool isInitialized() {
    return _isInitialized;
  }
}