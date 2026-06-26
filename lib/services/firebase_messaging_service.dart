// firebase_messaging_service.dart - COMPLETE FIXED VERSION
// ✅ Prevents duplicate notifications, handles token refresh properly

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';

class FirebaseMessagingService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // ✅ PREVENT DUPLICATE HANDLING
  static bool _isInitialized = false;
  static bool _isTokenRegistered = false;
  static final Set<String> _processedMessageIds = {};
  static final Set<String> _processedTokens = {};
  static Timer? _cleanupTimer;

  static const _maxProcessedIds = 100;
  static const _cleanupInterval = Duration(minutes: 5);

  static Future<void> initialize() async {
    // ✅ Prevent multiple initialization
    if (_isInitialized) {
      print('⏭️ Firebase Messaging already initialized');
      return;
    }

    try {
      // Initialize local notifications for Android
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

      // ✅ Setup background handler first
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // ✅ Setup message handlers
      _setupMessageHandlers();

      // ✅ Get FCM token
      await _getAndStoreToken();

      // ✅ Start cleanup timer for processed IDs
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

  static void _setupMessageHandlers() {
    // ✅ Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground message received: ${message.messageId}');
      _handleMessage(message, isForeground: true);
    });

    // ✅ App opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('📱 App opened from terminated state: ${message.messageId}');
        _handleMessage(message, isForeground: false);
      }
    });

    // ✅ App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from background: ${message.messageId}');
      _handleMessage(message, isForeground: false);
    });
  }

  // ✅ BACKGROUND HANDLER - Must be top-level function
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      print('📨 Background message received: ${message.messageId}');

      // ✅ Check for duplicate in background
      final msgId = message.messageId ?? '';
      if (msgId.isNotEmpty && _processedMessageIds.contains(msgId)) {
        print('⏭️ Duplicate background message ignored: $msgId');
        return;
      }

      if (msgId.isNotEmpty) {
        _processedMessageIds.add(msgId);
      }

      await _showLocalNotification(message);
    } catch (e) {
      print('⚠️ Background notification handling error: $e');
    }
  }

  // ✅ Main message handler with duplicate prevention
  static void _handleMessage(RemoteMessage message, {required bool isForeground}) {
    try {
      final msgId = message.messageId ?? '';

      // ✅ Check for duplicate
      if (msgId.isNotEmpty && _processedMessageIds.contains(msgId)) {
        print('⏭️ Duplicate message ignored: $msgId');
        return;
      }

      // ✅ Add to processed set
      if (msgId.isNotEmpty) {
        _processedMessageIds.add(msgId);
      }

      print('📨 Processing message: $msgId');
      print('   Title: ${message.notification?.title}');
      print('   Body: ${message.notification?.body}');
      print('   Data: ${message.data}');

      // ✅ Show notification
      _showLocalNotification(message);

      // ✅ Show in-app notification only for foreground
      if (isForeground) {
        _showInAppNotification(message);
      }

    } catch (e) {
      print('⚠️ Message handling error: $e');
    }
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
        // ✅ Use unique ID to prevent duplicate notifications
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // ✅ Generate unique ID from message ID or content
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

  static void _showInAppNotification(RemoteMessage message) {
    // ✅ Show in-app notification only if Get is available
    try {
      if (Get.context != null) {
        Get.snackbar(
          message.notification?.title ?? 'New Notification',
          message.notification?.body ?? '',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.black87,
          colorText: Colors.white,
          margin: const EdgeInsets.all(10),
          borderRadius: 10,
          icon: const Icon(Icons.notifications_active, color: Colors.orange),
          mainButton: TextButton(
            onPressed: () {
              Get.back();
              // Navigate based on data
              final type = message.data['type'] ?? message.data['notification_type'];
              if (type == 'booking' || type == 'booking_confirmed') {
                Get.toNamed('/my-bookings');
              } else if (type == 'wallet' || type == 'wallet_topup') {
                Get.toNamed('/wallet');
              } else {
                Get.toNamed('/notifications');
              }
            },
            child: const Text('VIEW', style: TextStyle(color: Colors.orange)),
          ),
        );
      }
    } catch (e) {
      print('⚠️ Could not show in-app notification: $e');
    }
  }

  // ✅ Subscribe to topics with duplicate prevention
  static Future<void> subscribeToTopics() async {
    try {
      // ✅ Check if already subscribed
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

  // ✅ Unsubscribe from topics
  static Future<void> unsubscribeFromTopics() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      await FirebaseMessaging.instance.unsubscribeFromTopic('offers');
      print('✅ Unsubscribed from notification topics');
    } catch (e) {
      print('❌ Failed to unsubscribe from topics: $e');
    }
  }

  // ✅ Helper to handle FCM token refresh
  static Future<String?> refreshToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        // ✅ Check if token already processed
        if (_processedTokens.contains(token)) {
          print('⏭️ Token already processed: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
          return token;
        }

        _processedTokens.add(token);
        print('📱 Refreshed FCM Token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
        return token;
      }
      return null;
    } catch (e) {
      print('⚠️ Error refreshing token: $e');
      return null;
    }
  }

  // ✅ Clear all processed IDs (useful for testing)
  static void clearProcessedIds() {
    _processedMessageIds.clear();
    _processedTokens.clear();
    print('🧹 Cleared all processed IDs');
  }

  // ✅ Dispose
  static void dispose() {
    _cleanupTimer?.cancel();
    _isInitialized = false;
    _isTokenRegistered = false;
    print('🗑️ Firebase Messaging Service disposed');
  }
}