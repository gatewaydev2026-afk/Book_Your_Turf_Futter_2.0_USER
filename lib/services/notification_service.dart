// services/notification_service.dart - FIXED duplicate API calls
// ✅ FIX (Sep 2026): notification opened from tray no longer shows a SECOND
//    tray notification; parallel history fetches share one request.

import 'dart:async';
import 'dart:convert';
import 'package:book_your_turf/config/app_config.dart';
import 'package:book_your_turf/services/cache_manager.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/shared_prefs_helper.dart';
import '../models/notification_model.dart';
import '../routes/app_routes.dart';
import '../view_models/main_page_view_model.dart';
import '../view_models/wallet_view_model.dart';
import '../view_models/coin_view_model.dart';
import '../views/wallet_transactions_view.dart';
import '../views/coin_transactions_view.dart';

class NotificationService extends GetxService {
  final notifications = <NotificationItem>[].obs;
  final isLoading = false.obs;
  final unreadCount = 0.obs;

  // Pagination state
  final hasMore = true.obs;
  var currentOffset = 0;
  var totalCount = 0;
  static const int pageSize = AppConfig.pageSize;

  // ✅ PREVENT DUPLICATE CALLS
  static bool _isFetching = false;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = AppConfig.notificationCacheDuration;

  // ✅ TRACK RECEIVED NOTIFICATIONS TO PREVENT DUPLICATES
  static final Set<String> _processedNotificationIds = {};
  static const _cleanupInterval = AppConfig.notificationCleanupInterval;
  static DateTime? _lastCleanupTime;

  // ✅ DEBOUNCE FOR REFRESH
  Timer? _refreshDebounceTimer;
  static const _debounceDuration = AppConfig.notificationDebounceDuration;

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
    _startCleanupTimer();
  }

  void _startCleanupTimer() {
    Timer.periodic(_cleanupInterval, (timer) {
      _cleanupProcessedIds();
    });
  }

  void _cleanupProcessedIds() {
    final now = DateTime.now();
    if (_lastCleanupTime != null && now.difference(_lastCleanupTime!) < _cleanupInterval) {
      return;
    }
    _lastCleanupTime = now;

    if (_processedNotificationIds.length > AppConfig.maxProcessedNotificationIds) {
      final ids = _processedNotificationIds.toList();
      final toRemove = ids.sublist(0, ids.length - AppConfig.maxProcessedNotificationIds);
      for (var id in toRemove) {
        _processedNotificationIds.remove(id);
      }
      print('🧹 Cleaned ${toRemove.length} old notification IDs');
    }
  }

  @override
  void onClose() {
    _refreshDebounceTimer?.cancel();
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

  // ✅ FIX: '/my-bookings', '/wallet', '/coins' were not registered routes →
  //    tapping a notification opened an unknown route. Now uses real screens.
  void _handleNavigation(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notification_type'] ?? '').toString();
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) return;

    if (type == 'booking' || type == 'booking_confirmed') {
      if (Get.currentRoute != AppRoutes.mainPage) {
        Get.offAllNamed(AppRoutes.mainPage);
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (Get.isRegistered<MainPageViewModel>()) {
          Get.find<MainPageViewModel>().changeTab(1);
        }
      });
    } else if (type == 'wallet' || type == 'wallet_topup') {
      if (Get.isRegistered<WalletViewModel>()) {
        Get.find<WalletViewModel>().loadWalletData(forceRefresh: true);
      }
      Get.to(() => const WalletTransactionsView());
    } else if (type == 'coins' || type == 'coins_earned') {
      if (Get.isRegistered<CoinViewModel>()) {
        Get.find<CoinViewModel>().loadCoinData();
      }
      Get.to(() => const CoinTransactionsView());
    } else if (Get.currentRoute != AppRoutes.notifications) {
      Get.toNamed(AppRoutes.notifications);
    }
  }

  // ==================== SHOW SYSTEM NOTIFICATION ====================

  Future<void> _showSystemNotification({
    required String title,
    required String body,
    String? payload,
    String? notificationId,
  }) async {
    if (!_isInitialized) await _initializeLocalNotifications();

    int id;
    if (notificationId != null) {
      id = notificationId.hashCode;
    } else {
      id = '$title-$body'.hashCode;
    }
    id = id.abs();

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
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );

    print('✅ System notification shown in tray: $title (ID: $id)');
  }

  // ==================== FCM HANDLER ====================

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground notification received');
      _handleIncomingNotification(message, showInTray: true);
    });

    // Opened from the tray → Android already showed it; just record + navigate
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('📱 App opened from terminated state');
        _handleIncomingNotification(message, showInTray: false);
        _navigateLater(message.data);
      }
    }).catchError((e) {
      print('⚠️ getInitialMessage error: $e');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from background');
      _handleIncomingNotification(message, showInTray: false);
      _navigateLater(message.data);
    });
  }

  void _navigateLater(Map<String, dynamic> data) {
    // wait until the first screens are on the navigator
    Future.delayed(const Duration(milliseconds: 1500), () {
      try {
        _handleNavigation(data);
      } catch (e) {
        print('⚠️ Notification navigation error: $e');
      }
    });
  }

  void _handleIncomingNotification(RemoteMessage message, {bool showInTray = true}) {
    try {
      final data = message.data;
      final notification = message.notification;

      final msgId = message.messageId ?? '${DateTime.now().millisecondsSinceEpoch}';

      if (_processedNotificationIds.contains(msgId)) {
        print('⏭️ Duplicate notification ignored: $msgId');
        return;
      }

      _processedNotificationIds.add(msgId);
      print('✅ Processing notification: $msgId');

      final notificationItem = NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch,
        type: data['type'] ?? data['notification_type'] ?? 'general',
        title: notification?.title ?? data['title'] ?? 'New Notification',
        body: notification?.body ?? data['body'] ?? '',
        sentAt: DateTime.now(),
        isRead: false,
      );

      final isDuplicate = notifications.any((n) =>
      n.title == notificationItem.title &&
          n.body == notificationItem.body &&
          DateTime.now().difference(n.sentAt).inSeconds < 5
      );

      if (isDuplicate) {
        print('⏭️ Duplicate notification (same content) ignored');
        return;
      }

      notifications.insert(0, notificationItem);
      _updateUnreadCount();
      _saveNotificationsToCache();

      _notificationController.add(notificationItem);

      if (showInTray) {
        _showSystemNotification(
          title: notificationItem.title,
          body: notificationItem.body,
          payload: jsonEncode(data),
          notificationId: msgId,
        );
      }


      print('✅ Notification saved: ${notificationItem.title}');

      // ✅ No API call here: the push already contains the notification and it
      //    was added to the list above. Re-fetching the whole list on every push
      //    meant one extra API call per notification.

    } catch (e) {
      print('❌ Error handling notification: $e');
    }
  }




  static final Map<String, Future<List<NotificationItem>>> _inFlightFetches = {};

  Future<List<NotificationItem>> fetchFromBackend({
    int offset = 0,
    int limit = 20,
    bool forceRefresh = false,
  }) {
    // ✅ Same page already being fetched → share that request
    final key = '$offset-$limit';
    final running = _inFlightFetches[key];
    if (running != null) {
      print('⏳ Notifications page $key already loading - sharing request');
      return running;
    }
    final f = _fetchFromBackendInternal(offset: offset, limit: limit, forceRefresh: forceRefresh);
    _inFlightFetches[key] = f;
    f.whenComplete(() => _inFlightFetches.remove(key));
    return f;
  }

  Future<List<NotificationItem>> _fetchFromBackendInternal({
    int offset = 0,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final token = SharedPrefsHelper.getToken();
    if (token == null || token.isEmpty) {
      return [];
    }


    if (!forceRefresh && _lastFetchTime != null) {
      final age = DateTime.now().difference(_lastFetchTime!);
      if (age < _cacheDuration && notifications.isNotEmpty) {
        print('⏭️ Notifications cached (${age.inSeconds}s old) - using cache');
        return notifications.toList();
      }
    }

    _isFetching = true;
    print('📡 Fetching notifications from API...');

    try {
      final url = Uri.parse(
          '${AppConfig.apiBaseUrl}/user/notifications/history/?offset=$offset&limit=$limit'
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

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
            // ✅ tryParse: a bad date from the server must not crash the list
            sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? '') ?? DateTime.now(),
            isRead: json['is_read'] ?? false,
          );
        }).toList();

        _lastFetchTime = DateTime.now();

        if (Get.isRegistered<CacheManager>()) {
          Get.find<CacheManager>().setCachedNotifications(fetchedNotifications);
        }

        print('✅ Fetched ${fetchedNotifications.length} notifications from backend (total: $totalCount)');
        return fetchedNotifications;
      } else {
        return [];
      }
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return [];
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refreshFromBackend() async {
    if (isLoading.value) {
      print('⏭️ Notifications refresh already in progress');
      return;
    }

    isLoading.value = true;
    try {
      final fetched = await fetchFromBackend(offset: 0, limit: pageSize, forceRefresh: true);

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
        Uri.parse('${AppConfig.apiBaseUrl}/user/notifications/mark-read/$notificationId/'),
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
        Uri.parse('${AppConfig.apiBaseUrl}/user/notifications/mark-all-read/'),
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
        Uri.parse('${AppConfig.apiBaseUrl}/user/device-token/'),
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

  static void resetCache() {
    _isFetching = false;
    _lastFetchTime = null;
    _processedNotificationIds.clear();
    _lastCleanupTime = null;
    print('🔄 Notification cache reset');
  }
}