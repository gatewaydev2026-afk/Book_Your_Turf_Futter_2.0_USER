// main_page.dart - Tab மாறும்போது மட்டுமே API call

import 'package:book_your_turf/services/shared_prefs_helper.dart';
import 'package:book_your_turf/view_models/booking_view_model.dart';
import 'package:book_your_turf/view_models/home_view_model.dart';
import 'package:book_your_turf/view_models/main_page_view_model.dart';
import 'package:book_your_turf/view_models/profile_view_model.dart';
import 'package:book_your_turf/views/booking_history_view.dart';
import 'package:book_your_turf/views/home_view.dart';
import 'package:book_your_turf/views/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;

class MainPage extends StatelessWidget {
  MainPage({super.key});
  final MainPageViewModel controller = Get.find();

  // Track which tabs have been loaded
  final RxSet<int> _loadedTabs = <int>{}.obs;

  final List<Widget> screens = [
    HomeView(),
    BookingHistoryView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(
          () => Scaffold(
        body: IndexedStack(
          index: controller.currentIndex.value,
          children: screens,
        ),
        extendBody: true,
        bottomNavigationBar: _buildGlassNavigationBar(),
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
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.2,
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
        // Change tab first
        controller.changeTab(index);
        // Then load data for that tab (only once per tab)
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

  // ✅ Tab-க்கு ஏற்ப ONLY ONE TIME API call
  void _loadTabData(int index) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      print('🚫 User not logged in, skipping data load');
      return;
    }

    // ✅ If already loaded this tab, skip API call
    if (_loadedTabs.contains(index)) {
      print('✅ Tab $index already loaded, skipping API call');
      return;
    }

    print('\n📱 Tab $index selected - Loading data for first time...');

    try {
      switch (index) {
        case 0: // Home Tab
          final homeVm = Get.find<HomeViewModel>();
          if (homeVm.allTurfs.isEmpty && !homeVm.isLoading.value) {
            print('🏠 Loading Home data...');
            await homeVm.loadHomeData();
            _loadedTabs.add(index);
          } else {
            print('✅ Home data already available (${homeVm.allTurfs.length} turfs)');
            _loadedTabs.add(index);
          }
          break;

        case 1: // Bookings Tab
          final bookingVm = Get.find<BookingViewModel>();
          if (bookingVm.bookings.isEmpty && !bookingVm.isLoading.value) {
            print('📅 Loading Bookings data...');
            await bookingVm.fetch();
            _loadedTabs.add(index);
          } else {
            print('✅ Bookings data already available (${bookingVm.bookings.length} bookings)');
            _loadedTabs.add(index);
          }
          break;

        case 2: // Profile Tab
          final profileVm = Get.find<ProfileViewModel>();
          if (profileVm.name.value.isEmpty && !profileVm.isLoading.value) {
            print('👤 Loading Profile data...');
            await profileVm.fetchUser();
            _loadedTabs.add(index);
          } else {
            print('✅ Profile data already available');
            _loadedTabs.add(index);
          }
          break;
      }
    } catch (e) {
      print('❌ Error loading data for tab $index: $e');
    }
  }
}