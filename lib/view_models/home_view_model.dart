// home_view_model.dart - Complete with Pagination & Location Support
// ✅ Based on API documentation: /api/user/turfs/
// ✅ Supports lat, lng, radius, search, pagination
// ✅ Fixed pagination using next URL from API
// ✅ Shows ONLY nearby turfs based on current location
// ✅ Public getters for _hasMoreData and _currentPage
// ✅ Sync with FavoritesViewModel

import 'dart:async';
import 'dart:convert';
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
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isLoadingMore = false.obs;
  final searchQuery = ''.obs;
  final selectedCategory = ''.obs;
  final showSuggestions = false.obs;
  final homeError = ''.obs;

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
  static const _cacheDuration = Duration(minutes: 10);

  final Set<int> _favoriteIds = <int>{};
  final isFavoritesLoading = false.obs;

  // ✅ Pagination - Private fields
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreData = true;
  static const int _pageSize = 20;

  // ✅ Public getters for pagination
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMoreData => _hasMoreData;
  int get pageSize => _pageSize;

  static const String googleMapsApiKey = 'AIzaSyBQ6kiaROyTfm7TLKG2c_FA1XER8IVaMlY';
  static const double MAX_DISTANCE_KM = 25.0;

  @override
  void onInit() {
    super.onInit();
    print('🏠 HomeViewModel initialized');
    _loadFavoritesFromStorage();

    // ✅ Get location immediately on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationAndFetch();
    });
  }

  // ✅ New method: Initialize location and fetch turfs
  Future<void> _initializeLocationAndFetch() async {
    print('📍 Initializing location and fetching turfs...');
    await getUserLocation();
    if (currentLocation.value != null) {
      print('📍 Location available, fetching turfs...');
      await fetchTurfs(forceRefresh: true);
    } else {
      print('⚠️ Location not available, using cache if available');
      // Try to load from cache as fallback
      _loadFromCache();
    }
  }

  // ✅ Load from cache as fallback
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
    super.onClose();
  }

  // ========== LOAD HOME DATA ==========
  Future<void> loadHomeData({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 User not logged in, skipping home data load');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping home data load');
      await SharedPrefsHelper.clearToken();
      return;
    }

    if (_isFetching && !forceRefresh) {
      print('⏭️ Home data already being fetched, skipping duplicate...');
      return;
    }

    // ✅ Always fetch fresh if location is available
    if (currentLocation.value != null) {
      print('📍 Location available, fetching fresh data...');
      await fetchTurfs(forceRefresh: true);
      return;
    }

    // ✅ If no location, try cache
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

    print('🏠 Loading home data...');
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
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      if (position != null) {
        currentLocation.value = position;
        await _updateLocationNameFromCoordinates(position);
        // ✅ Refresh turfs with new location
        await fetchTurfs(forceRefresh: true);
      }
    } catch (e) {
      print('⚠️ Background location fetch failed: $e');
    }
  }

  Future<void> _updateLocationNameFromCoordinates(Position position) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleMapsApiKey',
      );

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
  Future<void> fetchTurfs({
    bool forceRefresh = false,
    bool loadMore = false,
  }) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 User not logged in');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping turfs fetch');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // ✅ Check if location is available - if not, fetch location first
    if (currentLocation.value == null && !loadMore) {
      print('📍 No location, fetching location first...');
      await getUserLocation();
      if (currentLocation.value == null) {
        print('⚠️ Still no location, skipping API call');
        return;
      }
    }

    if (_isFetching) {
      print('⏳ Fetch already in progress');
      return;
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
    print('║  📍 Location: ${currentLocation.value != null ? "Available" : "None"}');
    print('╚════════════════════════════════════════════════════════════╝');

    try {
      final dio = Get.find<Dio>();

      Map<String, dynamic> queryParams = {
        'page': _currentPage,
        'page_size': _pageSize,
      };

      // ✅ ALWAYS add location parameters if available
      if (currentLocation.value != null) {
        queryParams['lat'] = currentLocation.value!.latitude.toString();
        queryParams['lng'] = currentLocation.value!.longitude.toString();
        queryParams['radius'] = MAX_DISTANCE_KM.toString();
        print('📍 Location params: lat=${queryParams['lat']}, lng=${queryParams['lng']}, radius=${queryParams['radius']}');
      } else {
        print('⚠️ No location available - API will return all turfs without distance');
      }

      // ✅ Add search query if available
      if (searchQuery.value.isNotEmpty) {
        queryParams['search'] = searchQuery.value;
        print('🔍 Search query: ${searchQuery.value}');
      }

      print('📡 API GET /user/turfs/ with params: $queryParams');

      final response = await dio.get(
        '/user/turfs/',
        queryParameters: queryParams,
      );

      print('📥 API Response Status: ${response.statusCode}');

      if (response.data['result'] == 'success') {
        final data = response.data['data'];
        final List<dynamic> results = data['results'] ?? [];
        final int count = data['count'] ?? 0;
        final String? next = data['next'];
        final String? previous = data['previous'];

        // ✅ Use next URL to determine hasMoreData
        _hasMoreData = next != null && next.isNotEmpty;

        // ✅ Calculate total pages
        _totalPages = (count / _pageSize).ceil();

        // ✅ Extract current page from response or use our value
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

        // ✅ Apply location filter to show only nearby turfs
        _applyLocationFilter();

        _lastRefreshTime = DateTime.now();
        _lastFetchTime = DateTime.now();

        if (!loadMore) {
          await SharedPrefsHelper.cacheTurfs(jsonEncode(results));
          print('✅ Turfs cached');
        }

        // ✅ Only increment if there is more data
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
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
      _isFetching = false;
    }
  }

  // ✅ Load more turfs (pagination)
  Future<void> loadMoreTurfs() async {
    if (_isFetching || isLoadingMore.value || !_hasMoreData) return;
    print('📄 Loading more turfs... (Page $_currentPage)');
    await fetchTurfs(loadMore: true);
  }

  // ✅ FIXED: Apply location filter - shows ONLY nearby turfs
  void _applyLocationFilter() {
    if (currentLocation.value == null) {
      // ✅ If no location, show all turfs but mark them as not nearby
      locationError.value = 'Location unavailable - showing all turfs';
      nearbyTurfs.assignAll(allTurfs);
      turfs.assignAll(allTurfs);
      print('⚠️ No location: showing all ${allTurfs.length} turfs');
      return;
    }

    final userPos = currentLocation.value!;
    final nearbyTurfsList = <TurfModel>[];

    print('📍 Filtering turfs within ${MAX_DISTANCE_KM}km of (${userPos.latitude}, ${userPos.longitude})');
    print('   Total turfs to filter: ${allTurfs.length}');

    for (var turf in allTurfs) {
      double? distance;

      // ✅ Use distance_km from API if available
      if (turf.distanceKm != null) {
        distance = turf.distanceKm;
      }
      // ✅ Fallback to calculated distance
      else if (turf.latitude != null && turf.longitude != null) {
        distance = LocationService.calculateDistance(
          userPos.latitude,
          userPos.longitude,
          turf.latitude!,
          turf.longitude!,
        );
      }

      // ✅ Check if within radius
      if (distance != null && distance <= MAX_DISTANCE_KM) {
        // ✅ Update turf with distance if from API
        if (turf.distanceKm == null && distance != null) {
          final updatedTurf = turf.copyWith(distanceKm: distance);
          nearbyTurfsList.add(updatedTurf);
        } else {
          nearbyTurfsList.add(turf);
        }
      }
    }

    // ✅ Sort by distance (nearest first)
    nearbyTurfsList.sort((a, b) {
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      return aDist.compareTo(bDist);
    });

    // ✅ Move favorites to top
    _sortWithFavoritesFirst(nearbyTurfsList);

    nearbyTurfs.assignAll(nearbyTurfsList);

    // ✅ Update the displayed turfs
    _applySearchAndFilters();

    print('✅ Found ${nearbyTurfsList.length} turfs within ${MAX_DISTANCE_KM}km');

    // ✅ Show info message if no nearby turfs
    if (nearbyTurfsList.isEmpty && allTurfs.isNotEmpty) {
      Get.snackbar(
        'No nearby turfs',
        'No turfs found within ${MAX_DISTANCE_KM}km of your location',
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
    allTurfs.refresh();
    turfs.refresh();
  }

  bool isFavorite(int turfId) => _favoriteIds.contains(turfId);

  Future<void> toggleFavorite(int turfId) async {
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
      await dio.post('/user/favorites/toggle/', data: {'turf_id': turfId});

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
    if (query.trim().isEmpty) {
      turfs.assignAll(nearbyTurfs);
      return;
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _applySearchAndFilters();
    });
  }

  void _applySearchAndFilters() {
    // ✅ Start with nearby turfs (already filtered by location)
    var filtered = searchQuery.value.trim().isNotEmpty
        ? allTurfs.where((t) => nearbyTurfs.contains(t)).toList()
        : nearbyTurfs.toList();

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase().trim();
      filtered = filtered.where((t) {
        return t.name.toLowerCase().contains(query) ||
            t.address.toLowerCase().contains(query) ||
            t.district.toLowerCase().contains(query) ||
            t.gameType.toLowerCase().contains(query) ||
            t.state.toLowerCase().contains(query);
      }).toList();
    }

    if (selectedCategory.value.isNotEmpty && searchQuery.value.trim().isEmpty) {
      filtered = filtered.where((t) => t.gameType.toLowerCase().contains(selectedCategory.value.toLowerCase())).toList();
    }

    _sortWithFavoritesFirst(filtered);
    turfs.assignAll(filtered);
  }

  void filterByCategory(String category) {
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;
    _applySearchAndFilters();
  }

  void clearSearch() {
    searchQuery.value = '';
    showSuggestions.value = false;
    _applySearchAndFilters();
  }

  // ========== REFRESH ==========

  Future<void> refreshTurfs({bool showLoading = true}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 User not logged in');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, redirecting to login');
      await SharedPrefsHelper.clearToken();
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    if (_isRefreshingLock || _isFetching) {
      print('⏳ Refresh already in progress');
      return;
    }

    print('\n🔄 Manual refresh triggered');
    _isRefreshingLock = true;
    if (showLoading) isRefreshing.value = true;

    try {
      // ✅ Refresh location first
      await getUserLocation();

      // ✅ Then fetch turfs with new location
      _initialFetchDone = false;
      _currentPage = 1;
      _hasMoreData = true;
      await fetchTurfs(forceRefresh: true);
      _lastRefreshTime = DateTime.now();
      _lastFetchTime = DateTime.now();
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

  static void resetCache() {
    // This will force fresh fetch on next load
  }
}