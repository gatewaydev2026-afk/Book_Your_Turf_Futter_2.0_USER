// home_view.dart - Complete with Better Pagination Design
// ✅ Modern loading indicator
// ✅ Smooth pagination with shimmer effect
// ✅ Pull to refresh with improved UI
// ✅ FIXED: Search shows ALL turfs (any distance)

import 'dart:async';
import 'package:book_your_turf/views/profile_view.dart';
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
    _categoryHeightAnimation = Tween<double>(begin: 230, end: 65).animate(
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
    if (token == null || token.isEmpty) {
      print('🚫 User not logged in, skipping home data load');
      return;
    }

    if (!SharedPrefsHelper.isTokenValid()) {
      print('⚠️ Token expired, redirecting to login');
      await SharedPrefsHelper.clearToken();
      Get.offAllNamed(AppRoutes.login);
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
    }
    else if (delta < -5 && _isCategoryMinimized && currentOffset < 50) {
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
      if (SharedPrefsHelper.isLoggedIn() && SharedPrefsHelper.isTokenValid()) {
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
    homeVm.showSuggestions.value = query.isNotEmpty;
  }

  Future<void> _onProfileTap() async {
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

  Future<void> _onCategoryTap(String filter) async {
    await _handleClick('category_$filter', () async {
      homeVm.filterByCategory(filter);
    });
  }

  void _openChatbot() {
    Get.to(() => ChatbotView());
  }

  void _openNotificationScreen() {
    Get.to(() =>  NotificationScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7F6),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                        height: 40,
                        alignment: Alignment.center,
                        child: Text(
                          "Hello $_cachedUserName!",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    if (!_showGreeting) _headerSection(context),
                    _searchBar(),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _categoryAnimationController,
                      builder: (context, child) {
                        return Container(
                          height: _categoryHeightAnimation.value,
                          width: double.infinity,
                          child: !_isCategoryMinimized
                              ? SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _allCategoryCard(),
                                const SizedBox(height: 8),
                                _threeCategoriesRow(),
                              ],
                            ),
                          )
                              : _miniCategorySection(),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _buildMainContent(),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 16,
              child: GestureDetector(
                onTap: _openChatbot,
                child: Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.6),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Lottie.asset(
                      'assets/lottie/chatbot.json',
                      height: 90,
                      width: 90,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.chat, size: 50, color: Colors.green);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
            height: 95,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff667eea), Color(0xff764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "All",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Image.asset(
                      'assets/sports/all .png',
                      height: 120,
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
              padding: EdgeInsets.only(right: index != 2 ? 8 : 0),
              child: Obx(() {
                final isSelected = homeVm.selectedCategory.value == filter;
                return GestureDetector(
                  onTap: () => _onCategoryTap(filter),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: category["colors"] as List<Color>,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 2),
                    ),
                    child: Stack(
                      children: [
                        Image.asset(
                          category["image1"] as String,
                          height: 180,
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                        ),
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                category["name"] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 2
                                    ..color = Colors.black,
                                ),
                              ),
                              Text(
                                category["name"] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
      {"name": "Badminton", "filter": "Badminton"},
      {"name": "Pickleball", "filter": "Pickleball"},
    ];

    return Container(
      height: 45,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.white,
                    borderRadius: BorderRadius.circular(15),
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
                        fontSize: 9,
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

  // ============================================================
  // ✅ MAIN CONTENT WITH SEARCH SUPPORT
  // ============================================================
  Widget _buildMainContent() {
    return Obx(() {
      // ✅ Loading State - Shimmer Effect
      if (homeVm.isLoading.value && homeVm.turfs.isEmpty) {
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

      // ✅ Search Empty State - Show when search has no results
      if (homeVm.searchQuery.value.isNotEmpty &&
          homeVm.turfs.isEmpty &&
          !homeVm.isLoading.value) {
        return _buildSearchEmptyState();
      }

      // ✅ Search Results or Nearby Turfs
      if (homeVm.turfs.isNotEmpty) {
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

      // ✅ Default Empty State
      return _buildEmptyState();
    });
  }

  // ✅ Search Empty State
  Widget _buildSearchEmptyState() {
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
          Text(
            'No turfs found for "${homeVm.searchQuery.value}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search terms',
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

  // ============================================================
  // HEADER SECTION
  // ============================================================
  Widget _headerSection(BuildContext context) {
    final profileImage = profileVm.profileImageUrl.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: Row(
              children: [
                InkWell(
                  onTap: _onProfileTap,
                  child: CircleAvatar(
                    radius: MediaQuery.of(context).size.width > 600 ? 26 : 22,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: profileImage.isNotEmpty
                        ? NetworkImage('${profileVm.profileImageUrl.value}?v=${profileVm.imageVersion.value}')
                        : const AssetImage('assets/images/person_1.png') as ImageProvider,
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
                            child: Obx(
                                  () => Text(
                                "Hello ${profileVm.name.value.isEmpty ? _cachedUserName : profileVm.name.value}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Lottie.asset('assets/lottie/Hand.json', errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _openLocationInMap,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Obx(
                                    () => Text(
                                  homeVm.currentLocationName.value.isEmpty
                                      ? (homeVm.isLocationLoading.value ? "Fetching location..." : "Location unavailable")
                                      : homeVm.currentLocationName.value,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Refresh Icon Button
          Obx(() => Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
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
          // Notification Icon with Badge
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
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.notifications_outlined, color: Colors.green, size: 22),
                    onPressed: () async {
                      await Get.to(() =>  NotificationScreen());
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
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 45,
      decoration: BoxDecoration(
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final query = _searchController.text;
              if (query.trim().isNotEmpty) {
                // ✅ Explicit trigger — this is what fires the API call
                homeVm.performSearch(query);
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
              onSubmitted: (query) {
                // ✅ Explicit trigger — this is what fires the API call
                homeVm.performSearch(query);
                _searchFocusNode.unfocus();
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search turfs, locations...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                suffixIcon: Obx(() {
                  if (homeVm.searchQuery.value.isNotEmpty) {
                    return IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () async {
                        _searchController.clear();
                        homeVm.clearSearch();
                        homeVm.showSuggestions.value = false;
                        _searchFocusNode.unfocus();
                      },
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ),
            ),
          ),
          // ✅ Search loading indicator
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
}