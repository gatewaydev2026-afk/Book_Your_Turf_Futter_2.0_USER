// firebase_messaging_service.dart - COMPLETE FIXED

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseMessagingService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
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

      // Get FCM token with error handling
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          print('📱 FCM Token: $token');
        } else {
          print('⚠️ FCM Token is null');
        }
      } catch (e) {
        print('⚠️ Error getting FCM token: $e');
      }

      // ✅ Setup background handler with error handling
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        print('⚠️ Error setting up background handler: $e');
      }

      print('✅ Firebase Messaging initialized');
    } catch (e) {
      print('❌ Firebase Messaging initialization error: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    try {
      print('📨 Handling background message: ${message.messageId}');
      await _showLocalNotification(message);
    } catch (e) {
      // ✅ Catch and log error, don't crash
      print('⚠️ Background notification handling error: $e');
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
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecond,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
        details,
        payload: message.data.toString(),
      );
    } catch (e) {
      print('⚠️ Error showing local notification: $e');
    }
  }

  static Future<void> subscribeToTopics() async {
    try {
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

  // ✅ Helper to handle FCM token refresh
  static Future<String?> refreshToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      print('📱 Refreshed FCM Token: $token');
      return token;
    } catch (e) {
      print('⚠️ Error refreshing token: $e');
      return null;
    }
  }
}