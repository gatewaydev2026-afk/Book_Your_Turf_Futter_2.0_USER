// firebase_messaging_service.dart - COMPLETE FIXED VERSION
// ✅ Prevents duplicate notifications, handles token refresh properly
// ✅ Fixed: Background handler is now a TOP-LEVEL function with @pragma

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

// ✅ 1. TOP-LEVEL BACKGROUND HANDLER (MUST be outside class)
// ✅ 2. Must be annotated with @pragma('vm:entry-point')
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ✅ 3. Initialize any services needed
  // WidgetsFlutterBinding.ensureInitialized();

  print('📨 BACKGROUND MESSAGE: ${message.messageId}');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');

  try {
    // Show notification using a separate helper or static method
    await FirebaseMessagingService._showBackgroundNotification(message);
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
    await _showLocalNotification(message);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'book_your_turf_channel',
        'Book Your Turf Notifications',
        channelDescription: 'Notifications for bookings, wallet updates, and offers',
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
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
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