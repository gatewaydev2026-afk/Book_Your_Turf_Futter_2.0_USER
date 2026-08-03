// main.dart - Complete Final Version with Permanent Device ID & Discount Support
// ✅ Device ID stored in SharedPreferences - NEVER changes
// ✅ ONE ID PER DEVICE - FOREVER
// ✅ DiscountViewModel registered
// ✅ FavoritesViewModel registered
// ✅ CacheManager registered for single API call guarantee
// ✅ Full logout cleanup

import 'package:book_your_turf/config/app_config.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import 'package:book_your_turf/services/chat_bot_service.dart';
import 'package:book_your_turf/services/device_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'routes/app_routes.dart';
import 'routes/route_generator.dart';
import 'themes/app_theme.dart';
import 'services/shared_prefs_helper.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_messaging_service.dart';
// 🔥 Import Facebook App Events
import 'services/facebook_events.dart';
import 'view_models/auth_view_model.dart';
import 'view_models/home_view_model.dart';
import 'view_models/booking_view_model.dart';
import 'view_models/profile_view_model.dart';
import 'view_models/main_page_view_model.dart';
import 'view_models/wallet_view_model.dart';
import 'view_models/coin_view_model.dart';
import 'view_models/discount_view_model.dart';
import 'view_models/favorites_view_model.dart'; // ✅ NEW: FavoritesViewModel
import 'firebase_options.dart';

bool _isAppInitialized = false;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('\n╔════════════════════════════════════════════════════════════╗');
  print('║              BOOK YOUR TURF APP STARTING                    ║');
  print('║  🔥 BASE URL: ${AppConfig.baseUrl}                         ║');
  print('╚════════════════════════════════════════════════════════════╝');

  // 1️⃣ Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
  } catch (e) {
    print('⚠️ Firebase initialization warning: $e');
  }

  // 🔥 Log Facebook App Launch Event
  try {
    await facebookAppEvents.logEvent(
      name: 'fb_mobile_activate_app',
    );
    print('✅ Facebook app launch event logged');
  } catch (e) {
    print('❌ Facebook app launch error: $e');
  }

  // 2️⃣ Initialize SharedPreferences FIRST
  await SharedPrefsHelper.init();
  print('✅ SharedPreferences initialized');

  // 3️⃣ ============================================================
  // ✅ PERMANENT DEVICE ID - NEVER CHANGES
  // ✅ Stored in SharedPreferences - survives reinstall
  // ✅ ONE ID PER DEVICE - FOREVER
  // ============================================================
  final permanentDeviceId = await SharedPrefsHelper.getPermanentDeviceId();

  print('\n╔════════════════════════════════════════════════════════════╗');
  print('║  🔒 PERMANENT DEVICE ID                                    ║');
  print('║  🆔 $permanentDeviceId                                     ║');
  print('║  ✅ This ID will NEVER change                              ║');
  print('║  ✅ ONE ID PER DEVICE - FOREVER                            ║');
  print('║  ✅ Survives app reinstall                                 ║');
  print('╚════════════════════════════════════════════════════════════╝\n');

  // 4️⃣ Check first launch
  final isFirstLaunch = SharedPrefsHelper.isFirstLaunch();
  if (isFirstLaunch) {
    print('🔄 First launch detected - Setting up');
    await SharedPrefsHelper.setFirstLaunch(false);
    print('✅ First launch setup complete');
  } else {
    final tokenExists = SharedPrefsHelper.getToken() != null;
    print('📱 App launched - Token exists: $tokenExists');
    if (tokenExists) {
      final token = SharedPrefsHelper.getToken();
      print('🔑 Token preview: ${token!.substring(0, token.length > 20 ? 20 : token.length)}...');
    }
  }

  // 5️⃣ Initialize Local Notifications
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  print('✅ Local notifications initialized');

  // 6️⃣ Create notification channel for Android
  if (defaultTargetPlatform == TargetPlatform.android) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'user_channel',
      'Book Your Turf',
      description: 'Notifications for bookings, wallet and coins',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    print('✅ Notification channel created');
  }

  // 7️⃣ Initialize Firebase Messaging Service
  try {
    await FirebaseMessagingService.initialize();
    print('✅ Firebase Messaging Service initialized');
  } catch (e) {
    print('⚠️ Firebase Messaging initialization warning: $e');
  }

  // 8️⃣ Request notification permissions
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('✅ Notification permissions requested');
  } catch (e) {
    print('⚠️ Permission request warning: $e');
  }

  // 9️⃣ Request location permission
  try {
    await Geolocator.requestPermission();
    print('📍 Location permission requested');
  } catch (e) {
    print('⚠️ Location permission warning: $e');
  }

  // 🔟 Initialize all dependencies
  await initDependencies();

  // 1️⃣1️⃣ Initialize deep link service
  try {
    final deepLinkService = DeepLinkService();
    await deepLinkService.init();
    print('🔗 Deep Link Service initialized');
  } catch (e) {
    print('⚠️ Deep Link Service warning: $e');
  }

  print('\n═══════════════════════════════════════════════════════════════\n');

  runApp(const MyApp());
}

Future<void> initDependencies() async {
  if (_isAppInitialized) {
    print('⏭️ App already initialized, skipping...');
    return;
  }

  print('\n╔════════════════════════════════════════════════════════════╗');
  print('║              INITIALIZING DEPENDENCIES                      ║');
  print('║  🔥 API BASE URL: ${AppConfig.apiBaseUrl}                  ║');
  print('╚════════════════════════════════════════════════════════════╝');

  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,  // ✅ SINGLE SOURCE OF TRUTH
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Add interceptors
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = SharedPrefsHelper.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      if (kDebugMode) {
        print('📡 API ${options.method} ${options.path}');
        print('📡 FULL URL: ${options.uri}');
        print('📡 AUTH TOKEN: ${options.headers['Authorization']}');
      }
      return handler.next(options);
    },
    onResponse: (response, handler) {
      if (kDebugMode) {
        print('📡 API RESPONSE: ${response.statusCode} ${response.requestOptions.path}');
      }
      return handler.next(response);
    },
    onError: (error, handler) async {
      print('❌ API ERROR: ${error.message}');
      if (error.response?.statusCode == 401) {
        await SharedPrefsHelper.clearAll();
        // ✅ Clear all caches on 401
        if (Get.isRegistered<CacheManager>()) {
          Get.find<CacheManager>().clearAllCaches();
        }
        Get.offAllNamed(AppRoutes.login);
        Get.snackbar(
          'Session Expired',
          'Please login again',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return handler.next(error);
    },
  ));

  // Register ALL services (only once)
  if (!Get.isRegistered<Dio>()) {
    Get.put<Dio>(dio, permanent: true);
    print('✅ Dio registered');
  }

  // ✅ Register CacheManager FIRST - Centralized cache management
  if (!Get.isRegistered<CacheManager>()) {
    Get.put(CacheManager(), permanent: true);
    print('✅ CacheManager registered');
  }

  if (!Get.isRegistered<DeviceManager>()) {
    Get.put(DeviceManager(), permanent: true);
    print('✅ DeviceManager registered');
  }

  if (!Get.isRegistered<AuthViewModel>()) {
    Get.put(AuthViewModel(), permanent: true);
    print('✅ AuthViewModel registered');
  }

  if (!Get.isRegistered<MainPageViewModel>()) {
    Get.put(MainPageViewModel(), permanent: true);
    print('✅ MainPageViewModel registered');
  }

  if (!Get.isRegistered<HomeViewModel>()) {
    Get.put(HomeViewModel(), permanent: true);
    print('✅ HomeViewModel registered');
  }

  if (!Get.isRegistered<BookingViewModel>()) {
    Get.put(BookingViewModel(), permanent: true);
    print('✅ BookingViewModel registered');
  }

  if (!Get.isRegistered<ProfileViewModel>()) {
    Get.put(ProfileViewModel(), permanent: true);
    print('✅ ProfileViewModel registered');
  }

  if (!Get.isRegistered<ChatbotService>()) {
    Get.put(ChatbotService(), permanent: true);
    print('✅ ChatbotService registered');
  }

  if (!Get.isRegistered<WalletViewModel>()) {
    Get.put(WalletViewModel(), permanent: true);
    print('✅ WalletViewModel registered');
  }

  if (!Get.isRegistered<CoinViewModel>()) {
    Get.put(CoinViewModel(), permanent: true);
    print('✅ CoinViewModel registered');
  }

  // ✅ NEW: Register DiscountViewModel
  if (!Get.isRegistered<DiscountViewModel>()) {
    Get.put(DiscountViewModel(), permanent: true);
    print('✅ DiscountViewModel registered');
  }

  // ✅ NEW: Register FavoritesViewModel
  if (!Get.isRegistered<FavoritesViewModel>()) {
    Get.put(FavoritesViewModel(), permanent: true);
    print('✅ FavoritesViewModel registered');
  }

  if (!Get.isRegistered<NotificationService>()) {
    Get.put(NotificationService(), permanent: true);
    print('✅ NotificationService registered');
  }

  _isAppInitialized = true;
  print('✅ All ViewModels and Services registered');
  print('📊 CacheManager initialized for single API call guarantee');
  print('═══════════════════════════════════════════════════════════════\n');
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Book Your Turf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      getPages: RouteGenerator.routes,
      defaultTransition: Transition.cupertino,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}