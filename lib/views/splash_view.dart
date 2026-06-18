// views/splash_view.dart - FIXED for first launch

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

    _checkAndNavigate();
  }

  void _typeText() async {
    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (mounted) setState(() => displayText = fullText.substring(0, i + 1));
    }
  }

  Future<void> _checkAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 3000));

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

    if (mounted) {
      // If it's first launch, ALWAYS go to login regardless of token
      if (isFirstLaunch) {
        print('✅ First launch detected - Navigating to Login');
        // Clear any existing token on first launch
        await SharedPrefsHelper.clearAll();
        await SharedPrefsHelper.setFirstLaunch(false);
        Get.offAllNamed(AppRoutes.login);
      }
      // If token exists and not first launch, go to main page
      else if (token != null && token.isNotEmpty) {
        print('✅ Token found - Navigating to MainPage');
        Get.offAllNamed(AppRoutes.mainPage);
      }
      // No token and not first launch, go to login
      else {
        print('❌ No token found - Navigating to Login');
        Get.offAllNamed(AppRoutes.login);
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