// lib/services/cache_manager.dart
// ✅ Centralized cache management with single API call guarantee
// ✅ Duplicate API call prevention with debounce

import 'dart:async';
import 'dart:ui';
import 'package:get/get.dart';
import 'package:book_your_turf/config/app_config.dart';

class CacheManager extends GetxService {
  // ============================================================
  // 🔒 SINGLE API CALL FLAGS
  // ============================================================
  static bool _isProfileFetching = false;
  static bool _isTurfsFetching = false;
  static bool _isBookingsFetching = false;
  static bool _isWalletFetching = false;
  static bool _isCoinsFetching = false;
  static bool _isFavoritesFetching = false;
  static bool _isDiscountsFetching = false;
  static bool _isNotificationsFetching = false;

  // ============================================================
  // 📅 LAST FETCH TIMES
  // ============================================================
  static DateTime? _lastProfileFetch;
  static DateTime? _lastTurfsFetch;
  static DateTime? _lastBookingsFetch;
  static DateTime? _lastWalletFetch;
  static DateTime? _lastCoinsFetch;
  static DateTime? _lastFavoritesFetch;
  static DateTime? _lastDiscountsFetch;
  static DateTime? _lastNotificationsFetch;

  // ============================================================
  // 📦 CACHED DATA
  // ============================================================
  static Map<String, dynamic>? _cachedProfile;
  static List<dynamic>? _cachedTurfs;
  static List<dynamic>? _cachedBookings;
  static List<dynamic>? _cachedWalletTransactions;
  static List<dynamic>? _cachedCoinTransactions;
  static List<dynamic>? _cachedFavorites;
  static Map<String, dynamic>? _cachedDiscounts;
  static List<dynamic>? _cachedNotifications;

  // ============================================================
  // ⏱️ MINIMUM FETCH INTERVAL - Prevent rapid duplicate calls
  // ============================================================
  static final Map<String, DateTime> _lastFetchTimes = {};
  static const _minFetchInterval = AppConfig.minFetchInterval;

  // ============================================================
  // 🔄 DEBOUNCE
  // ============================================================
  static Timer? _debounceTimer;
  static const _debounceDuration = AppConfig.refreshDebounceDuration;

  // ============================================================
  // 🔓 PUBLIC GETTERS
  // ============================================================

  bool get hasCachedProfile => _cachedProfile != null;
  bool get hasCachedTurfs => _cachedTurfs != null;
  bool get hasCachedBookings => _cachedBookings != null;
  bool get hasCachedWallet => _cachedWalletTransactions != null;
  bool get hasCachedCoins => _cachedCoinTransactions != null;
  bool get hasCachedFavorites => _cachedFavorites != null;
  bool get hasCachedDiscounts => _cachedDiscounts != null;
  bool get hasCachedNotifications => _cachedNotifications != null;

  bool get isProfileFetching => _isProfileFetching;
  bool get isTurfsFetching => _isTurfsFetching;
  bool get isBookingsFetching => _isBookingsFetching;
  bool get isWalletFetching => _isWalletFetching;
  bool get isCoinsFetching => _isCoinsFetching;
  bool get isFavoritesFetching => _isFavoritesFetching;
  bool get isDiscountsFetching => _isDiscountsFetching;
  bool get isNotificationsFetching => _isNotificationsFetching;

  // ============================================================
  // ✅ CHECK IF CACHE IS FRESH
  // ============================================================

  bool isProfileFresh() {
    if (_lastProfileFetch == null) return false;
    return DateTime.now().difference(_lastProfileFetch!) < AppConfig.profileCacheDuration;
  }

  bool isTurfsFresh() {
    if (_lastTurfsFetch == null) return false;
    return DateTime.now().difference(_lastTurfsFetch!) < AppConfig.cacheDuration;
  }

  bool isBookingsFresh() {
    if (_lastBookingsFetch == null) return false;
    return DateTime.now().difference(_lastBookingsFetch!) < AppConfig.bookingCacheDuration;
  }

  bool isWalletFresh() {
    if (_lastWalletFetch == null) return false;
    return DateTime.now().difference(_lastWalletFetch!) < AppConfig.walletCacheDuration;
  }

  bool isCoinsFresh() {
    if (_lastCoinsFetch == null) return false;
    return DateTime.now().difference(_lastCoinsFetch!) < AppConfig.coinCacheDuration;
  }

  bool isFavoritesFresh() {
    if (_lastFavoritesFetch == null) return false;
    return DateTime.now().difference(_lastFavoritesFetch!) < AppConfig.cacheDuration;
  }

  bool isDiscountsFresh() {
    if (_lastDiscountsFetch == null) return false;
    return DateTime.now().difference(_lastDiscountsFetch!) < AppConfig.discountCacheDuration;
  }

  bool isNotificationsFresh() {
    if (_lastNotificationsFetch == null) return false;
    return DateTime.now().difference(_lastNotificationsFetch!) < AppConfig.notificationCacheDuration;
  }

  // ============================================================
  // ✅ CAN FETCH - Check minimum interval
  // ============================================================

  bool canFetch(String key, {bool forceRefresh = false}) {
    if (forceRefresh) return true;

    final lastTime = _lastFetchTimes[key];
    if (lastTime == null) return true;

    final elapsed = DateTime.now().difference(lastTime);
    return elapsed >= _minFetchInterval;
  }

  void recordFetch(String key) {
    _lastFetchTimes[key] = DateTime.now();
  }

  // ============================================================
  // 🔄 DEBOUNCE WRAPPER
  // ============================================================

  void debounce(String key, VoidCallback action, {Duration delay = const Duration(milliseconds: 500)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (canFetch(key)) {
        action();
        recordFetch(key);
      } else {
        print('⏭️ Debounced fetch skipped for: $key');
      }
    });
  }

  // ============================================================
  // 📥 GET CACHED DATA
  // ============================================================

  Map<String, dynamic>? getCachedProfile() => _cachedProfile;
  List<dynamic>? getCachedTurfs() => _cachedTurfs;
  List<dynamic>? getCachedBookings() => _cachedBookings;
  List<dynamic>? getCachedWalletTransactions() => _cachedWalletTransactions;
  List<dynamic>? getCachedCoinTransactions() => _cachedCoinTransactions;
  List<dynamic>? getCachedFavorites() => _cachedFavorites;
  Map<String, dynamic>? getCachedDiscounts() => _cachedDiscounts;
  List<dynamic>? getCachedNotifications() => _cachedNotifications;

  // ============================================================
  // 📤 SET CACHED DATA
  // ============================================================

  void setCachedProfile(Map<String, dynamic> data) {
    _cachedProfile = data;
    _lastProfileFetch = DateTime.now();
    _isProfileFetching = false;
    recordFetch('profile');
  }

  void setCachedTurfs(List<dynamic> data) {
    _cachedTurfs = data;
    _lastTurfsFetch = DateTime.now();
    _isTurfsFetching = false;
    recordFetch('turfs');
  }

  void setCachedBookings(List<dynamic> data) {
    _cachedBookings = data;
    _lastBookingsFetch = DateTime.now();
    _isBookingsFetching = false;
    recordFetch('bookings');
  }

  void setCachedWalletTransactions(List<dynamic> data) {
    _cachedWalletTransactions = data;
    _lastWalletFetch = DateTime.now();
    _isWalletFetching = false;
    recordFetch('wallet');
  }

  void setCachedCoinTransactions(List<dynamic> data) {
    _cachedCoinTransactions = data;
    _lastCoinsFetch = DateTime.now();
    _isCoinsFetching = false;
    recordFetch('coins');
  }

  void setCachedFavorites(List<dynamic> data) {
    _cachedFavorites = data;
    _lastFavoritesFetch = DateTime.now();
    _isFavoritesFetching = false;
    recordFetch('favorites');
  }

  void setCachedDiscounts(Map<String, dynamic> data) {
    _cachedDiscounts = data;
    _lastDiscountsFetch = DateTime.now();
    _isDiscountsFetching = false;
    recordFetch('discounts');
  }

  void setCachedNotifications(List<dynamic> data) {
    _cachedNotifications = data;
    _lastNotificationsFetch = DateTime.now();
    _isNotificationsFetching = false;
    recordFetch('notifications');
  }

  // ============================================================
  // 🔄 SET FETCHING FLAGS
  // ============================================================

  bool startProfileFetch() {
    if (_isProfileFetching) return false;
    _isProfileFetching = true;
    return true;
  }

  bool startTurfsFetch() {
    if (_isTurfsFetching) return false;
    _isTurfsFetching = true;
    return true;
  }

  bool startBookingsFetch() {
    if (_isBookingsFetching) return false;
    _isBookingsFetching = true;
    return true;
  }

  bool startWalletFetch() {
    if (_isWalletFetching) return false;
    _isWalletFetching = true;
    return true;
  }

  bool startCoinsFetch() {
    if (_isCoinsFetching) return false;
    _isCoinsFetching = true;
    return true;
  }

  bool startFavoritesFetch() {
    if (_isFavoritesFetching) return false;
    _isFavoritesFetching = true;
    return true;
  }

  bool startDiscountsFetch() {
    if (_isDiscountsFetching) return false;
    _isDiscountsFetching = true;
    return true;
  }

  bool startNotificationsFetch() {
    if (_isNotificationsFetching) return false;
    _isNotificationsFetching = true;
    return true;
  }

  // ============================================================
  // 🔓 RELEASE FETCHING FLAGS
  // ============================================================
  // ✅ FIX: start*Fetch() only ever ACQUIRES the lock (sets flag -> true and
  // returns whether it succeeded). There was no matching "release" method, so
  // callers were mistakenly calling start*Fetch() again inside their `finally`
  // blocks hoping it would reset the flag - it doesn't. On error paths (where
  // setCached*() is never reached) the flag was never cleared at all, and even
  // on success paths re-calling start*Fetch() in `finally` re-armed the lock
  // right after setCached*() had just cleared it. Net effect: after the first
  // fetch (success OR failure), the flag got stuck `true` forever and every
  // future load call silently skipped itself.
  //
  // Use these in your view model's `finally` block instead of start*Fetch().

  void endProfileFetch() {
    _isProfileFetching = false;
  }

  void endTurfsFetch() {
    _isTurfsFetching = false;
  }

  void endBookingsFetch() {
    _isBookingsFetching = false;
  }

  void endWalletFetch() {
    _isWalletFetching = false;
  }

  void endCoinsFetch() {
    _isCoinsFetching = false;
  }

  void endFavoritesFetch() {
    _isFavoritesFetching = false;
  }

  void endDiscountsFetch() {
    _isDiscountsFetching = false;
  }

  void endNotificationsFetch() {
    _isNotificationsFetching = false;
  }

  // ============================================================
  // 🗑️ CLEAR ALL CACHES
  // ============================================================

  void clearAllCaches() {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  🗑️ CLEARING ALL CACHES - COMPLETE RESET                  ║');
    print('╚════════════════════════════════════════════════════════════╝');

    _cachedProfile = null;
    _cachedTurfs = null;
    _cachedBookings = null;
    _cachedWalletTransactions = null;
    _cachedCoinTransactions = null;
    _cachedFavorites = null;
    _cachedDiscounts = null;
    _cachedNotifications = null;

    _lastProfileFetch = null;
    _lastTurfsFetch = null;
    _lastBookingsFetch = null;
    _lastWalletFetch = null;
    _lastCoinsFetch = null;
    _lastFavoritesFetch = null;
    _lastDiscountsFetch = null;
    _lastNotificationsFetch = null;

    _isProfileFetching = false;
    _isTurfsFetching = false;
    _isBookingsFetching = false;
    _isWalletFetching = false;
    _isCoinsFetching = false;
    _isFavoritesFetching = false;
    _isDiscountsFetching = false;
    _isNotificationsFetching = false;

    _lastFetchTimes.clear();
    _debounceTimer?.cancel();

    print('✅ All caches cleared successfully');
    print('═══════════════════════════════════════════════════════════════\n');
  }

  // ============================================================
  // 📊 CACHE STATUS
  // ============================================================

  String getCacheStatus() {
    return '''
    📊 CACHE STATUS:
    ─────────────────────────────────
    Profile: ${_cachedProfile != null ? '✅ Cached' : '❌ Empty'} (${isProfileFresh() ? 'Fresh' : 'Stale'})
    Turfs: ${_cachedTurfs != null ? '✅ Cached' : '❌ Empty'} (${isTurfsFresh() ? 'Fresh' : 'Stale'})
    Bookings: ${_cachedBookings != null ? '✅ Cached' : '❌ Empty'} (${isBookingsFresh() ? 'Fresh' : 'Stale'})
    Wallet: ${_cachedWalletTransactions != null ? '✅ Cached' : '❌ Empty'} (${isWalletFresh() ? 'Fresh' : 'Stale'})
    Coins: ${_cachedCoinTransactions != null ? '✅ Cached' : '❌ Empty'} (${isCoinsFresh() ? 'Fresh' : 'Stale'})
    Favorites: ${_cachedFavorites != null ? '✅ Cached' : '❌ Empty'} (${isFavoritesFresh() ? 'Fresh' : 'Stale'})
    Discounts: ${_cachedDiscounts != null ? '✅ Cached' : '❌ Empty'} (${isDiscountsFresh() ? 'Fresh' : 'Stale'})
    Notifications: ${_cachedNotifications != null ? '✅ Cached' : '❌ Empty'} (${isNotificationsFresh() ? 'Fresh' : 'Stale'})
    ─────────────────────────────────
    ''';
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}