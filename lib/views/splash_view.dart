// splash_view.dart - FIXED for first launch with duplicate navigation prevention

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../routes/app_routes.dart';
import '../services/shared_prefs_helper.dart';
import '../themes/app_colors.dart';

class SplashView extends StatefulWidget {
  const SplashView({Key? key}) : super(key: key);

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String displayText = "";
  final String fullText = "Book Your Turf";

  final Color subtitleColor = Colors.grey.shade600;

  // ✅ Prevent duplicate navigation
  bool _isNavigating = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);
    _fadeController.forward();
    _typeText();

    // ✅ Only call navigation once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _isInitialized = true;
        _checkAndNavigate();
      }
    });
  }

  void _typeText() async {
    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (mounted) setState(() => displayText = fullText.substring(0, i + 1));
    }
  }

  Future<void> _checkAndNavigate() async {
    // ✅ Prevent duplicate navigation
    if (_isNavigating) {
      print('⏭️ Navigation already in progress - skipping');
      return;
    }

    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    _isNavigating = true;

    // Get first launch status
    final isFirstLaunch = SharedPrefsHelper.isFirstLaunch();

    // Get token
    final token = SharedPrefsHelper.getToken();

    print('\n========== SPLASH NAVIGATION ==========');
    print('Is First Launch: $isFirstLaunch');
    print('Token exists: ${token != null}');
    if (token != null && token.isNotEmpty) {
      print('Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    }

    if (!mounted) return;

    // If it's first launch, ALWAYS go to the Guest/Existing-user picker
    if (isFirstLaunch) {
      print('✅ First launch detected - Navigating to Guest/Login picker');
      await SharedPrefsHelper.clearAll();
      await SharedPrefsHelper.setFirstLaunch(false);
      if (mounted) {
        Get.offAllNamed(AppRoutes.guestOrLogin);
      }
    }
    // If token exists and not first launch, go to main page
    else if (token != null && token.isNotEmpty) {
      print('✅ Token found - Navigating to MainPage');
      if (mounted) {
        Get.offAllNamed(AppRoutes.mainPage);
      }
    }
    // No token and not first launch, go to Guest/Existing-user picker
    else {
      print('❌ No token found - Navigating to Guest/Login picker');
      if (mounted) {
        Get.offAllNamed(AppRoutes.guestOrLogin);
      }
    }

    print('========================================\n');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Lottie.asset(
              'assets/lottie/BYT_2_CP_splash.json',
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.sports_cricket,
                size: 100,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Owned by',
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        'Nottam Infotech Private Limited',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontFamily: 'Balloon',
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}