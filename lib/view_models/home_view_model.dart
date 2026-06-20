// home_view_model.dart - Complete Optimized Version with Duplicate Call Prevention

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
  bool _isFetching = false;  // ✅ PREVENT DUPLICATE CALLS
  int _apiCallCount = 0;

  DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(minutes: 10);

  final Set<int> _favoriteIds = <int>{};
  final isFavoritesLoading = false.obs;

  static const String googleMapsApiKey = 'AIzaSyBQ6kiaROyTfm7TLKG2c_FA1XER8IVaMlY';
  static const double MAX_DISTANCE_KM = 20.0;

  @override
  void onInit() {
    super.onInit();
    print('🏠 HomeViewModel initialized');
    _loadFavoritesFromStorage();
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

    // ✅ Check token validity
    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping home data load');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // ✅ Prevent duplicate calls while fetching
    if (_isFetching && !forceRefresh) {
      print('⏭️ Home data already being fetched, skipping duplicate...');
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
    // ✅ First check cached location
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
      // Request permission first
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

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      currentLocation.value = position;
      locationError.value = '';
      print('📍 Got coordinates: ${position.latitude}, ${position.longitude}');

      // Get location name from Google Maps
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

            // ✅ Save to SharedPreferences
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

  // ========== FETCH TURFS ==========

  Future<void> fetchTurfs({bool forceRefresh = false}) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 User not logged in');
      return;
    }

    // ✅ Check token validity
    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, skipping turfs fetch');
      await SharedPrefsHelper.clearToken();
      return;
    }

    // ✅ Prevent duplicate calls
    if (_isFetching) {
      print('⏳ Fetch already in progress');
      return;
    }

    if (!forceRefresh && _initialFetchDone && allTurfs.isNotEmpty) {
      print('✅ Data already loaded');
      return;
    }

    _isFetching = true;
    _apiCallCount++;
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  🏟️ FETCH TURFS API CALL #$_apiCallCount                     ║');
    print('╚════════════════════════════════════════════════════════════╝');

    isLoading.value = true;
    homeError.value = '';

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get('/user/turfs/');

      if (response.data['result'] == 'success') {
        final List<dynamic> data = response.data['data'];
        print('📦 Received ${data.length} turfs');

        final fetchedTurfs = data.map((json) => TurfModel.fromJson(json)).toList();
        final turfsWithFavorites = fetchedTurfs.map((turf) {
          return turf.copyWith(isFavorite: _favoriteIds.contains(turf.id));
        }).toList();

        allTurfs.assignAll(turfsWithFavorites);
        _initialFetchDone = true;
        _applyLocationFilter();
        _lastRefreshTime = DateTime.now();
        _lastFetchTime = DateTime.now();

        await SharedPrefsHelper.cacheTurfs(jsonEncode(data));
        print('✅ Turfs cached');
      } else {
        homeError.value = 'Failed to load turfs';
      }
    } catch (e) {
      print('❌ Error: $e');
      homeError.value = 'Failed to load turfs';
    } finally {
      isLoading.value = false;
      _isFetching = false;
    }
  }

  void _applyLocationFilter() {
    if (currentLocation.value == null) {
      locationError.value = 'Location unavailable';
      return;
    }

    final userPos = currentLocation.value!;
    final nearbyTurfsList = <TurfModel>[];

    for (var turf in allTurfs) {
      if (turf.latitude != null && turf.longitude != null) {
        final distance = LocationService.calculateDistance(
          userPos.latitude,
          userPos.longitude,
          turf.latitude!,
          turf.longitude!,
        );
        if (distance <= MAX_DISTANCE_KM) {
          nearbyTurfsList.add(turf);
        }
      }
    }

    _sortWithFavoritesFirst(nearbyTurfsList);
    nearbyTurfs.assignAll(nearbyTurfsList);
    turfs.assignAll(nearbyTurfsList);
    _applySearchAndFilters();
  }

  void _sortWithFavoritesFirst(List<TurfModel> turfList) {
    if (currentLocation.value == null) return;

    turfList.sort((a, b) {
      final aIsFavorite = _favoriteIds.contains(a.id);
      final bIsFavorite = _favoriteIds.contains(b.id);
      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;

      if (a.latitude == null || a.longitude == null ||
          b.latitude == null || b.longitude == null) {
        return 0;
      }

      final distanceA = LocationService.calculateDistance(
        currentLocation.value!.latitude,
        currentLocation.value!.longitude,
        a.latitude!,
        a.longitude!,
      );
      final distanceB = LocationService.calculateDistance(
        currentLocation.value!.latitude,
        currentLocation.value!.longitude,
        b.latitude!,
        b.longitude!,
      );
      return distanceA.compareTo(distanceB);
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

      // Sync with backend
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
    var filtered = searchQuery.value.trim().isNotEmpty ? allTurfs.toList() : nearbyTurfs.toList();

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

    // ✅ Check token validity
    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, redirecting to login');
      await SharedPrefsHelper.clearToken();
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    // ✅ Prevent duplicate refresh calls
    if (_isRefreshingLock || _isFetching) {
      print('⏳ Refresh already in progress');
      return;
    }

    print('\n🔄 Manual refresh triggered');
    _isRefreshingLock = true;
    if (showLoading) isRefreshing.value = true;

    try {
      if (currentLocation.value == null) {
        await getUserLocation();
      }

      _initialFetchDone = false;
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

  // ========== RESET CACHE ==========
  static void resetCache() {
    // This will force fresh fetch on next load
    // Static flags need to be reset
  }
}

// TurfModel copyWith extension
extension TurfModelCopyWith on TurfModel {
  TurfModel copyWith({
    int? id,
    String? name,
    String? address,
    String? gameType,
    String? description,
    String? achievements,
    int? maxPersons,
    int? courts,
    Map<String, dynamic>? facilities,
    String? openTime,
    String? closeTime,
    double? latitude,
    double? longitude,
    String? state,
    String? district,
    String? pincode,
    List<String>? images,
    String? turfCode,
    bool? isFavorite,
    bool? isVerified,
    String? type,
    String? status,
    bool? isBookable,
    String? phoneNumber,
    String? advanceType,
    String? advanceValue,
    int? minSlots,
  }) {
    return TurfModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      gameType: gameType ?? this.gameType,
      description: description ?? this.description,
      achievements: achievements ?? this.achievements,
      maxPersons: maxPersons ?? this.maxPersons,
      courts: courts ?? this.courts,
      facilities: facilities ?? this.facilities,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      state: state ?? this.state,
      district: district ?? this.district,
      pincode: pincode ?? this.pincode,
      images: images ?? this.images,
      turfCode: turfCode ?? this.turfCode,
      isFavorite: isFavorite ?? this.isFavorite,
      isVerified: isVerified ?? this.isVerified,
      type: type ?? this.type,
      status: status ?? this.status,
      isBookable: isBookable ?? this.isBookable,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      advanceType: advanceType ?? this.advanceType,
      advanceValue: advanceValue ?? this.advanceValue,
      minSlots: minSlots ?? this.minSlots,
    );
  }
}