// main_page.dart - FIXED with transparent background for glass nav

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

  @override
  void initState() {
    super.initState();
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
        controller.changeTab(index);
        _loadTabData(index);
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
    final isGuest = homeVm.isGuestMode.value;

    final token = SharedPrefsHelper.getToken();
    final bool hasToken = token != null && token.isNotEmpty;

    if (!hasToken) {
      homeVm.isGuestMode.value = true;
    }

    if (isGuest || !hasToken) {
      if (index != 0) {
        print('👤 Guest mode - Showing login prompt for tab $index');
        _showLoginRequiredDialog(index);
        return;
      }
      if (homeVm.allTurfs.isEmpty && !homeVm.isLoading.value) {
        print('🏠 Guest mode - Loading home data...');
        await homeVm.loadHomeData();
        _loadedTabs.add(index);
      } else {
        print('✅ Home data available (${homeVm.allTurfs.length} turfs)');
        _loadedTabs.add(index);
      }
      return;
    }

    switch (index) {
      case 0:
        print('🏠 Home tab selected - Ensuring data is loaded...');
        if (homeVm.allTurfs.isEmpty && !homeVm.isLoading.value) {
          print('📡 Home data empty - Loading now...');
          await homeVm.loadHomeData();
        } else if (homeVm.isLoading.value) {
          print('⏳ Home data is loading, waiting...');
          await Future.delayed(const Duration(milliseconds: 800));
          if (homeVm.allTurfs.isEmpty) {
            print('⚠️ Home data still empty, retrying...');
            await homeVm.loadHomeData();
          }
        }
        if (homeVm.allTurfs.isNotEmpty) {
          print('✅ Home data available (${homeVm.allTurfs.length} turfs)');
          _loadedTabs.add(index);
        }
        break;

      case 1:
        if (_loadedTabs.contains(index)) {
          print('✅ Bookings already loaded, skipping');
          return;
        }
        print('📅 Loading Bookings data...');
        final bookingVm = Get.find<BookingViewModel>();
        if (bookingVm.bookings.isEmpty && !bookingVm.isLoading.value) {
          await bookingVm.loadBookings();
        }
        _loadedTabs.add(index);
        break;

      case 2:
        if (_loadedTabs.contains(index)) {
          print('✅ Profile already loaded, skipping');
          return;
        }
        print('👤 Loading Profile data...');
        final profileVm = Get.find<ProfileViewModel>();
        if (profileVm.name.value.isEmpty && !profileVm.isLoading.value) {
          await profileVm.fetchUser();
        }
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