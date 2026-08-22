import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import '../routes/app_routes.dart';
import 'shared_prefs_helper.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  String? _pendingReferralCode;
  AppLinks? _appLinks;
  StreamSubscription? _linkSubscription;

  String? get pendingReferralCode => _pendingReferralCode;

  Future<void> init() async {
    try {
      _appLinks = AppLinks();

      // Handle initial link when app is started from cold state
      await _handleInitialLink();

      // Handle links when app is in foreground
      _handleLinkStream();

      print('✅ DeepLinkService initialized successfully');
    } catch (e) {
      print('❌ DeepLinkService initialization error: $e');
    }
  }

  Future<void> _handleInitialLink() async {
    try {
      // Old name use pannu if package not updated
      final Uri? initialUri = await _appLinks?.getInitialAppLink();  // ← Change here

      if (initialUri != null) {
        print('🔗 Initial deep link received: $initialUri');
        _processDeepLink(initialUri.toString());
      } else {
        print('🔗 No initial deep link');
      }
    } catch (e) {
      print('❌ Error getting initial link: $e');
    }
  }
  void _handleLinkStream() {
    // FIXED: Use uriLinkStream (not getLinkStream)
    _linkSubscription = _appLinks?.uriLinkStream.listen((Uri uri) {
      print('🔗 Deep link received while app running: $uri');
      _processDeepLink(uri.toString());
    }, onError: (err) {
      print('❌ Deep link stream error: $err');
    });
  }

  void _processDeepLink(String link) {
    print('🔍 Processing deep link: $link');

    String? referralCode;

    try {
      Uri uri = Uri.parse(link);

      // Method 1: Play Store link with query param
      if (uri.host == 'play.google.com' && uri.path.contains('/store/apps/details')) {
        if (uri.queryParameters.containsKey('referral_code')) {
          referralCode = uri.queryParameters['referral_code'];
          print('✅ Referral code from Play Store link: $referralCode');
        } else if (uri.queryParameters.containsKey('referral')) {
          referralCode = uri.queryParameters['referral'];
          print('✅ Referral code from referral param: $referralCode');
        } else if (uri.queryParameters.containsKey('ref')) {
          referralCode = uri.queryParameters['ref'];
          print('✅ Referral code from ref param: $referralCode');
        }
      }

      // Method 2: Your website domain
      if (referralCode == null && (uri.host == 'book_your_turf.com' || uri.host == 'www.book_your_turf.com')) {
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'refer' && uri.pathSegments.length > 1) {
          referralCode = uri.pathSegments[1];
          print('✅ Referral code from website path: $referralCode');
        }
        if (referralCode == null && uri.queryParameters.containsKey('referral_code')) {
          referralCode = uri.queryParameters['referral_code'];
          print('✅ Referral code from website query: $referralCode');
        }
      }

      // Method 3: Custom URL scheme - book_your_turf://refer/ABC123
      if (referralCode == null && uri.scheme == 'book_your_turf') {
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'refer' && uri.pathSegments.length > 1) {
          referralCode = uri.pathSegments[1];
          print('✅ Referral code from custom scheme: $referralCode');
        }
      }

      // Method 4: Generic query parameters
      if (referralCode == null && uri.queryParameters.containsKey('referral_code')) {
        referralCode = uri.queryParameters['referral_code'];
        print('✅ Referral code from generic referral_code param: $referralCode');
      }

      if (referralCode == null && uri.queryParameters.containsKey('ref')) {
        referralCode = uri.queryParameters['ref'];
        print('✅ Referral code from ref param: $referralCode');
      }

      if (referralCode != null && referralCode.isNotEmpty) {
        _pendingReferralCode = referralCode;
        print('✅ Referral code extracted and stored: $referralCode');
        _handleReferralCode();
      } else {
        print('❌ No referral code found in deep link');
      }

    } catch (e) {
      print('❌ Error parsing deep link: $e');
    }
  }

  void _handleReferralCode() async {
    if (_pendingReferralCode != null) {
      await SharedPrefsHelper.setPendingReferralCode(_pendingReferralCode!);
      print('📦 Referral code saved to SharedPreferences: ${_pendingReferralCode}');

      final isLoggedIn = SharedPrefsHelper.isLoggedIn();

      if (!isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentRoute = Get.currentRoute;
          print('📍 Current route: $currentRoute');

          if (currentRoute == AppRoutes.register) {
            print('✅ Already on signup page, updating controller');
            _updateSignupController();
          } else if (currentRoute == AppRoutes.splash) {
            print('⏳ On splash screen, will apply on signup navigation');
          } else {
            print('🚀 Navigating to signup with referral code');
            Get.toNamed(AppRoutes.register);
          }
        });
      } else {
        print('👤 User already logged in, showing referral bonus message');
        _showReferralBonusMessage();
      }
    }
  }

  void _updateSignupController() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (Get.isRegistered<SignupController>()) {
        final controller = Get.find<SignupController>();
        if (_pendingReferralCode != null) {
          controller.setReferralCode(_pendingReferralCode!);
          print('✅ SignupController updated with referral code: ${_pendingReferralCode}');
        }
      } else {
        print('⏳ SignupController not yet registered, retrying...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (Get.isRegistered<SignupController>()) {
            final controller = Get.find<SignupController>();
            if (_pendingReferralCode != null) {
              controller.setReferralCode(_pendingReferralCode!);
              print('✅ SignupController updated (retry) with referral code: ${_pendingReferralCode}');
            }
          }
        });
      }
    });
  }

  void _showReferralBonusMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar(
        '🎉 Referral Code Applied!',
        'You will get bonus coins on your next booking!',
        backgroundColor: Colors.white,
        colorText: Colors.black,
        duration: const Duration(seconds: 1),
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.card_giftcard, color: Colors.white),
      );
    });
  }

  String? consumePendingReferral() {
    final code = _pendingReferralCode;
    _pendingReferralCode = null;
    return code;
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  String generateShareLink(String code) {
    return 'https://play.google.com/store/apps/details?id=com.book_your_turf.app&referral_code=$code';
  }

  String generateDeepLinkScheme(String code) {
    return 'book_your_turf://refer/$code';
  }
}

// SignupController
class SignupController extends GetxController {
  final referralCodeController = TextEditingController();
  final hasReferralFromLink = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkForPendingReferral();
    print('📱 SignupController initialized');
  }

  Future<void> _checkForPendingReferral() async {
    print('🔍 SignupController: Checking for pending referral code');

    final pendingCode = await SharedPrefsHelper.getPendingReferralCode();
    if (pendingCode != null && pendingCode.isNotEmpty) {
      print('✅ Found pending referral code in SharedPreferences: $pendingCode');
      referralCodeController.text = pendingCode;
      hasReferralFromLink.value = true;
      await SharedPrefsHelper.clearPendingReferralCode();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          '🎉 Referral Code Applied!',
          'Referral code "$pendingCode" has been auto-filled',
          backgroundColor: Colors.white,
          colorText: Colors.black,
          duration: const Duration(seconds: 1),
          snackPosition: SnackPosition.TOP,
          icon: const Icon(Icons.card_giftcard, color: Colors.white),
        );
      });
    }

    final deepLinkService = DeepLinkService();
    final directCode = deepLinkService.consumePendingReferral();
    if (directCode != null && directCode.isNotEmpty && referralCodeController.text.isEmpty) {
      referralCodeController.text = directCode;
      hasReferralFromLink.value = true;
      print('✅ Referral code from deep link service (direct): $directCode');
    }

    if (referralCodeController.text.isEmpty) {
      print('📭 No pending referral code found');
    }
  }

  void setReferralCode(String code) {
    if (code.isNotEmpty && referralCodeController.text.isEmpty) {
      referralCodeController.text = code;
      hasReferralFromLink.value = true;
      print('✅ Referral code set programmatically: $code');

      Get.snackbar(
        '🎉 Referral Code Applied!',
        'Referral code "$code" has been applied',
        backgroundColor: Colors.black,
        colorText: Colors.black,
        duration: const Duration(seconds: 1),
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.card_giftcard, color: Colors.white),
      );
    }
  }

  void clearReferralCode() {
    referralCodeController.clear();
    hasReferralFromLink.value = false;
    print('🗑️ Referral code cleared');
  }

  @override
  void onClose() {
    referralCodeController.dispose();
    super.onClose();
  }
}