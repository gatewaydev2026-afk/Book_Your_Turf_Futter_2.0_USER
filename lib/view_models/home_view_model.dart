// home_view_model.dart - Complete Updated Version
// ✅ Search shows ALL matching turfs from any state
// ✅ No location filter for search
// ✅ Guest mode supported
// ✅ Small snackbar with 1-second duration at TOP
// ✅ FIX (Sep 2026): Load-more APPENDS results – items already on screen never disappear
//    (search mode used to replace the list with only the next page)
// ✅ FIX (Sep 2026): Category filter kept after load-more / refresh
// ✅ FIX (Sep 2026): Header location label no longer stays stale (e.g. wrong city)
// ✅ Meta: fb_mobile_search logged on API search
// ✅ FIX (Sep 2026 #2): ONE turfs API call at start-up (was 3-5)
//    • fetchTurfs is single-flight: parallel callers wait for the same request
//    • same page / same query / same area within 10s → no new call
//    • location lookup is single-flight; background GPS refresh only refetches
//      when the user actually moved > 1 km
//    • no location permission → turfs still load (API works without lat/lng)
//    • 401 retry no longer re-enters a running fetch

import 'dart:async';
import 'dart:convert';
import 'package:book_your_turf/config/app_config.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/turf_model.dart';
import '../routes/app_routes.dart';
import '../services/location_service.dart';
import '../services/meta_events_service.dart';
import '../services/shared_prefs_helper.dart';

class HomeViewModel extends GetxController {
  final turfs = <TurfModel>[].obs;
  final allTurfs = <TurfModel>[].obs;
  final nearbyTurfs = <TurfModel>[].obs;
  final searchResults = <TurfModel>[].obs;
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isLoadingMore = false.obs;
  final searchQuery = ''.obs;
  final selectedCategory = ''.obs;
  final showSuggestions = false.obs;
  final homeError = ''.obs;
  final isSearching = false.obs;

  final isGuestMode = false.obs;

  final currentLocation = Rx<Position?>(null);
  final isLocationLoading = true.obs;
  final locationError = ''.obs;
  final currentLocationName = ''.obs;

  // ✅ true only when the label was geocoded from a GPS fix in THIS session
  bool _locationLabelVerified = false;

  // ✅ The query that the CURRENT result list was fetched with.
  // Typing in the box (without pressing search) does not change it,
  // so "load more" always continues the same search.
  String _activeApiQuery = '';
  // ✅ Full API search result list (searchResults is also used for typing suggestions)
  final List<TurfModel> _apiSearchList = <TurfModel>[];
  // ✅ Nearby-list pagination saved while a search is active
  int _savedNearbyPage = 1;
  bool _savedNearbyHasMore = true;

  void _endApiSearch() {
    if (_activeApiQuery.isEmpty) return;
    _activeApiQuery = '';
    _apiSearchList.clear();
    _currentPage = _savedNearbyPage;
    _hasMoreData = _savedNearbyHasMore;
    print('🔙 Search ended - nearby pagination restored (page $_currentPage, hasMore $_hasMoreData)');
  }

  final Map<String, List<String>> _suggestionCache = {};
  Timer? _searchDebounceTimer;

  DateTime? _lastRefreshTime;
  bool _isRefreshingLock = false;

  bool _initialFetchDone = false;
  bool _isFetching = false;
  int _apiCallCount = 0;

  DateTime? _lastFetchTime;
  static const _cacheDuration = AppConfig.cacheDuration;

  final Set<int> _favoriteIds = <int>{};
  final isFavoritesLoading = false.obs;

  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreData = true;
  static const int _pageSize = AppConfig.defaultPageSize;

  DateTime? _lastTurfsFetchTime;
  static const _minFetchInterval = Duration(seconds: 5);
  Timer? _locationDebounceTimer;
  static const _locationDebounceDuration = Duration(seconds: 2);
  bool _isRefreshingFromLocation = false;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMoreData => _hasMoreData;
  int get pageSize => _pageSize;

  // ============================================================
  // ✅ SHOW CUSTOM SMALL SNACKBAR AT TOP
  // ============================================================
  void _showSmallSnackbar(String title, String message, Color color) {
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: Colors.black,
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 8,
      maxWidth: 300,
      barBlur: 0,
      overlayBlur: 0,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOut,
      reverseAnimationCurve: Curves.easeIn,
      animationDuration: const Duration(milliseconds: 300),
      icon: Icon(
        color == Colors.red ? Icons.error_outline : Icons.check_circle,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  // ============================================================
  // ✅ SINGLE-FLIGHT STATE
  // ============================================================
  Future<void>? _initFuture;
  Future<void>? _fetchInFlight;
  Future<void>? _locationFuture;
  String? _lastCompletedKey;
  DateTime? _lastCompletedAt;
  Position? _lastFetchPosition;
  static const _sameRequestWindow = Duration(seconds: 10);
  // 3 km: a last-known GPS fix can be 1–2 km off the fresh one, which used to
  // trigger a second full turfs load right after start-up.
  static const double _refetchDistanceKm = 3.0;

  /// ~1 km grid so tiny GPS jitter does not count as a "new" request
  String _requestKey() {
    final p = currentLocation.value;
    final pos = p == null
        ? 'nopos'
        : '${(p.latitude * 100).round()},${(p.longitude * 100).round()}';
    return '$_activeApiQuery|$pos';
  }

  @override
  void onInit() {
    super.onInit();
    print('🏠 HomeViewModel initialized');

    final token = SharedPrefsHelper.getToken();
    isGuestMode.value = (token == null || token.isEmpty);
    print('👤 Guest Mode: ${isGuestMode.value}');

    _loadFavoritesFromStorage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFuture ??= _initializeLocationAndFetch();
    });
  }

  Future<void> _initializeLocationAndFetch() async {
    print('📍 Initializing location and fetching turfs...');
    // ✅ Show cached turfs instantly (no spinner) while the fresh call runs
    if (allTurfs.isEmpty) _loadFromCache();
    await getUserLocation();
    // ✅ Fetch even without location - API returns turfs without distance
    await fetchTurfs(forceRefresh: true);
  }

  void _loadFromCache() {
    if (SharedPrefsHelper.isTurfsCacheValid()) {
      final cachedTurfsJson = SharedPrefsHelper.getCachedTurfs();
      if (cachedTurfsJson != null) {
        print('📦 Loading turfs from cache as fallback');
        try {
          final List<dynamic> cachedData = jsonDecode(cachedTurfsJson);
          final cachedTurfs = cachedData.map((json) => TurfModel.fromJson(json)).toList();
          final turfsWithFavorites = cachedTurfs.map((turf) {
            return turf.copyWith(isFavorite: _favoriteIds.contains(turf.id));
          }).toList();
          allTurfs.assignAll(turfsWithFavorites);
          _initialFetchDone = true;
          _applyLocationFilter();
          _lastFetchTime = DateTime.now();
          print('✅ Loaded ${allTurfs.length} turfs from cache');
        } catch (e) {
          print('❌ Error parsing cached turfs: $e');
        }
      }
    }
  }

  @override
  void onClose() {
    print('🏠 HomeViewModel closing');
    _searchDebounceTimer?.cancel();
    _locationDebounceTimer?.cancel();
    super.onClose();
  }

  // ========== LOAD HOME DATA ==========
  Future<void> loadHomeData({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      isGuestMode.value = true;
    } else if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, switching to guest mode');
      await SharedPrefsHelper.clearToken();
      isGuestMode.value = true;
    }

    // ✅ Start-up load already running / done → reuse it
    if (_initFuture == null) {
      _initFuture = _initializeLocationAndFetch();
      await _initFuture;
      return;
    }
    await _initFuture;

    if (!forceRefresh && _initialFetchDone && allTurfs.isNotEmpty && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration) {
        print('✅ Home data still fresh (${age.inSeconds}s old) - no API call');
        return;
      }
    }

    if (currentLocation.value == null) {
      await getUserLocation();
    }
    await fetchTurfs(forceRefresh: true);
  }

  // ========== GET USER LOCATION (single-flight) ==========
  Future<void> getUserLocation() {
    final running = _locationFuture;
    if (running != null) return running;
    final f = _getUserLocationInternal();
    _locationFuture = f;
    f.whenComplete(() {
      if (identical(_locationFuture, f)) _locationFuture = null;
    });
    return f;
  }

  Future<void> _getUserLocationInternal() async {
    final cachedLocation = SharedPrefsHelper.getDeviceLocation();
    final isLocationValid = await SharedPrefsHelper.isLocationValid();

    if (cachedLocation != null && cachedLocation.isNotEmpty && isLocationValid) {
      currentLocationName.value = cachedLocation;
      print('📍 Using cached location: $cachedLocation');
      // ✅ Use the last known GPS fix right away so the first API call has lat/lng
      if (currentLocation.value == null) {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) currentLocation.value = last;
        } catch (e) {
          print('⚠️ Last known position unavailable: $e');
        }
      }
      isLocationLoading.value = false;
      _getFreshLocationInBackground();
      return;
    }

    isLocationLoading.value = true;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          locationError.value = 'Location permission denied';
          currentLocationName.value = 'Location denied';
          isLocationLoading.value = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        locationError.value = 'Location permission permanently denied';
        currentLocationName.value = 'Enable location in settings';
        isLocationLoading.value = false;
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      currentLocation.value = position;
      locationError.value = '';
      print('📍 Got coordinates: ${position.latitude}, ${position.longitude}');

      await _updateLocationNameFromCoordinates(position);

    } catch (e) {
      print('❌ Location error: $e');
      locationError.value = 'Unable to get location';
      currentLocationName.value = 'Location unavailable';
    } finally {
      isLocationLoading.value = false;
    }
  }

  Future<void> _getFreshLocationInBackground() async {
    _locationDebounceTimer?.cancel();
    _locationDebounceTimer = Timer(_locationDebounceDuration, () async {
      if (_isRefreshingFromLocation) {
        print('⏭️ Location refresh already in progress');
        return;
      }
      _isRefreshingFromLocation = true;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
        currentLocation.value = position;
        await _updateLocationNameFromCoordinates(position);

        // ✅ Only call the API again if the user really moved
        final last = _lastFetchPosition;
        final movedKm = last == null
            ? double.infinity
            : LocationService.calculateDistance(
                last.latitude, last.longitude, position.latitude, position.longitude);
        if (movedKm >= _refetchDistanceKm && _activeApiQuery.isEmpty) {
          print('📍 Moved ${movedKm.isFinite ? movedKm.toStringAsFixed(1) : '?'} km - refreshing turfs');
          await fetchTurfs(forceRefresh: true);
        } else {
          print('📍 Location unchanged (${movedKm.toStringAsFixed(2)} km) - no API call');
        }
      } catch (e) {
        print('⚠️ Background location fetch failed: $e');
      } finally {
        _isRefreshingFromLocation = false;
      }
    });
  }

  Future<void> _updateLocationNameFromCoordinates(Position position) async {
    // ✅ Skip the paid Google Geocoding call when we already have a name
    //    for (almost) the same spot
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLat = prefs.getDouble('geo_last_lat');
      final lastLng = prefs.getDouble('geo_last_lng');
      final cachedName = SharedPrefsHelper.getDeviceLocation();
      if (lastLat != null &&
          lastLng != null &&
          cachedName != null &&
          cachedName.isNotEmpty &&
          await SharedPrefsHelper.isLocationValid()) {
        final km = LocationService.calculateDistance(
            lastLat, lastLng, position.latitude, position.longitude);
        if (km < 0.5) {
          currentLocationName.value = cachedName;
          _locationLabelVerified = true;
          print('📍 Geocode skipped (moved ${km.toStringAsFixed(2)} km)');
          return;
        }
      }
    } catch (_) {}

    try {
      final url = Uri.parse(AppConfig.geocodeUrl(position.latitude, position.longitude));

      print('📍 Calling Google Maps API...');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = data['results'];
          if (results.isNotEmpty) {
            String area = '';
            String city = '';
            String state = '';

            final components = results[0]['address_components'] as List;
            for (var comp in components) {
              final types = comp['types'] as List;
              if (area.isEmpty && (types.contains('sublocality_level_1') ||
                  types.contains('sublocality') ||
                  types.contains('neighborhood') ||
                  types.contains('route'))) {
                area = comp['long_name'];
              }
              if (types.contains('locality') && city.isEmpty) {
                city = comp['long_name'];
              }
              if (types.contains('administrative_area_level_1') && state.isEmpty) {
                state = comp['long_name'];
              }
            }

            String locationName = "";
            if (area.isNotEmpty && city.isNotEmpty && area != city) {
              locationName = "$area, $city";
            } else if (city.isNotEmpty && state.isNotEmpty) {
              locationName = "$city, $state";
            } else if (city.isNotEmpty) {
              locationName = city;
            } else if (area.isNotEmpty) {
              locationName = area;
            } else {
              locationName = results[0]['formatted_address'];
            }

            currentLocationName.value = locationName;
            _locationLabelVerified = true;
            await SharedPrefsHelper.saveDeviceLocation(locationName);
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('geo_last_lat', position.latitude);
              await prefs.setDouble('geo_last_lng', position.longitude);
            } catch (_) {}
            print('📍 Location saved: "$locationName"');
          }
        } else {
          print('⚠️ Google Maps API status: ${data['status']}');
          _setFallbackLocationLabel();
        }
      } else {
        print('⚠️ Geocode HTTP ${response.statusCode}');
        _setFallbackLocationLabel();
      }
    } catch (e) {
      print('❌ Error getting location name: $e');
      _setFallbackLocationLabel();
    }
  }

  // ============================================================
  // ✅ LOCATION LABEL FALLBACK / SANITY CHECK
  // Never keep an old cached city name (e.g. "Hyderabad") when the
  // turfs being listed are clearly somewhere else.
  // ============================================================
  TurfModel? _nearestTurf() {
    TurfModel? nearest;
    for (final t in nearbyTurfs) {
      final d = t.distanceKm;
      if (d == null) continue;
      if (nearest == null || d < (nearest.distanceKm ?? double.infinity)) {
        nearest = t;
      }
    }
    return nearest;
  }

  void _setFallbackLocationLabel() {
    final nearest = _nearestTurf();
    if (nearest != null &&
        (nearest.distanceKm ?? 999) <= 30 &&
        nearest.district.trim().isNotEmpty) {
      currentLocationName.value = 'Near ${nearest.district.trim()}';
    } else {
      currentLocationName.value = 'Your location';
    }
    _locationLabelVerified = false;
  }

  void _validateLocationLabelAgainstTurfs() {
    if (_locationLabelVerified) return;
    final nearest = _nearestTurf();
    if (nearest == null) return;
    final district = nearest.district.trim();
    if (district.isEmpty || (nearest.distanceKm ?? 999) > 30) return;
    final label = currentLocationName.value.toLowerCase();
    if (!label.contains(district.toLowerCase())) {
      print('📍 Cached label "$label" does not match nearby turfs ($district) - correcting');
      currentLocationName.value = 'Near $district';
    }
  }

  // ============================================================
  // ✅ FETCH TURFS - UPDATED FOR SEARCH
  // ✅ Search: NO location parameters - shows ALL matching turfs
  // ============================================================
  Future<void> fetchTurfs({
    bool forceRefresh = false,
    bool loadMore = false,
    bool userInitiated = false,
  }) async {
    // ✅ Another request is running
    final running = _fetchInFlight;
    if (running != null) {
      if (loadMore) {
        print('⏳ Fetch running - load-more skipped');
        return;
      }
      print('⏳ Fetch running - waiting for it instead of calling again');
      await running;
      if (_fetchInFlight != null) return; // somebody already started the next one
      if (!userInitiated && _lastCompletedKey == _requestKey()) return;
    }

    // ✅ Same first-page request finished a moment ago → nothing to do
    if (!loadMore &&
        !userInitiated &&
        _lastCompletedKey == _requestKey() &&
        _lastCompletedAt != null &&
        DateTime.now().difference(_lastCompletedAt!) < _sameRequestWindow &&
        allTurfs.isNotEmpty) {
      print('⏭️ Same turfs request done ${DateTime.now().difference(_lastCompletedAt!).inSeconds}s ago - skipped');
      return;
    }

    final completer = Completer<void>();
    _fetchInFlight = completer.future;
    bool retryAsGuest = false;
    try {
      retryAsGuest = await _fetchTurfsInternal(
        forceRefresh: forceRefresh,
        loadMore: loadMore,
      );
    } finally {
      _fetchInFlight = null;
      completer.complete();
    }

    if (retryAsGuest) {
      print('🔑 Retrying turfs as guest');
      await fetchTurfs(forceRefresh: true, userInitiated: true);
    }
  }

  /// Returns true when the call failed with 401 and should be retried as guest.
  Future<bool> _fetchTurfsInternal({
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    final token = SharedPrefsHelper.getToken();
    final bool hasToken = token != null && token.isNotEmpty;

    isGuestMode.value = !hasToken;
    print('👤 Fetching turfs - Guest Mode: ${isGuestMode.value}');

    if (hasToken && !SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, clearing and continuing as guest');
      await SharedPrefsHelper.clearToken();
      isGuestMode.value = true;
    }

    if (!forceRefresh && !loadMore && _lastTurfsFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastTurfsFetchTime!);
      if (elapsed < _minFetchInterval) {
        print('⏭️ Turfs fetch skipped (${elapsed.inMilliseconds}ms since last fetch)');
        return false;
      }
    }

    // ✅ For search mode - NO location check needed
    if (currentLocation.value == null && !loadMore && _activeApiQuery.isEmpty) {
      print('📍 No location, fetching location first...');
      await getUserLocation();
      if (currentLocation.value == null) {
        print('⚠️ No location - loading turfs without distance');
      }
    }

    if (!loadMore && !forceRefresh && _initialFetchDone && allTurfs.isNotEmpty) {
      print('✅ Data already loaded');
      return false;
    }

    if (loadMore && !_hasMoreData) {
      print('⏭️ No more data to load');
      return false;
    }

    _isFetching = true;
    final String requestKey = _requestKey();
    if (_activeApiQuery.isEmpty && !loadMore) {
      _lastFetchPosition = currentLocation.value;
    }
    // ✅ Remember which search this request belongs to
    final String requestQuery = _activeApiQuery;
    if (loadMore) {
      isLoadingMore.value = true;
    } else {
      isLoading.value = true;
      _currentPage = 1;
      _hasMoreData = true;
    }
    _apiCallCount++;
    homeError.value = '';

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  🏟️ FETCH TURFS API CALL #$_apiCallCount                     ║');
    print('║  📄 Page: $_currentPage, Page Size: $_pageSize                ║');
    print('║  👤 Guest Mode: ${isGuestMode.value}                          ║');
    if (_activeApiQuery.isNotEmpty) {
      print('║  🔍 SEARCH: "${_activeApiQuery}" (NO LOCATION FILTER)     ║');
      print('║  📍 ALL TURFS FROM ANY STATE WILL SHOW                     ║');
    } else {
      print('║  📍 Location: ${currentLocation.value != null ? "Available" : "None"}');
    }
    print('╚════════════════════════════════════════════════════════════╝');

    try {
      final dio = Get.find<Dio>();

      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (!isGuestMode.value) {
        final currentToken = SharedPrefsHelper.getToken();
        if (currentToken != null && currentToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $currentToken';
          print('🔑 Using token for authenticated request');
        } else {
          isGuestMode.value = true;
          print('👤 No token available, switching to guest mode');
        }
      } else {
        print('👤 Guest mode: No token in request');
      }

      Map<String, dynamic> queryParams = {
        'page': _currentPage,
        'page_size': _pageSize,
      };

      // ============================================================
      // ✅ CRITICAL FIX: SEARCH MODE - NO LOCATION PARAMETERS
      // ============================================================
      if (_activeApiQuery.isNotEmpty) {
        // ✅ ONLY send search parameter - NO lat, lng, radius
        queryParams['search'] = _activeApiQuery;
        print('🔍 SEARCH: "${_activeApiQuery}" - NO location filter applied');
        print('📍 Results will include turfs from ALL STATES');
      } else {
        // ✅ Normal mode - use location filter
        if (currentLocation.value != null) {
          queryParams['lat'] = currentLocation.value!.latitude.toString();
          queryParams['lng'] = currentLocation.value!.longitude.toString();
          queryParams['radius'] = AppConfig.maxDistanceKm.toString();
          print('📍 Location params: lat=${queryParams['lat']}, lng=${queryParams['lng']}, radius=${queryParams['radius']}');
        } else {
          print('⚠️ No location available - API will return all turfs without distance');
        }
      }

      print('📡 API GET /user/turfs/ with params: $queryParams');
      print('🔑 Auth: ${isGuestMode.value ? "No token (Guest)" : "With token"}');

      final response = await dio.get(
        AppConfig.turfs,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      print('📥 API Response Status: ${response.statusCode}');

      // ✅ User changed / cleared the search while this page was loading →
      // ignore this response so it never mixes into the wrong list.
      if (_activeApiQuery != requestQuery) {
        print('⏭️ Search changed during fetch ("$requestQuery" → "${_activeApiQuery}") - ignoring response');
        return false;
      }

      if (response.data['result'] == 'success') {
        final data = response.data['data'];
        final List<dynamic> results = data['results'] ?? [];
        final int count = data['count'] ?? 0;
        final String? next = data['next'];
        final String? previous = data['previous'];

        _hasMoreData = next != null && next.isNotEmpty;
        _totalPages = (count / _pageSize).ceil();
        _currentPage = data['current_page'] ?? _currentPage;

        print('📊 Pagination: Total=$count, Pages=$_totalPages, Current=${_currentPage}, HasMore=$_hasMoreData');
        print('📦 Received ${results.length} turfs');

        final fetchedTurfs = results.map((json) => TurfModel.fromJson(json)).toList();
        final turfsWithFavorites = fetchedTurfs.map((turf) {
          return turf.copyWith(isFavorite: _favoriteIds.contains(turf.id));
        }).toList();

        // ✅ Drop duplicates (a page can repeat items if data changed)
        final List<TurfModel> newTurfs;
        if (loadMore) {
          final existingIds = allTurfs.map((t) => t.id).toSet();
          newTurfs = turfsWithFavorites.where((t) => !existingIds.contains(t.id)).toList();
          allTurfs.addAll(newTurfs);
          print('✅ Added ${newTurfs.length} turfs (total: ${allTurfs.length})');
        } else {
          newTurfs = turfsWithFavorites;
          allTurfs.assignAll(turfsWithFavorites);
          print('✅ Loaded ${allTurfs.length} turfs');
        }

        _initialFetchDone = true;

        // ✅ LOAD MORE = APPEND ONLY. Items already visible stay in place.
        if (_activeApiQuery.isNotEmpty) {
          if (loadMore) {
            _appendApiSearchResults(newTurfs);
          } else {
            _applyApiSearchResults(turfsWithFavorites);
          }
        } else {
          if (loadMore) {
            _appendNearbyTurfs(newTurfs);
          } else {
            _applyLocationFilter();
          }
        }

        _lastRefreshTime = DateTime.now();
        _lastFetchTime = DateTime.now();
        _lastTurfsFetchTime = DateTime.now();
        if (!loadMore) {
          _lastCompletedKey = requestKey;
          _lastCompletedAt = DateTime.now();
        }

        if (!loadMore) {
          await SharedPrefsHelper.cacheTurfs(jsonEncode(results));
          print('✅ Turfs cached');
        }

        if (_hasMoreData) {
          _currentPage++;
          print('📄 Next page will be: $_currentPage');
        } else {
          print('📄 No more pages');
        }

      } else {
        homeError.value = 'Failed to load turfs';
        print('❌ API Error: ${response.data['message']}');
      }
    } catch (e) {
      print('❌ Error: $e');
      homeError.value = 'Failed to load turfs';

      if (e is DioException && e.response?.statusCode == 401 && !isGuestMode.value) {
        print('🔑 Auth error - switching to guest mode and retrying...');
        isGuestMode.value = true;
        await SharedPrefsHelper.clearToken();
        return true;
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
      _isFetching = false;
    }
    return false;
  }

  // ============================================================
  // ✅ APPLY API SEARCH RESULTS - ALL MATCHING TURFS
  // ============================================================
  void _applyApiSearchResults(List<TurfModel> fetchedTurfs) {
    print('🔍 Applying API search results for: "${searchQuery.value}"');
    print('🔍 Total matching turfs from API: ${fetchedTurfs.length}');
    print('📍 These include turfs from ALL STATES');

    searchResults.assignAll(fetchedTurfs);
    _apiSearchList
      ..clear()
      ..addAll(fetchedTurfs);

    var sorted = List<TurfModel>.from(fetchedTurfs);
    sorted.sort((a, b) {
      final aIsFav = _favoriteIds.contains(a.id);
      final bIsFav = _favoriteIds.contains(b.id);
      if (aIsFav && !bIsFav) return -1;
      if (!aIsFav && bIsFav) return 1;

      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      if (aDist != bDist) return aDist.compareTo(bDist);

      return a.name.compareTo(b.name);
    });

    turfs.assignAll(_filterByCategory(sorted));

    print('✅ Showing ${turfs.length} search results for "${searchQuery.value}" (ALL LOCATIONS)');

    if (turfs.isEmpty) {
      print('⚠️ No turfs found matching "${searchQuery.value}"');
    }
  }

  // ============================================================
  // ✅ APPLY LOCATION FILTER - For normal view
  // ============================================================
  void _applyLocationFilter() {
    if (currentLocation.value == null) {
      locationError.value = 'Location unavailable - showing all turfs';
      nearbyTurfs.assignAll(allTurfs);
      turfs.assignAll(_filterByCategory(allTurfs));
      print('⚠️ No location: showing all ${allTurfs.length} turfs');
      return;
    }

    final userPos = currentLocation.value!;
    final nearbyTurfsList = <TurfModel>[];

    print('📍 Filtering turfs within ${AppConfig.maxDistanceKm}km of (${userPos.latitude}, ${userPos.longitude})');
    print('   Total turfs to filter: ${allTurfs.length}');

    for (var turf in allTurfs) {
      double? distance;

      if (turf.distanceKm != null) {
        distance = turf.distanceKm;
      } else if (turf.latitude != null && turf.longitude != null) {
        distance = LocationService.calculateDistance(
          userPos.latitude,
          userPos.longitude,
          turf.latitude!,
          turf.longitude!,
        );
      }

      if (distance != null && distance <= AppConfig.maxDistanceKm) {
        if (turf.distanceKm == null && distance != null) {
          final updatedTurf = turf.copyWith(distanceKm: distance);
          nearbyTurfsList.add(updatedTurf);
        } else {
          nearbyTurfsList.add(turf);
        }
      }
    }

    nearbyTurfsList.sort((a, b) {
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      return aDist.compareTo(bDist);
    });

    _sortWithFavoritesFirst(nearbyTurfsList);

    nearbyTurfs.assignAll(nearbyTurfsList);
    turfs.assignAll(_filterByCategory(nearbyTurfsList));
    _validateLocationLabelAgainstTurfs();

    print('✅ Found ${nearbyTurfsList.length} turfs within ${AppConfig.maxDistanceKm}km');

    if (nearbyTurfsList.isEmpty && allTurfs.isNotEmpty) {
      _showSmallSnackbar(
        'No nearby turfs',
        'No turfs found within ${AppConfig.maxDistanceKm}km of your location',
        Colors.orange,
      );
    }
  }

  // ============================================================
  // ✅ CATEGORY FILTER HELPER (keeps chip selection after reloads)
  // ============================================================
  List<TurfModel> _filterByCategory(List<TurfModel> list) {
    final cat = selectedCategory.value.trim().toLowerCase();
    if (cat.isEmpty) return List<TurfModel>.from(list);
    return list.where((t) => t.gameType.toLowerCase().contains(cat)).toList();
  }

  // ============================================================
  // ✅ APPEND NEXT SEARCH PAGE - existing results are NOT touched
  // ============================================================
  void _appendApiSearchResults(List<TurfModel> newPage) {
    if (newPage.isEmpty) return;
    final existing = _apiSearchList.map((t) => t.id).toSet();
    final fresh = newPage.where((t) => !existing.contains(t.id)).toList();
    fresh.sort((a, b) {
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      if (aDist != bDist) return aDist.compareTo(bDist);
      return a.name.compareTo(b.name);
    });
    _apiSearchList.addAll(fresh);
    if (!showSuggestions.value) {
      searchResults.addAll(fresh);
    }
    turfs.addAll(_filterByCategory(fresh));
    print('✅ Appended ${fresh.length} search results (showing ${turfs.length})');
  }

  // ============================================================
  // ✅ APPEND NEXT NEARBY PAGE - existing cards keep their position
  // ============================================================
  void _appendNearbyTurfs(List<TurfModel> newPage) {
    if (newPage.isEmpty) return;
    final existing = nearbyTurfs.map((t) => t.id).toSet();
    final fresh = <TurfModel>[];

    for (final turf in newPage) {
      if (existing.contains(turf.id)) continue;
      if (currentLocation.value == null) {
        fresh.add(turf);
        continue;
      }
      double? distance = turf.distanceKm;
      if (distance == null && turf.latitude != null && turf.longitude != null) {
        distance = LocationService.calculateDistance(
          currentLocation.value!.latitude,
          currentLocation.value!.longitude,
          turf.latitude!,
          turf.longitude!,
        );
      }
      if (distance != null && distance <= AppConfig.maxDistanceKm) {
        fresh.add(turf.distanceKm == null ? turf.copyWith(distanceKm: distance) : turf);
      }
    }

    fresh.sort((a, b) {
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      return aDist.compareTo(bDist);
    });

    nearbyTurfs.addAll(fresh);
    turfs.addAll(_filterByCategory(fresh));
    print('✅ Appended ${fresh.length} nearby turfs (showing ${turfs.length})');
  }

  void _sortWithFavoritesFirst(List<TurfModel> turfList) {
    turfList.sort((a, b) {
      final aIsFavorite = _favoriteIds.contains(a.id);
      final bIsFavorite = _favoriteIds.contains(b.id);
      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;

      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      return aDist.compareTo(bDist);
    });
  }

  // ✅ LOAD MORE TURFS (Pagination)
  Future<void> loadMoreTurfs() async {
    if (_isFetching) {
      print('⏳ Already fetching, skipping load more');
      return;
    }

    if (isLoadingMore.value) {
      print('⏳ Already loading more, skipping');
      return;
    }

    if (!_hasMoreData) {
      print('⏭️ No more data to load');
      return;
    }

    if (searchQuery.value.isNotEmpty) {
      print('🔍 Loading more search results for: "${searchQuery.value}"');
    } else {
      print('📄 Loading more turfs... (Page $_currentPage)');
    }

    await fetchTurfs(loadMore: true);
  }

  // ========== FAVORITES ==========

  Future<void> _loadFavoritesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesString = prefs.getString('user_favorites');
      if (favoritesString != null && favoritesString.isNotEmpty) {
        final List<String> favoritesList = favoritesString.split(',');
        _favoriteIds.clear();
        for (var id in favoritesList) {
          if (id.isNotEmpty) _favoriteIds.add(int.parse(id));
        }
        print('❤️ Loaded ${_favoriteIds.length} favorites');
      }
      _updateAllTurfsFavoriteStatus();
    } catch (e) {
      print('❌ Error loading favorites: $e');
    }
  }

  Future<void> _saveFavoritesToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesString = _favoriteIds.join(',');
      await prefs.setString('user_favorites', favoritesString);
    } catch (e) {
      print('❌ Error saving favorites: $e');
    }
  }

  void _updateAllTurfsFavoriteStatus() {
    for (int i = 0; i < allTurfs.length; i++) {
      final turf = allTurfs[i];
      final isFav = _favoriteIds.contains(turf.id);
      if (turf.isFavorite != isFav) {
        allTurfs[i] = turf.copyWith(isFavorite: isFav);
      }
    }
    allTurfs.refresh();
    turfs.refresh();
  }

  void _updateSingleTurfFavoriteStatus(int turfId, bool isFavorite) {
    final allIndex = allTurfs.indexWhere((t) => t.id == turfId);
    if (allIndex != -1) {
      allTurfs[allIndex] = allTurfs[allIndex].copyWith(isFavorite: isFavorite);
    }
    final searchIndex = searchResults.indexWhere((t) => t.id == turfId);
    if (searchIndex != -1) {
      searchResults[searchIndex] = searchResults[searchIndex].copyWith(isFavorite: isFavorite);
    }
    allTurfs.refresh();
    turfs.refresh();
    searchResults.refresh();
  }

  bool isFavorite(int turfId) => _favoriteIds.contains(turfId);

  Future<void> toggleFavorite(int turfId) async {
    if (isGuestMode.value) {
      _showSmallSnackbar('Login Required', 'Please login to save favorites', Colors.orange);
      return;
    }

    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      _showSmallSnackbar('Login Required', 'Please login to save favorites', Colors.orange);
      return;
    }

    if (_isRefreshingLock) {
      _showSmallSnackbar('Please wait', 'Another operation in progress', Colors.orange);
      return;
    }

    _isRefreshingLock = true;
    final bool isCurrentlyFavorite = _favoriteIds.contains(turfId);
    final bool newFavoriteState = !isCurrentlyFavorite;

    try {
      if (newFavoriteState) {
        _favoriteIds.add(turfId);
      } else {
        _favoriteIds.remove(turfId);
      }
      await _saveFavoritesToStorage();
      _updateSingleTurfFavoriteStatus(turfId, newFavoriteState);

      final dio = Get.find<Dio>();
      await dio.post(AppConfig.toggleFavorite, data: {'turf_id': turfId});

      // 📊 Meta: wishlist add / remove (only after the server accepted it)
      String turfName = '';
      for (final t in allTurfs) {
        if (t.id == turfId) {
          turfName = t.name;
          break;
        }
      }
      unawaited(MetaEvents.favoriteChanged(
        turfId: turfId,
        turfName: turfName,
        added: newFavoriteState,
      ));

    } catch (e) {
      print('Error toggling favorite: $e');
      if (newFavoriteState) {
        _favoriteIds.remove(turfId);
      } else {
        _favoriteIds.add(turfId);
      }
      await _saveFavoritesToStorage();
      _updateSingleTurfFavoriteStatus(turfId, !newFavoriteState);
      _showSmallSnackbar('Error', 'Failed to update favorite', Colors.red);
    } finally {
      _isRefreshingLock = false;
    }
  }

  List<TurfModel> getFavoritedTurfs() {
    return allTurfs.where((turf) => _favoriteIds.contains(turf.id)).toList();
  }

  int get favoriteCount => _favoriteIds.length;

  // ========== FAVORITE SYNC METHODS ==========

  void refreshFavoritesList() {
    allTurfs.refresh();
    turfs.refresh();
    searchResults.refresh();
  }

  void addFavoriteLocally(TurfModel turf) {
    if (!_favoriteIds.contains(turf.id)) {
      _favoriteIds.add(turf.id);
      _updateSingleTurfFavoriteStatus(turf.id, true);
    }
  }

  void removeFavoriteLocally(int turfId) {
    if (_favoriteIds.contains(turfId)) {
      _favoriteIds.remove(turfId);
      _updateSingleTurfFavoriteStatus(turfId, false);
    }
  }

  // ============================================================
  // ✅ SEARCH - TYPING (Local suggestions only)
  // ============================================================
  void onSearchTextChanged(String query) {
    searchQuery.value = query;
    showSuggestions.value = query.isNotEmpty;
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      isSearching.value = false;
      searchResults.clear();
      _endApiSearch();
      turfs.assignAll(_filterByCategory(nearbyTurfs));
      return;
    }

    _showLocalSuggestions(query.trim());
  }

  void _showLocalSuggestions(String query) {
    final lowerQuery = query.toLowerCase();
    final suggestions = nearbyTurfs.where((turf) {
      return turf.name.toLowerCase().contains(lowerQuery) ||
          turf.gameType.toLowerCase().contains(lowerQuery) ||
          turf.address.toLowerCase().contains(lowerQuery);
    }).toList();

    searchResults.assignAll(suggestions);
    print('🔎 Local suggestions "$query": ${suggestions.length} matches (typing only)');
  }

  // ============================================================
  // ✅ SEARCH - Button/Enter (API call - NO LOCATION FILTER)
  // ============================================================
  Future<void> performApiSearch(String query) async {
    final trimmed = query.trim();
    _searchDebounceTimer?.cancel();

    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    searchQuery.value = trimmed;
    showSuggestions.value = false;
    isSearching.value = true;

    print('🔍 Performing API SEARCH for: "$trimmed"');
    print('📍 Search will show turfs from ALL STATES (no location filter)');

    // ✅ If a load-more is still running, wait for it (otherwise the search is skipped)
    int waited = 0;
    while (_isFetching && waited < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }

    if (_activeApiQuery.isEmpty) {
      // save nearby pagination so it can continue after the search is cleared
      _savedNearbyPage = _currentPage;
      _savedNearbyHasMore = _hasMoreData;
    }
    _activeApiQuery = trimmed;
    _currentPage = 1;
    _hasMoreData = true;
    searchResults.clear();

    await fetchTurfs(forceRefresh: true, userInitiated: true);

    isSearching.value = false;

    // 📊 Meta: search
    MetaEvents.search(query: trimmed, resultCount: searchResults.length);
  }

  // ============================================================
  // ✅ FILTER BY CATEGORY
  // ============================================================
  void filterByCategory(String category) {
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;

    if (_activeApiQuery.isNotEmpty) {
      final filtered = _apiSearchList.where((t) =>
          t.gameType.toLowerCase().contains(category.toLowerCase())
      ).toList();
      turfs.assignAll(filtered);
    } else {
      final filtered = nearbyTurfs.where((t) =>
          t.gameType.toLowerCase().contains(category.toLowerCase())
      ).toList();
      turfs.assignAll(filtered);
    }
  }

  // ============================================================
  // ✅ CLEAR SEARCH
  // ============================================================
  void clearSearch() {
    searchQuery.value = '';
    showSuggestions.value = false;
    isSearching.value = false;
    searchResults.clear();
    _endApiSearch();
    _searchController?.clear();
    selectedCategory.value = '';
    turfs.assignAll(nearbyTurfs);
  }

  TextEditingController? _searchController;

  void setSearchController(TextEditingController controller) {
    _searchController = controller;
  }

  // ========== REFRESH ==========

  Future<void> refreshTurfs({bool showLoading = true}) async {
    final token = SharedPrefsHelper.getToken();
    if (token != null && token.isNotEmpty && !SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired during refresh, switching to guest mode');
      await SharedPrefsHelper.clearToken();
      isGuestMode.value = true;
    }

    if (_isRefreshingLock || _isFetching) {
      print('⏳ Refresh already in progress');
      return;
    }

    print('\n🔄 Manual refresh triggered (Guest: ${isGuestMode.value})');
    _isRefreshingLock = true;
    if (showLoading) isRefreshing.value = true;

    try {
      await getUserLocation();

      _initialFetchDone = false;
      _currentPage = 1;
      _hasMoreData = true;

      await fetchTurfs(forceRefresh: true, userInitiated: true);

      if (homeError.value.isNotEmpty) {
        _showSmallSnackbar('✗ Failed', 'Please check your connection', Colors.red);
        return;
      }
      _lastRefreshTime = DateTime.now();
      _lastFetchTime = DateTime.now();
      _lastTurfsFetchTime = DateTime.now();
      print('✅ Refresh completed');

      _showSmallSnackbar('✓ Updated Successfully', '', Colors.white,);
    } catch (e) {
      print('❌ Refresh error: $e');
      _showSmallSnackbar('✗ Failed', 'Please check your connection', Colors.red);
    } finally {
      if (showLoading) isRefreshing.value = false;
      _isRefreshingLock = false;
    }
  }

  String getDistanceString(TurfModel turf) {
    if (turf.distanceKm != null && turf.distanceKm! > 0) {
      if (turf.distanceKm! < 1) {
        return '${(turf.distanceKm! * 1000).toInt()} m away';
      }
      return '${turf.distanceKm!.toStringAsFixed(1)} km away';
    }

    if (currentLocation.value == null || turf.latitude == null || turf.longitude == null) {
      return '';
    }
    final distance = LocationService.calculateDistance(
      currentLocation.value!.latitude,
      currentLocation.value!.longitude,
      turf.latitude!,
      turf.longitude!,
    );
    if (distance < 1) {
      return '${(distance * 1000).toInt()} m away';
    }
    return '${distance.toStringAsFixed(1)} km away';
  }

  static void resetCache() {}
}