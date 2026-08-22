// splash_view.dart - With phone permission request during splash

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../routes/app_routes.dart';
import '../services/shared_prefs_helper.dart';
import '../services/phone_auto_detect_service.dart';
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

  // ✅ Permission status
  bool _permissionGranted = false;
  bool _permissionChecked = false;

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

    // ✅ Request phone permission and detect number during splash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _isInitialized = true;
        _requestPhonePermissionAndNavigate();
      }
    });
  }

  void _typeText() async {
    for (int i = 0; i < fullText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (mounted) setState(() => displayText = fullText.substring(0, i + 1));
    }
  }

  // ✅ Request phone permission and detect number during splash
  Future<void> _requestPhonePermissionAndNavigate() async {
    // ✅ Prevent duplicate navigation
    if (_isNavigating) {
      print('⏭️ Navigation already in progress - skipping');
      return;
    }

    print('\n========== SPLASH: REQUESTING PHONE PERMISSION ==========');

    try {
      // ✅ Request phone permission
      final status = await Permission.phone.request();
      _permissionGranted = status.isGranted;
      _permissionChecked = true;

      print('📱 Phone permission status: ${status.isGranted ? "GRANTED ✅" : "DENIED ❌"}');

      if (status.isGranted) {
        // ✅ Detect phone number immediately
        print('📱 Detecting phone number during splash...');
        final numbers = await PhoneAutoDetectService.getSimPhoneNumbers();
        if (numbers.isNotEmpty) {
          print('✅ Phone number detected during splash: ${numbers.first}');
          // Store it for later use
          await PhoneAutoDetectService.setDetectedNumber(numbers.first);
        } else {
          print('ℹ️ No phone number detected during splash');
        }
      } else if (status.isPermanentlyDenied) {
        print('❌ Phone permission permanently denied');
        // Show dialog to guide user to settings
        if (mounted) {
          _showPermissionDeniedDialog();
          return;
        }
      } else {
        print('❌ Phone permission denied');
      }
    } catch (e) {
      print('❌ Error requesting phone permission: $e');
    }

    // ✅ Wait for splash animation to complete
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;
    _isNavigating = true;

    // Navigate based on first launch and token
    final isFirstLaunch = SharedPrefsHelper.isFirstLaunch();
    final token = SharedPrefsHelper.getToken();

    print('\n========== SPLASH NAVIGATION ==========');
    print('Is First Launch: $isFirstLaunch');
    print('Token exists: ${token != null}');
    print('Phone permission: ${_permissionGranted ? "GRANTED ✅" : "DENIED ❌"}');

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

  // ✅ Show dialog if permission is permanently denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Phone Permission Required'),
        content: const Text(
          'Phone permission is required to automatically detect your SIM number for quick login. '
              'Please enable it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isNavigating = false;
              _checkAndNavigateWithoutPermission();
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ✅ Fallback navigation if permission denied
  Future<void> _checkAndNavigateWithoutPermission() async {
    if (_isNavigating) return;
    _isNavigating = true;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final isFirstLaunch = SharedPrefsHelper.isFirstLaunch();
    final token = SharedPrefsHelper.getToken();

    if (isFirstLaunch) {
      await SharedPrefsHelper.clearAll();
      await SharedPrefsHelper.setFirstLaunch(false);
      if (mounted) {
        Get.offAllNamed(AppRoutes.guestOrLogin);
      }
    } else if (token != null && token.isNotEmpty) {
      if (mounted) {
        Get.offAllNamed(AppRoutes.mainPage);
      }
    } else {
      if (mounted) {
        Get.offAllNamed(AppRoutes.guestOrLogin);
      }
    }
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