// main_page.dart - FIXED with transparent background for glass nav
// ✅ FIX (Sep 2026): tab data loads exactly once per tab switch (also when the
//    tab is changed from code, e.g. after a booking); guests no longer land on
//    the Bookings/Dashboard tab behind the login dialog.

import 'package:book_your_turf/services/shared_prefs_helper.dart';
import 'package:book_your_turf/view_models/booking_view_model.dart';
import 'package:book_your_turf/view_models/home_view_model.dart';
import 'package:book_your_turf/view_models/main_page_view_model.dart';
import 'package:book_your_turf/view_models/profile_view_model.dart';
import 'package:book_your_turf/views/booking_history_view.dart';
import 'package:book_your_turf/views/home_view.dart';
import 'package:book_your_turf/views/profile.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;

import '../routes/app_routes.dart';
import '../services/meta_events_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final MainPageViewModel controller = Get.find<MainPageViewModel>();
  final RxSet<int> _loadedTabs = <int>{}.obs;
  bool _initialized = false;

  final List<Widget> screens = [
    const HomeView(),
    BookingHistoryView(),
    ProfileView(),
  ];

  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    // ✅ Any tab change (tap or controller.changeTab) loads that tab's data
    _tabWorker = ever<int>(controller.currentIndex, (i) {
      if (mounted) _loadTabData(i);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        controller.currentIndex.value = 0;
        print('🏠 MainPage initialized - Setting tab to Home (index 0)');
        _loadTabData(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
          () => Scaffold(
        // ✅ FIXED: Make scaffold background transparent
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ✅ Content with IndexedStack
            IndexedStack(
              index: controller.currentIndex.value,
              children: screens,
            ),
            // ✅ Bottom Navigation Bar on top with glass effect
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildGlassNavigationBar(),
            ),
          ],
        ),
        extendBody: true,
        // ✅ Remove the default bottomNavigationBar
        bottomNavigationBar: null,
      ),
    );
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    super.dispose();
  }

  bool get _isGuestNow {
    final token = SharedPrefsHelper.getToken();
    return token == null || token.isEmpty;
  }

  Widget _buildGlassNavigationBar() {
    return Obx(
          () => Container(
        height: 65,
        margin: EdgeInsets.fromLTRB(
          16,
          2,
          16,
          MediaQuery.of(Get.context!).padding.bottom + 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(35),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(
                    'assets/icons/home-green.svg',
                    'assets/icons/home-grey.svg',
                    "Home",
                    0,
                  ),
                  _navItem(
                    'assets/icons/history-green.svg',
                    'assets/icons/history-grey.svg',
                    "Bookings",
                    1,
                  ),
                  _navItem(
                    'assets/icons/profile-green.svg',
                    'assets/icons/profile-grey.svg',
                    "Dashboard",
                    2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      String activeIcon,
      String inactiveIcon,
      String label,
      int index,
      ) {
    final isActive = controller.currentIndex.value == index;

    return GestureDetector(
      onTap: () {
        if (index != 0 && _isGuestNow) {
          _showLoginRequiredDialog(index);
          return;
        }
        if (controller.currentIndex.value == index) return;
        controller.changeTab(index); // ever() worker loads the data
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF009624).withOpacity(0.9),
              const Color(0xFF00B42A).withOpacity(0.9),
            ],
          )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: const Color(0xFF009624).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: isActive
                  ? SvgPicture.asset(
                activeIcon,
                height: 22,
                width: 22,
                key: ValueKey('active-$index'),
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              )
                  : SvgPicture.asset(
                inactiveIcon,
                height: 22,
                width: 22,
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
                key: ValueKey('inactive-$index'),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _loadTabData(int index) async {
    final homeVm = Get.find<HomeViewModel>();

    // ✅ Token is the source of truth (isGuestMode can be stale right after login)
    final bool hasToken = !_isGuestNow;
    homeVm.isGuestMode.value = !hasToken;

    if (!hasToken) {
      if (index != 0) {
        print('👤 Guest mode - Showing login prompt for tab $index');
        controller.changeTab(0);
        _showLoginRequiredDialog(index);
        return;
      }
      await homeVm.loadHomeData();
      _loadedTabs.add(index);
      return;
    }

    switch (index) {
      case 0:
        // single-flight + cache inside HomeViewModel → no duplicate calls
        await homeVm.loadHomeData();
        _loadedTabs.add(index);
        break;

      case 1:
        // loadBookings() uses its own 5-min cache, so this is cheap when fresh
        final bookingVm = Get.find<BookingViewModel>();
        await bookingVm.loadBookings();
        bookingVm.logHistoryView(); // 📊 Meta
        _loadedTabs.add(index);
        break;

      case 2:
        final profileVm = Get.find<ProfileViewModel>();
        await profileVm.fetchUser();
        // 📊 Meta: dashboard opened
        MetaEvents.screenView('dashboard', {
          'has_wallet_balance': profileVm.walletBalance.value > 0 ? 1 : 0,
        });
        _loadedTabs.add(index);
        break;
    }
  }

  void _showLoginRequiredDialog(int index) {
    Get.dialog(
      AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to access this feature.'),
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
}