// views/notification_view.dart - FIXED duplicate refresh

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';

class NotificationScreen extends StatelessWidget {
   NotificationScreen({Key? key}) : super(key: key);

  // ✅ DUPLICATE REFRESH PREVENTION
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final NotificationService notificationService = Get.find<NotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
        elevation: 0,
        actions: [
          Obx(() {
            if (notificationService.notifications.isEmpty) return const SizedBox();
            return IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                notificationService.clearAllNotifications();
                Get.snackbar('Cleared', 'All notifications cleared');
              },
            );
          }),
        ],
      ),
      body: Obx(() {
        if (notificationService.isLoading.value && notificationService.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (notificationService.notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text('No notifications yet'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // ✅ Prevent duplicate refreshes
            if (_isRefreshing) {
              print('⏭️ Notification refresh already in progress');
              return;
            }
            _isRefreshing = true;
            try {
              await notificationService.refreshFromBackend();
            } finally {
              _isRefreshing = false;
            }
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notificationService.notifications.length,
            itemBuilder: (context, index) {
              final notification = notificationService.notifications[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notification.type.contains('booking')
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    child: Icon(
                      notification.type.contains('booking') ? Icons.sports_soccer : Icons.currency_rupee,
                      color: notification.type.contains('booking') ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.body),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification.sentAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: !notification.isRead
                      ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  )
                      : null,
                  onTap: () {
                    if (!notification.isRead) {
                      notificationService.markAsRead(notification.id);
                    }
                  },
                ),
              );
            },
          ),
        );
      }),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}