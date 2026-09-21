// firebase_messaging_service.dart - COMPLETE FIXED VERSION
// ✅ Prevents duplicate notifications, handles token refresh properly
// ✅ Fixed: Background handler is now a TOP-LEVEL function with @pragma

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'shared_prefs_helper.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

// ✅ 1. TOP-LEVEL BACKGROUND HANDLER (MUST be outside class)
// ✅ 2. Must be annotated with @pragma('vm:entry-point')
// ✅ FIX (Sep 2026): this is now the ONLY background handler in the app
//    (DeviceManager used to register a second one, which silently replaced
//    this one). Remote-logout is handled here too.
// ✅ FIX: messages that already carry a `notification` block are shown by
//    Android itself – showing a local one as well gave duplicate notifications.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  print('📨 BACKGROUND MESSAGE: ${message.messageId}');

  try {
    if (message.data['type'] == 'device_logout') {
      print('🔴 Device logout notification received in background');
      await SharedPrefsHelper.init();
      final myDeviceId = await SharedPrefsHelper.getPermanentDeviceId();
      final target = message.data['device_id']?.toString();
      if (target == null || target.isEmpty || target == myDeviceId) {
        await SharedPrefsHelper.clearAll();
      }
      return;
    }

    if (message.notification == null) {
      // data-only push → we must show it ourselves
      await FirebaseMessagingService._showBackgroundNotification(message);
    }
  } catch (e) {
    print('⚠️ Background notification error: $e');
  }
}

class FirebaseMessagingService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static bool _isTokenRegistered = false;
  static final Set<String> _processedMessageIds = {};
  static final Set<String> _processedTokens = {};
  static Timer? _cleanupTimer;

  static const _maxProcessedIds = 100;
  static const _cleanupInterval = Duration(minutes: 5);

  static Future<void> initialize() async {
    if (_isInitialized) {
      print('⏭️ Firebase Messaging already initialized');
      return;
    }

    try {
      // Initialize local notifications
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(settings);
      print('✅ Local notifications plugin initialized');

      // ✅ Register the TOP-LEVEL background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // ✅ NOTE: Foreground/opened-app message handling intentionally NOT
      // registered here anymore. NotificationService already listens to
      // FirebaseMessaging.onMessage / getInitialMessage / onMessageOpenedApp
      // and shows the system tray notification. Having BOTH services listen
      // was causing: 2 tray notifications for one push + an extra Get.snackbar
      // popup from this service. This service now only handles background
      // registration + FCM token retrieval.

      // Get FCM token
      await _getAndStoreToken();

      // Start cleanup timer
      _startCleanupTimer();

      _isInitialized = true;
      print('✅ Firebase Messaging fully initialized');

    } catch (e) {
      print('❌ Firebase Messaging initialization error: $e');
    }
  }

  static void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _cleanupProcessedIds();
    });
  }

  static void _cleanupProcessedIds() {
    if (_processedMessageIds.length > _maxProcessedIds) {
      final ids = _processedMessageIds.toList();
      final toRemove = ids.sublist(0, ids.length - _maxProcessedIds);
      for (var id in toRemove) {
        _processedMessageIds.remove(id);
      }
      print('🧹 Cleaned ${toRemove.length} old message IDs');
    }
  }

  static Future<void> _getAndStoreToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('📱 FCM Token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
        _processedTokens.add(token);
      } else {
        print('⚠️ FCM Token is null');
      }
    } catch (e) {
      print('⚠️ Error getting FCM token: $e');
    }
  }

  // ✅ Called from background handler (static)
  static Future<void> _showBackgroundNotification(RemoteMessage message) async {
    // background isolate: the plugin must be initialised here as well
    try {
      await _localNotifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
    } catch (_) {}
    await _showLocalNotification(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      // same channel as NotificationService / main.dart
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'user_channel',
        'Book Your Turf',
        channelDescription: 'Notifications for bookings, wallet and coins',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        showWhen: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate unique ID from message ID or content
      final id = message.messageId?.hashCode.abs() ??
          '${message.notification?.title}-${message.notification?.body}'.hashCode.abs();

      await _localNotifications.show(
        id,
        message.notification?.title ?? message.data['title']?.toString() ?? 'New Notification',
        message.notification?.body ?? message.data['body']?.toString() ?? '',
        details,
        payload: message.data.toString(),
      );

      print('✅ Local notification shown (ID: $id)');
    } catch (e) {
      print('⚠️ Error showing local notification: $e');
    }
  }

  static Future<void> subscribeToTopics() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        print('❌ No FCM token available');
        return;
      }

      await FirebaseMessaging.instance.subscribeToTopic('all_users');
      await FirebaseMessaging.instance.subscribeToTopic('offers');
      print('✅ Subscribed to notification topics');
    } catch (e) {
      print('❌ Failed to subscribe to topics: $e');
    }
  }

  static Future<void> unsubscribeFromTopics() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      await FirebaseMessaging.instance.unsubscribeFromTopic('offers');
      print('✅ Unsubscribed from notification topics');
    } catch (e) {
      print('❌ Failed to unsubscribe from topics: $e');
    }
  }

  static Future<String?> refreshToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        if (_processedTokens.contains(token)) {
          print('⏭️ Token already processed');
          return token;
        }
        _processedTokens.add(token);
        print('📱 Refreshed FCM Token');
        return token;
      }
      return null;
    } catch (e) {
      print('⚠️ Error refreshing token: $e');
      return null;
    }
  }

  static void clearProcessedIds() {
    _processedMessageIds.clear();
    _processedTokens.clear();
    print('🧹 Cleared all processed IDs');
  }

  static void dispose() {
    _cleanupTimer?.cancel();
    _isInitialized = false;
    _isTokenRegistered = false;
    print('🗑️ Firebase Messaging Service disposed');
  }
}