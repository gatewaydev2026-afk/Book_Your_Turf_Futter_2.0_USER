// home_view.dart - COMPLETE UPDATED VERSION
// ✅ Compact UI - No extra space
// ✅ API Search - Search button calls API
// ✅ Typing shows local suggestions only
// ✅ Guest mode fully working
// ✅ Transparent bottom navigation bar

import 'dart:async';
import 'package:book_your_turf/views/profile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/notification_model.dart';
import '../routes/app_routes.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../services/shared_prefs_helper.dart';
import '../view_models/home_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../widgets/turf_card.dart';
import '../widgets/turf_skeleton.dart';
import 'ChatbotView.dart';
import 'notification_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final HomeViewModel homeVm = Get.find<HomeViewModel>();
  final ProfileViewModel profileVm = Get.find<ProfileViewModel>();
  late final NotificationService _notificationService;

  late AnimationController _greetingAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _showGreeting = true;
  String _cachedUserName = 'Guest';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _categoryAnimationController;
  late Animation<double> _categoryHeightAnimation;

  double _lastScrollOffset = 0;
  bool _isCategoryMinimized = false;
  final _scrollController = ScrollController();

  final Map<String, DateTime> _lastClickTime = {};
  static const int DEBOUNCE_DURATION_MS = 800;

  bool _dataLoaded = false;
  bool _isUpdateCheckDone = false;

  StreamSubscription<NotificationItem>? _notificationStreamSubscription;

  @override
  void initState() {
    super.initState();

    homeVm.setSearchController(_searchController);

    _notificationService = Get.find<NotificationService>();

    _notificationStreamSubscription = _notificationService.onNotificationReceived.listen((notification) {
      if (mounted) {
        _notificationService.updateUnreadCount();
      }
    });

    _checkForUpdatesInBackground();

    WidgetsBinding.instance.addObserver(this);

    _cachedUserName = profileVm.name.value.isNotEmpty
        ? profileVm.name.value
        : (SharedPrefsHelper.getUserName() ?? 'Guest');

    _greetingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(
      CurvedAnimation(parent: _greetingAnimationController, curve: Curves.easeIn),
    );
    _fadeAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _greetingAnimationController, curve: Curves.easeOut),
    );
    _greetingAnimationController.forward().then((_) {
      if (mounted) setState(() => _showGreeting = false);
    });

    _categoryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _categoryHeightAnimation = Tween<double>(
      begin: 125,
      end: 38,
    ).animate(
      CurvedAnimation(parent: _categoryAnimationController, curve: Curves.easeInOut),
    );

    _listenToProfileChanges();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeData();
      _scrollController.addListener(_onScroll);
      _notificationService.updateUnreadCount();
    });

    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus) {
            homeVm.showSuggestions.value = false;
          }
        });
      }
    });
  }

  Future<void> _checkForUpdatesInBackground() async {
    try {
      if (!SharedPrefsHelper.shouldCheckForUpdate()) {
        return;
      }

      Future.delayed(const Duration(seconds: 3), () async {
        try {
          await UpdateService.checkAndShowUpdateDialog(context);
          _isUpdateCheckDone = true;
        } catch (e) {
          print('⚠️ Background update check failed: $e');
        }
      });
    } catch (e) {
      print('⚠️ Update check setup failed: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationService.updateUnreadCount();
  }

  Future<void> _loadHomeData() async {
    if (_dataLoaded) {
      print('✅ Home data already loaded, skipping');
      return;
    }

    final token = SharedPrefsHelper.getToken();
    final isGuest = token == null || token.isEmpty;

    if (isGuest) {
      print('👤 Guest mode - Loading turfs without token');
      await homeVm.loadHomeData();
      _dataLoaded = true;
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, switching to guest mode');
      await SharedPrefsHelper.clearToken();
      await homeVm.loadHomeData();
      _dataLoaded = true;
      return;
    }

    if (homeVm.allTurfs.isEmpty && !homeVm.isLoading.value) {
      print('📡 Loading home data for the first time...');
      await homeVm.loadHomeData();
      _dataLoaded = true;
    } else if (homeVm.allTurfs.isNotEmpty) {
      print('✅ Home data already available (${homeVm.allTurfs.length} turfs)');
      _dataLoaded = true;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;

    if (delta > 5 && !_isCategoryMinimized && currentOffset > 30) {
      _isCategoryMinimized = true;
      _categoryAnimationController.forward();
    } else if (delta < -5 && _isCategoryMinimized && currentOffset < 50) {
      _isCategoryMinimized = false;
      _categoryAnimationController.reverse();
    }

    _lastScrollOffset = currentOffset;
  }

  bool _isDebounced(String actionId) {
    final now = DateTime.now();
    if (_lastClickTime.containsKey(actionId)) {
      final lastClick = _lastClickTime[actionId]!;
      if (now.difference(lastClick).inMilliseconds < DEBOUNCE_DURATION_MS) {
        return true;
      }
    }
    _lastClickTime[actionId] = now;
    return false;
  }

  void _listenToProfileChanges() {
    profileVm.name.listen((newName) {
      if (mounted && newName.isNotEmpty) {
        setState(() {
          _cachedUserName = newName;
        });
        SharedPrefsHelper.setUserName(newName);
      }
    });
  }

  Future<void> _handleClick(String actionId, Future<void> Function() action) async {
    if (_isDebounced(actionId)) return;
    await action();
  }

  Future<void> _handleRefresh() async {
    if (_isDebounced('refresh')) return;
    await homeVm.refreshTurfs();
    _notificationService.updateUnreadCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('App state: $state - Updating notification badge only');
    if (state == AppLifecycleState.resumed) {
      _notificationService.updateUnreadCount();
      final token = SharedPrefsHelper.getToken();
      if (token != null && token.isNotEmpty && SharedPrefsHelper.isTokenValid()) {
        _loadHomeData();
      }
    }
  }

  @override
  void dispose() {
    _notificationStreamSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _greetingAnimationController.stop();
    _greetingAnimationController.dispose();
    _categoryAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int getCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width <= 450) return 2;
    if (width <= 700) return 2;
    if (width <= 900) return 3;
    return 4;
  }

  Future<void> _openLocationInMap() async {
    await _handleClick('location', () async {
      String url;
      if (homeVm.currentLocation.value != null) {
        final pos = homeVm.currentLocation.value!;
        url = "https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}";
      } else {
        const fallback = "KK Nagar, Madurai";
        url = "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(fallback)}";
      }
      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch map';
        }
      } catch (e) {
        if (mounted) {
          Get.snackbar('Error', 'Could not open map: $e',
              backgroundColor: Colors.red, colorText: Colors.white);
        }
      }
    });
  }

  void _onSearchChanged(String query) {
    homeVm.onSearchTextChanged(query);
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      homeVm.performApiSearch(query);
      _searchFocusNode.unfocus();
    }
  }

  Future<void> _onProfileTap() async {
    if (homeVm.isGuestMode.value) {
      _showLoginRequiredDialog();
      return;
    }

    await _handleClick('profile', () async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfileView()),
      );
      if (result == true) {
        await profileVm.refresh();
        setState(() {
          _cachedUserName = profileVm.name.value;
        });
      }
    });
  }

  void _showLoginRequiredDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to view your profile and access all features.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _onCategoryTap(String filter) async {
    await _handleClick('category_$filter', () async {
      homeVm.filterByCategory(filter);
    });
  }

  void _openChatbot() {
    Get.to(() => ChatbotView());
  }

  void _openNotificationScreen() {
    Get.to(() => NotificationScreen());
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Removed the colored Container - now transparent for glass nav
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Stack(
        children: [
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                homeVm.showSuggestions.value = false;
              },
              child: Column(
                children: [
                  if (_showGreeting)
                    Container(
                      height: 30,
                      alignment: Alignment.center,
                      child: Obx(() => Text(
                        homeVm.isGuestMode.value
                            ? "Hello Guest! 👋"
                            : "Hello $_cachedUserName!",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      )),
                    ),
                  if (!_showGreeting) _headerSection(context),
                  _searchBar(),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _categoryAnimationController,
                    builder: (context, child) {
                      return Container(
                        height: _categoryHeightAnimation.value,
                        width: double.infinity,
                        child: !_isCategoryMinimized
                            ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _allCategoryCard(),
                            const SizedBox(height: 4),
                            _threeCategoriesRow(),
                          ],
                        )
                            : _miniCategorySection(),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: _buildMainContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _allCategoryCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        final isSelected = homeVm.selectedCategory.value == "";
        return GestureDetector(
          onTap: () => _onCategoryTap(""),
          child: Container(
            width: double.infinity,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff5B6EE8), Color(0xff7B4FA0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff667eea).withOpacity(0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "All",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Image.asset(
                      'assets/sports/all .png',
                      height: 80,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _threeCategoriesRow() {
    final categories = [
      {"name": "Cricket &\n Football", "filter": "Football", "image1": "assets/sports/human_cricket.png", "colors": [const Color(0xffFF9A9E), const Color(0xffF6416C)]},
      {"name": "Pickleball", "filter": "Pickleball", "image1": "assets/sports/human_pickle.png", "colors": [const Color(0xff43CEA2), const Color(0xff185A9D)]},
      {"name": "Badminton", "filter": "Badminton", "image1": "assets/sports/human_badminton.png", "colors": [const Color(0xffFDC830), const Color(0xffF37335)]},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(3, (index) {
          final category = categories[index];
          final filter = category["filter"] as String;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index != 2 ? 6 : 0),
              child: Obx(() {
                final isSelected = homeVm.selectedCategory.value == filter;
                return GestureDetector(
                  onTap: () => _onCategoryTap(filter),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: category["colors"] as List<Color>,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (category["colors"] as List<Color>)[1].withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Image.asset(
                            category["image1"] as String,
                            height: 100,
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                          Center(
                            child: Text(
                              category["name"] as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _miniCategorySection() {
    final categories = [
      {"name": "All", "filter": ""},
      {"name": "Cricket &\nFootball", "filter": "Football"},
      {"name": "Pickleball", "filter": "Pickleball"},
      {"name": "Badminton", "filter": "Badminton"},
    ];

    return Container(
      height: 35,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(categories.length, (index) {
          final category = categories[index];
          final filter = category["filter"] as String;

          return Obx(() {
            final isSelected = homeVm.selectedCategory.value == filter;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onCategoryTap(filter),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.grey.shade300,
                      width: 0.8,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      category["name"] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            );
          });
        }),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 46,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final query = _searchController.text;
              if (query.trim().isNotEmpty) {
                homeVm.performApiSearch(query);
                _searchFocusNode.unfocus();
              } else {
                FocusScope.of(context).requestFocus(_searchFocusNode);
              }
            },
            child: SvgPicture.asset(
              'assets/icons/search.svg',
              height: 22,
              width: 22,
              placeholderBuilder: (context) => const Icon(Icons.search),
              errorBuilder: (context, error, stack) => const Icon(Icons.search),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search turfs, locations...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                suffixIcon: _buildSearchSuffixIcon(),
              ),
            ),
          ),
          Obx(() {
            if (homeVm.isSearching.value) {
              return const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildSearchSuffixIcon() {
    return Obx(() {
      if (homeVm.searchQuery.value.isNotEmpty) {
        return IconButton(
          icon: const Icon(Icons.clear, size: 18),
          onPressed: () {
            _searchController.clear();
            homeVm.clearSearch();
            homeVm.showSuggestions.value = false;
            _searchFocusNode.unfocus();
          },
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildMainContent() {
    return Obx(() {
      if (homeVm.isLoading.value && homeVm.turfs.isEmpty && !homeVm.isSearching.value) {
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: getCrossAxisCount(context),
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => const TurfSkeleton(),
        );
      }

      if (homeVm.searchQuery.value.isNotEmpty) {
        if (homeVm.turfs.isEmpty && !homeVm.isLoading.value) {
          return _buildSearchEmptyState();
        }
        if (homeVm.turfs.isNotEmpty) {
          return _buildTurfGrid();
        }
      }

      if (homeVm.showSuggestions.value && homeVm.searchResults.isNotEmpty) {
        return _buildSuggestionsList();
      }

      if (homeVm.turfs.isNotEmpty) {
        return _buildTurfGrid();
      }

      return _buildEmptyState();
    });
  }

  Widget _buildSuggestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: homeVm.searchResults.length,
      itemBuilder: (context, index) {
        final turf = homeVm.searchResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.search, color: Colors.green, size: 20),
            title: Text(
              turf.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              turf.address,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: turf.distanceKm != null
                ? Text(
              '${turf.distanceKm!.toStringAsFixed(1)} km',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
                : null,
            onTap: () {
              _searchController.text = turf.name;
              homeVm.performApiSearch(turf.name);
              _searchFocusNode.unfocus();
            },
          ),
        );
      },
    );
  }

  Widget _buildTurfGrid() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.green,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 300) {
            if (!homeVm.isLoadingMore.value && homeVm.hasMoreData) {
              homeVm.loadMoreTurfs();
            }
          }
          return true;
        },
        child: GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: getCrossAxisCount(context),
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: homeVm.turfs.length + (homeVm.isLoadingMore.value ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == homeVm.turfs.length && homeVm.isLoadingMore.value) {
              return _buildLoadingMoreIndicator();
            }
            return TurfCard(homeVm.turfs[index]);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading more turfs...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lottie/no.json',
            height: 120,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.search_off, size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            'No turfs found for "${homeVm.searchQuery.value}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search terms or location',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              homeVm.clearSearch();
              _searchFocusNode.unfocus();
            },
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text("Clear Search", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lottie/no.json',
            height: 120,
            errorBuilder: (_, __, ___) => const Icon(Icons.search_off, size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Turfs Found",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            homeVm.locationError.value.isNotEmpty ? homeVm.locationError.value : "Try refreshing",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _handleRefresh(),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text("Refresh Now", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Obx(() {
        final profileImage = profileVm.profileImageUrl.value;
        final isGuest = homeVm.isGuestMode.value;

        return Row(
          children: [
            Flexible(
              flex: 3,
              child: Row(
                children: [
                  InkWell(
                    onTap: _onProfileTap,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: MediaQuery.of(context).size.width > 600 ? 26 : 22,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: (!isGuest && profileImage.isNotEmpty)
                            ? NetworkImage('${profileVm.profileImageUrl.value}?v=${profileVm.imageVersion.value}')
                            : const AssetImage('assets/images/person_1.png') as ImageProvider,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isGuest
                                    ? "Hello Guest 👋"
                                    : "Hello ${profileVm.name.value.isEmpty ? _cachedUserName : profileVm.name.value}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: Colors.black87,
                                  letterSpacing: 0.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: Lottie.asset('assets/lottie/Hand.json', errorBuilder: (_, __, ___) => const SizedBox()),
                            ),
                            if (isGuest)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300, width: 0.6),
                                ),
                                child: Text(
                                  'Guest',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            if (isGuest)
                              GestureDetector(
                                onTap: () {
                                  Get.offAllNamed(AppRoutes.login);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade300, width: 0.5),
                                  ),
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _openLocationInMap,
                          child: Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.green.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Obx(
                                      () => Text(
                                    homeVm.currentLocationName.value.isEmpty
                                        ? (homeVm.isLocationLoading.value ? "Fetching location..." : "Location unavailable")
                                        : homeVm.currentLocationName.value,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isGuest)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Browsing as Guest • Login for full access',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Obx(() => Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: homeVm.isRefreshing.value
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                )
                    : const Icon(Icons.refresh, color: Colors.green, size: 22),
                onPressed: homeVm.isRefreshing.value ? null : _handleRefresh,
                tooltip: 'Refresh',
              ),
            )),
            const SizedBox(width: 8),
            Obx(() {
              final count = _notificationService.unreadCount.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.notifications_outlined, color: Colors.green, size: 22),
                      onPressed: () async {
                        await Get.to(() => NotificationScreen());
                        _notificationService.updateUnreadCount();
                      },
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ],
        );
      }),
    );
  }
}