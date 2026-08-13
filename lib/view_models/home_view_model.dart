// home_view_model.dart - Updated to support guest mode (no token required for listing)

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

  // ✅ Track if user is in guest mode
  final isGuestMode = false.obs;

  final currentLocation = Rx<Position?>(null);
  final isLocationLoading = true.obs;
  final locationError = ''.obs;
  final currentLocationName = ''.obs;

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

  // ✅ DUPLICATE API CALL PREVENTION
  DateTime? _lastTurfsFetchTime;
  static const _minFetchInterval = Duration(seconds: 5);
  Timer? _locationDebounceTimer;
  static const _locationDebounceDuration = Duration(seconds: 2);
  bool _isRefreshingFromLocation = false;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMoreData => _hasMoreData;
  int get pageSize => _pageSize;

  @override
  void onInit() {
    super.onInit();
    print('🏠 HomeViewModel initialized');

    // ✅ Check if user is in guest mode (no token)
    final token = SharedPrefsHelper.getToken();
    isGuestMode.value = (token == null || token.isEmpty);
    print('👤 Guest Mode: ${isGuestMode.value}');

    _loadFavoritesFromStorage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationAndFetch();
    });
  }

  Future<void> _initializeLocationAndFetch() async {
    print('📍 Initializing location and fetching turfs...');
    await getUserLocation();
    if (currentLocation.value != null) {
      print('📍 Location available, fetching turfs...');
      await fetchTurfs(forceRefresh: true);
    } else {
      print('⚠️ Location not available, using cache if available');
      _loadFromCache();
    }
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
    // ✅ For guest mode: no token check, just fetch turfs
    if (!isGuestMode.value) {
      final token = SharedPrefsHelper.getToken();
      if (token == null || token.isEmpty) {
        print('🚫 User not logged in, switching to guest mode');
        isGuestMode.value = true;
        // Continue with guest mode fetch
      } else if (!SharedPrefsHelper.isTokenValid()) {
        print('⚠️ Token expired, switching to guest mode');
        await SharedPrefsHelper.clearToken();
        isGuestMode.value = true;
      }
    }

    // ✅ Prevent duplicate calls within 5 seconds
    if (!forceRefresh && _lastTurfsFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastTurfsFetchTime!);
      if (elapsed < _minFetchInterval) {
        print('⏭️ Home data load skipped (${elapsed.inMilliseconds}ms since last fetch)');
        return;
      }
    }

    if (_isFetching && !forceRefresh) {
      print('⏭️ Home data already being fetched, skipping duplicate...');
      return;
    }

    if (currentLocation.value != null) {
      print('📍 Location available, fetching fresh data...');
      await fetchTurfs(forceRefresh: true);
      return;
    }

    if (!forceRefresh && _initialFetchDone && allTurfs.isNotEmpty) {
      if (_lastFetchTime != null) {
        final age = DateTime.now().difference(_lastFetchTime!);
        if (age < _cacheDuration) {
          print('✅ Home data still fresh (${age.inMinutes} min old)');
          return;
        }
      }
    }

    if (forceRefresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _totalPages = 1;
    }

    if (!forceRefresh && SharedPrefsHelper.isTurfsCacheValid()) {
      final cachedTurfsJson = SharedPrefsHelper.getCachedTurfs();
      if (cachedTurfsJson != null) {
        print('📦 Loading turfs from cache');
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
          return;
        } catch (e) {
          print('❌ Error parsing cached turfs: $e');
        }
      }
    }

    print('🏠 Loading home data... (Guest mode: ${isGuestMode.value})');
    if (currentLocation.value == null) {
      await getUserLocation();
    }
    await fetchTurfs(forceRefresh: forceRefresh);
  }

  // ========== GET USER LOCATION ==========
  Future<void> getUserLocation() async {
    final cachedLocation = SharedPrefsHelper.getDeviceLocation();
    final isLocationValid = await SharedPrefsHelper.isLocationValid();

    if (cachedLocation != null && cachedLocation.isNotEmpty && isLocationValid) {
      currentLocationName.value = cachedLocation;
      print('📍 Using cached location: $cachedLocation');
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
        if (position != null) {
          currentLocation.value = position;
          await _updateLocationNameFromCoordinates(position);
          await fetchTurfs(forceRefresh: true);
        }
      } catch (e) {
        print('⚠️ Background location fetch failed: $e');
      } finally {
        _isRefreshingFromLocation = false;
      }
    });
  }

  Future<void> _updateLocationNameFromCoordinates(Position position) async {
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
            await SharedPrefsHelper.saveDeviceLocation(locationName);
            print('📍 Location saved: "$locationName"');
          }
        } else {
          print('⚠️ Google Maps API status: ${data['status']}');
          currentLocationName.value = "Your location";
        }
      }
    } catch (e) {
      print('❌ Error getting location name: $e');
      currentLocationName.value = "Your location";
    }
  }

  // ========== FETCH TURFS WITH PAGINATION & LOCATION ==========
  // ✅ UPDATED: Works with AND without token (guest mode)
  Future<void> fetchTurfs({
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    // ✅ Check if token exists - if yes, use it; if no, still allow guest access
    final token = SharedPrefsHelper.getToken();
    final bool hasToken = token != null && token.isNotEmpty;

    // ✅ Update guest mode status
    isGuestMode.value = !hasToken;
    print('👤 Fetching turfs - Guest Mode: ${isGuestMode.value}');

    // ✅ If token exists but expired, clear it and continue as guest
    if (hasToken && !SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, clearing and continuing as guest');
      await SharedPrefsHelper.clearToken();
      isGuestMode.value = true;
      // Continue with guest mode - don't return
    }

    // ✅ Prevent duplicate calls within 5 seconds
    if (!forceRefresh && !loadMore && _lastTurfsFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastTurfsFetchTime!);
      if (elapsed < _minFetchInterval) {
        print('⏭️ Turfs fetch skipped (${elapsed.inMilliseconds}ms since last fetch)');
        return;
      }
    }

    if (_isFetching) {
      print('⏳ Fetch already in progress');
      return;
    }

    if (currentLocation.value == null && !loadMore) {
      print('📍 No location, fetching location first...');
      await getUserLocation();
      if (currentLocation.value == null) {
        print('⚠️ Still no location, skipping API call');
        return;
      }
    }

    if (!loadMore && !forceRefresh && _initialFetchDone && allTurfs.isNotEmpty) {
      print('✅ Data already loaded');
      return;
    }

    if (loadMore && !_hasMoreData) {
      print('⏭️ No more data to load');
      return;
    }

    _isFetching = true;
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
    print('║  📍 Location: ${currentLocation.value != null ? "Available" : "None"}');
    if (searchQuery.value.isNotEmpty) {
      print('║  🔍 SEARCH: "${searchQuery.value}" (ANY DISTANCE)            ║');
    }
    print('╚════════════════════════════════════════════════════════════╝');

    try {
      // ✅ Create Dio instance with or without token
      final dio = Get.find<Dio>();

      // ✅ Build headers - include token only if available
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      // ✅ Add token ONLY if user is logged in
      if (!isGuestMode.value) {
        final currentToken = SharedPrefsHelper.getToken();
        if (currentToken != null && currentToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $currentToken';
          print('🔑 Using token for authenticated request');
        } else {
          // Token not available, switch to guest mode
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

      if (currentLocation.value != null) {
        queryParams['lat'] = currentLocation.value!.latitude.toString();
        queryParams['lng'] = currentLocation.value!.longitude.toString();
        if (searchQuery.value.isNotEmpty) {
          queryParams['radius'] = '1000';
          print('🔍 SEARCH MODE: Using radius 1000km to find all matching turfs');
        } else {
          queryParams['radius'] = AppConfig.maxDistanceKm.toString();
        }
        print('📍 Location params: lat=${queryParams['lat']}, lng=${queryParams['lng']}, radius=${queryParams['radius']}');
      } else {
        print('⚠️ No location available - API will return all turfs without distance');
      }

      if (searchQuery.value.isNotEmpty) {
        queryParams['search'] = searchQuery.value;
        print('🔍 Search query: "${searchQuery.value}"');
      }

      print('📡 API GET /user/turfs/ with params: $queryParams');
      print('🔑 Auth: ${isGuestMode.value ? "No token (Guest)" : "With token"}}');

      // ✅ Make API call - works with OR without token
      final response = await dio.get(
        AppConfig.turfs,
        queryParameters: queryParams,
        options: Options(headers: headers),
      );

      print('📥 API Response Status: ${response.statusCode}');

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

        if (loadMore) {
          allTurfs.addAll(turfsWithFavorites);
          print('✅ Added ${turfsWithFavorites.length} turfs (total: ${allTurfs.length})');
        } else {
          allTurfs.assignAll(turfsWithFavorites);
          print('✅ Loaded ${allTurfs.length} turfs');
        }

        _initialFetchDone = true;

        if (searchQuery.value.isNotEmpty) {
          _applySearchResults(turfsWithFavorites);
        } else {
          _applyLocationFilter();
        }

        _lastRefreshTime = DateTime.now();
        _lastFetchTime = DateTime.now();
        _lastTurfsFetchTime = DateTime.now();

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

      // ✅ On error, try without token if it was an auth error
      if (e is DioException && e.response?.statusCode == 401) {
        print('🔑 Auth error - switching to guest mode and retrying...');
        isGuestMode.value = true;
        await SharedPrefsHelper.clearToken();
        // Retry without token
        await fetchTurfs(forceRefresh: true);
        return;
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
      _isFetching = false;
    }
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

  void _applySearchResults(List<TurfModel> fetchedTurfs) {
    print('🔍 Applying search results for: "${searchQuery.value}"');
    print('🔍 Total matching turfs: ${fetchedTurfs.length}');

    searchResults.assignAll(fetchedTurfs);

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

    turfs.assignAll(sorted);

    print('✅ Showing ${turfs.length} search results for "${searchQuery.value}" (ALL LOCATIONS)');

    if (turfs.isEmpty) {
      print('⚠️ No turfs found matching "${searchQuery.value}"');
    }
  }

  void _applyLocationFilter() {
    if (currentLocation.value == null) {
      locationError.value = 'Location unavailable - showing all turfs';
      nearbyTurfs.assignAll(allTurfs);
      turfs.assignAll(allTurfs);
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
      }
      else if (turf.latitude != null && turf.longitude != null) {
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

    turfs.assignAll(nearbyTurfsList);

    print('✅ Found ${nearbyTurfsList.length} turfs within ${AppConfig.maxDistanceKm}km');

    if (nearbyTurfsList.isEmpty && allTurfs.isNotEmpty) {
      Get.snackbar(
        'No nearby turfs',
        'No turfs found within ${AppConfig.maxDistanceKm}km of your location',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
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
    // ✅ Guest cannot add favorites
    if (isGuestMode.value) {
      Get.snackbar(
        'Login Required',
        'Please login to add favorites',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar('Login Required', 'Please login to add favorites',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (_isRefreshingLock) {
      Get.snackbar('Please wait', 'Another operation in progress',
          backgroundColor: Colors.orange, colorText: Colors.white, duration: const Duration(seconds: 1));
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

      Get.snackbar(
        newFavoriteState ? 'Added to Favorites' : 'Removed from Favorites',
        newFavoriteState ? 'Turf saved to favorites' : 'Turf removed from favorites',
        backgroundColor: newFavoriteState ? Colors.green : Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
        snackPosition: SnackPosition.BOTTOM,
      );

      final dio = Get.find<Dio>();
      await dio.post(AppConfig.toggleFavorite, data: {'turf_id': turfId});

    } catch (e) {
      print('Error toggling favorite: $e');
      if (newFavoriteState) {
        _favoriteIds.remove(turfId);
      } else {
        _favoriteIds.add(turfId);
      }
      await _saveFavoritesToStorage();
      _updateSingleTurfFavoriteStatus(turfId, !newFavoriteState);
      Get.snackbar('Error', 'Failed to update favorite',
          backgroundColor: Colors.red, colorText: Colors.white);
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

  // ========== SEARCH ==========

  void onSearchTextChanged(String query) {
    searchQuery.value = query;
    showSuggestions.value = query.isNotEmpty;
    _searchDebounceTimer?.cancel();

    if (query.trim().isEmpty) {
      isSearching.value = false;
      searchResults.clear();
      turfs.assignAll(nearbyTurfs);
      return;
    }

    _applyLocalFilter(query.trim());
  }

  void _applyLocalFilter(String query) {
    final lowerQuery = query.toLowerCase();
    final filtered = nearbyTurfs.where((turf) {
      return turf.name.toLowerCase().contains(lowerQuery) ||
          turf.gameType.toLowerCase().contains(lowerQuery) ||
          turf.address.toLowerCase().contains(lowerQuery);
    }).toList();
    turfs.assignAll(filtered);
    print('🔎 Local filter "$query": ${filtered.length} match(es) (no API call)');
  }

  Future<void> performSearch(String query) async {
    final trimmed = query.trim();
    _searchDebounceTimer?.cancel();

    if (trimmed.isEmpty) {
      clearSearch();
      return;
    }

    searchQuery.value = trimmed;
    showSuggestions.value = false;
    isSearching.value = true;

    print('🔍 Performing search for: "$trimmed" (ANY DISTANCE - ALL LOCATIONS)');

    _currentPage = 1;
    _hasMoreData = true;

    await fetchTurfs(forceRefresh: true);

    isSearching.value = false;
  }

  void filterByCategory(String category) {
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;

    if (searchQuery.value.isNotEmpty) {
      final filtered = searchResults.where((t) =>
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

  void clearSearch() {
    searchQuery.value = '';
    showSuggestions.value = false;
    isSearching.value = false;
    searchResults.clear();
    _searchController?.clear();
    turfs.assignAll(nearbyTurfs);
    selectedCategory.value = '';
  }

  TextEditingController? _searchController;

  void setSearchController(TextEditingController controller) {
    _searchController = controller;
  }

  // ========== REFRESH ==========

  Future<void> refreshTurfs({bool showLoading = true}) async {
    // ✅ Check token status - if expired, switch to guest mode
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

      if (searchQuery.value.isNotEmpty) {
        await fetchTurfs(forceRefresh: true);
      } else {
        await fetchTurfs(forceRefresh: true);
      }

      _lastRefreshTime = DateTime.now();
      _lastFetchTime = DateTime.now();
      _lastTurfsFetchTime = DateTime.now();
      homeError.value = '';
      print('✅ Refresh completed');

      Get.snackbar(
        '✓ Updated!',
        'Latest turf information loaded',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      print('❌ Refresh error: $e');
      Get.snackbar('✗ Failed', 'Please check your connection',
          backgroundColor: Colors.red, colorText: Colors.white);
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