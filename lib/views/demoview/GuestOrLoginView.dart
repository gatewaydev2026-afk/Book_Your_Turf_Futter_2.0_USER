// views/guest_or_login_view.dart
// Shown right after the splash screen, BEFORE login.
// Lets the user pick:
//   - "Continue as Guest"  -> HomeView (no token, browse-only, uses the
//                              no-auth guest endpoints for turfs / slots /
//                              discounts)
//   - "Existing User"      -> LoginView (normal authenticated flow)

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';


class GuestOrLoginView extends StatelessWidget {
  const GuestOrLoginView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade800,
              Colors.green.shade600,
              Colors.green.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 60 : 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.sports_soccer,
                  size: 90,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Book Your Turf',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Browse turfs instantly, or sign in for the full experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 48),

                // ✅ Continue as Guest — no token needed
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      print('👤 Continuing as Guest');
                      // ✅ FIX: was Get.offAllNamed(AppRoutes.home) — that
                      // route is the standalone HomeView with NO bottom nav
                      // bar, and it becomes the bottom of the navigation
                      // stack. So (a) guests never saw the tab bar, and
                      // (b) after later logging in mid-flow (e.g. via the
                      // guest-booking-then-register dialog), pressing back
                      // enough times always landed back on this same
                      // tab-less /home instead of a page with tabs.
                      //
                      // /main-page already renders HomeView as its first
                      // tab and already knows how to handle guest mode
                      // (MainPage._loadTabData prompts login only for the
                      // Bookings/Profile tabs, Home works guest or not).
                      // Making /main-page the root of the stack from the
                      // start fixes both: the bottom nav bar is visible
                      // immediately, and it's what back navigation lands
                      // on regardless of whether the user later logs in.
                      Get.offAllNamed(AppRoutes.mainPage);
                    },
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text(
                      'Continue as Guest',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ Existing user — normal login flow (unchanged)
                SizedBox(
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      print('🔐 Going to Login (Existing User)');
                      Get.offAllNamed(AppRoutes.login);
                    },
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text(
                      'Existing User',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}