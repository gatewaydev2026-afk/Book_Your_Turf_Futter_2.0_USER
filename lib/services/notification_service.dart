// services/notification_service.dart - COMPLETE USER APP VERSION

import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/shared_prefs_helper.dart';
import '../models/notification_model.dart';

class NotificationService extends GetxService {
  final notifications = <NotificationItem>[].obs;
  final isLoading = false.obs;
  final unreadCount = 0.obs;

  // Pagination state
  final hasMore = true.obs;
  var currentOffset = 0;
  var totalCount = 0;
  static const int pageSize = 20;

  // ✅ STREAM FOR REAL-TIME NOTIFICATIONS
  final _notificationController = StreamController<NotificationItem>.broadcast();
  Stream<NotificationItem> get onNotificationReceived => _notificationController.stream;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    _initializeLocalNotifications();
    _setupForegroundHandler();
    _loadCachedNotifications();
  }

  @override
  void onClose() {
    _notificationController.close();
    super.onClose();
  }

  // ==================== LOCAL NOTIFICATIONS INITIALIZATION ====================

  Future<void> _initializeLocalNotifications() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _isInitialized = true;
    print('✅ Local notifications initialized');
  }

  void _onNotificationTap(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNavigation(data);
      } catch (e) {
        print('Error parsing payload: $e');
      }
    }
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'booking' || type == 'booking_confirmed') {
      Get.toNamed('/my-bookings');
    } else if (type == 'wallet' || type == 'wallet_topup') {
      Get.toNamed('/wallet');
    } else if (type == 'coins' || type == 'coins_earned') {
      Get.toNamed('/coins');
    }
  }

  // ==================== SHOW SYSTEM NOTIFICATION ====================

  Future<void> _showSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await _initializeLocalNotifications();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'user_channel',
      'Book Your Turf',
      channelDescription: 'Notifications for bookings, wallet and coins',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      channelShowBadge: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.hashCode,
      title,
      body,
      platformDetails,
      payload: payload,
    );

    print('✅ System notification shown in tray: $title');
  }

  // ==================== FCM HANDLER ====================

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground notification received');
      _handleIncomingNotification(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('📱 App opened from terminated state');
        _handleIncomingNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from background');
      _handleIncomingNotification(message);
    });
  }

  void _handleIncomingNotification(RemoteMessage message) {
    try {
      final data = message.data;
      final notification = message.notification;

      final notificationItem = NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch,
        type: data['type'] ?? data['notification_type'] ?? 'general',
        title: notification?.title ?? data['title'] ?? 'New Notification',
        body: notification?.body ?? data['body'] ?? '',
        sentAt: DateTime.now(),
        isRead: false,
      );

      // Add to local list
      notifications.insert(0, notificationItem);
      _updateUnreadCount();
      _saveNotificationsToCache();

      // ✅ ADD THIS LINE - Broadcast to stream listeners
      _notificationController.add(notificationItem);

      // Show system notification
      _showSystemNotification(
        title: notificationItem.title,
        body: notificationItem.body,
        payload: jsonEncode(data),
      );

      // Show in-app snackbar for foreground
      if (Get.context != null) {
        _showInAppSnackbar(notificationItem);
      }

      print('✅ Notification saved: ${notificationItem.title}');

      // Refresh from backend
      refreshFromBackend();

    } catch (e) {
      print('❌ Error handling notification: $e');
    }
  }

  void _showInAppSnackbar(NotificationItem notification) {
    try {
      Get.snackbar(
        notification.title,
        notification.body,
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
            Get.toNamed('/notifications');
          },
          child: const Text('VIEW', style: TextStyle(color: Colors.orange)),
        ),
      );
    } catch (e) {
      print('⚠️ Could not show snackbar: $e');
    }
  }

  // ==================== BACKEND API METHODS ====================

  Future<List<NotificationItem>> fetchFromBackend({
    int offset = 0,
    int limit = 20,
  }) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      return [];
    }

    try {
      final url = Uri.parse(
          'https://backend.arcmedialabs.in/api/user/notifications/history/?offset=$offset&limit=$limit'
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notificationsData = data['data']?['notifications'] ?? data['notifications'] ?? [];
        totalCount = data['data']?['total'] ?? data['total'] ?? 0;

        final fetchedNotifications = notificationsData.map<NotificationItem>((json) {
          return NotificationItem(
            id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
            type: json['notification_type'] ?? json['type'] ?? 'general',
            title: json['title'] ?? '',
            body: json['body'] ?? json['message'] ?? '',
            sentAt: json['sent_at'] != null
                ? DateTime.parse(json['sent_at'])
                : DateTime.now(),
            isRead: json['is_read'] ?? false,
          );
        }).toList();

        print('✅ Fetched ${fetchedNotifications.length} notifications from backend (total: $totalCount)');
        return fetchedNotifications;
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> refreshFromBackend() async {
    isLoading.value = true;
    try {
      final fetched = await fetchFromBackend(offset: 0, limit: pageSize);

      final existingIds = notifications.map((n) => n.id).toSet();
      final newNotifications = fetched.where((n) => !existingIds.contains(n.id)).toList();

      if (newNotifications.isNotEmpty) {
        notifications.insertAll(0, newNotifications);
        if (notifications.length > 100) {
          notifications.removeRange(100, notifications.length);
        }
        await _saveNotificationsToCache();
      }

      hasMore.value = fetched.length >= pageSize;
      currentOffset = fetched.length;
      _updateUnreadCount();
    } catch (e) {
      print('❌ Refresh error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || !hasMore.value) return;

    isLoading.value = true;
    try {
      final fetched = await fetchFromBackend(offset: currentOffset, limit: pageSize);

      final existingIds = notifications.map((n) => n.id).toSet();
      final newNotifications = fetched.where((n) => !existingIds.contains(n.id)).toList();

      if (newNotifications.isNotEmpty) {
        notifications.addAll(newNotifications);
        await _saveNotificationsToCache();
      }

      hasMore.value = fetched.length >= pageSize;
      currentOffset += fetched.length;
    } catch (e) {
      print('❌ Load more error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsReadOnBackend(int notificationId) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://backend.arcmedialabs.in/api/user/notifications/mark-read/$notificationId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('✅ Marked as read on backend: $notificationId');
      }
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }

  Future<void> markAllAsReadOnBackend() async {
    final token = SharedPrefsHelper.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://backend.arcmedialabs.in/api/user/notifications/mark-all-read/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('✅ All marked as read on backend');
        for (int i = 0; i < notifications.length; i++) {
          if (!notifications[i].isRead) {
            notifications[i] = notifications[i].copyWith(isRead: true);
          }
        }
        _updateUnreadCount();
        await _saveNotificationsToCache();
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  // ==================== TOKEN REGISTRATION ====================

  Future<bool> registerDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        print('❌ No FCM token');
        return false;
      }

      final jwtToken = SharedPrefsHelper.getToken();
      if (jwtToken == null) {
        print('❌ No JWT token');
        return false;
      }

      print('📱 Registering token: $token');

      final response = await http.post(
        Uri.parse('https://backend.arcmedialabs.in/api/user/device-token/'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Token registered');
        await SharedPrefsHelper.setLastTokenRegistration(DateTime.now());
        return true;
      } else {
        print('❌ Registration failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  // ✅ UPDATE UNREAD COUNT - Public method
  void updateUnreadCount() {
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    unreadCount.value = notifications.where((n) => !n.isRead).length;
  }

  // ==================== CACHE METHODS ====================

  Future<void> _saveNotificationsToCache() async {
    try {
      final jsonList = notifications.map((n) => n.toJson()).toList();
      await SharedPrefsHelper.setNotificationsCache(jsonEncode(jsonList));
    } catch (e) {
      print('⚠️ Failed to save notifications to cache: $e');
    }
  }

  Future<void> _loadCachedNotifications() async {
    try {
      final cachedData = await SharedPrefsHelper.getNotificationsCache();
      if (cachedData != null && cachedData.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        notifications.value = jsonList
            .map((json) => NotificationItem.fromJson(json))
            .toList();
        _updateUnreadCount();
        print('📦 Loaded ${notifications.length} notifications from cache');
      }
    } catch (e) {
      print('⚠️ Failed to load cached notifications: $e');
    }
  }

  // ==================== CRUD OPERATIONS ====================

  Future<void> markAsRead(int notificationId) async {
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !notifications[index].isRead) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      _updateUnreadCount();
      await _saveNotificationsToCache();
      await markAsReadOnBackend(notificationId);
      print('✅ Marked as read: $notificationId');
    }
  }

  Future<void> markAllAsRead() async {
    await markAllAsReadOnBackend();
  }

  Future<void> clearAllNotifications() async {
    notifications.clear();
    _updateUnreadCount();
    await _saveNotificationsToCache();
    print('🗑️ All cleared');
  }

  Future<void> deleteNotification(int notificationId) async {
    notifications.removeWhere((n) => n.id == notificationId);
    _updateUnreadCount();
    await _saveNotificationsToCache();
    print('🗑️ Deleted: $notificationId');
  }
}