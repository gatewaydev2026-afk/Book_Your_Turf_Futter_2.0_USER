// utils/helpers.dart - COMPLETE WITH ALL UTILITY FUNCTIONS

import 'dart:convert';
import 'package:flutter/material.dart';

// ==================== TIME FORMATTING ====================

String formatTo12Hour(String time24) {
  if (time24.isEmpty || time24 == 'null' || time24 == 'NULL') {
    return 'Not specified';
  }

  try {
    String cleanTime = time24;
    if (cleanTime.contains(':')) {
      final parts = cleanTime.split(':');
      if (parts.length >= 2) {
        String hourStr = parts[0];
        String minuteStr = parts[1];
        if (minuteStr.contains(',')) minuteStr = minuteStr.split(',').first;
        if (minuteStr.contains('.')) minuteStr = minuteStr.split('.').first;
        if (minuteStr.length > 2) minuteStr = minuteStr.substring(0, 2);
        cleanTime = '$hourStr:$minuteStr';
      }
    }

    final parts = cleanTime.split(':');
    if (parts.length < 2) return time24;

    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1].split(',').first.split('.').first);
    String period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  } catch (e) {
    return time24;
  }
}

String formatTo24Hour(String time12) {
  if (time12.isEmpty || time12 == 'null' || time12 == 'NULL') {
    return '00:00';
  }

  try {
    String cleanTime = time12.trim().toUpperCase();
    bool isPM = cleanTime.contains('PM');
    cleanTime = cleanTime.replaceAll(RegExp(r'[AP]M'), '').trim();

    final parts = cleanTime.split(':');
    if (parts.length < 2) return '00:00';

    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1].split(' ').first);

    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  } catch (e) {
    return '00:00';
  }
}

// ==================== DATE FORMATTING ====================

String formatDate(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}

String formatDateDisplay(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
}

String formatDateReadable(DateTime date) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

DateTime? parseDate(String dateStr) {
  if (dateStr.isEmpty) return null;

  try {
    String cleanDate = dateStr.trim();

    if (cleanDate.contains('-')) {
      final parts = cleanDate.split('-');
      if (parts.length == 3) {
        int first = int.tryParse(parts[0]) ?? 0;
        int second = int.tryParse(parts[1]) ?? 0;
        int third = int.tryParse(parts[2]) ?? 0;

        // Check if it's YYYY-MM-DD or DD-MM-YYYY
        if (first > 31) {
          // YYYY-MM-DD format
          return DateTime(first, second, third);
        } else {
          // DD-MM-YYYY format
          return DateTime(third, second, first);
        }
      }
    }

    return DateTime.tryParse(cleanDate);
  } catch (e) {
    return null;
  }
}

bool isSameDay(DateTime? date1, DateTime? date2) {
  if (date1 == null || date2 == null) return false;
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

bool isDateAfter(DateTime? date, DateTime? reference) {
  if (date == null || reference == null) return false;
  return date.isAfter(reference);
}

// ==================== PRICE FORMATTING ====================

String formatPrice(double price) {
  // Round to 2 decimal places first
  double roundedPrice = double.parse(price.toStringAsFixed(2));
  if (roundedPrice == roundedPrice.toInt()) {
    return roundedPrice.toInt().toString();
  }
  String formatted = roundedPrice.toStringAsFixed(2);
  formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
  if (formatted.endsWith('.')) {
    formatted = formatted.substring(0, formatted.length - 1);
  }
  return formatted;
}

String formatPriceForApi(double price) {
  return price.toStringAsFixed(2);
}

double roundToTwoDecimals(double value) {
  return double.parse(value.toStringAsFixed(2));
}

// ==================== STRING VALIDATION ====================

bool isValidEmail(String email) {
  if (email.isEmpty) return false;
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

bool isValidPhone(String phone) {
  if (phone.isEmpty) return false;
  String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
  return cleanPhone.length >= 10 && cleanPhone.length <= 15;
}

bool isValidPassword(String password) {
  return password.length >= 6;
}

// ==================== GAME TYPE HELPERS ====================

String getGameTypeDisplay(String gameType) {
  if (gameType.isEmpty) return "Sports";
  final type = gameType.toLowerCase();
  if (type.contains('football') && type.contains('cricket')) return "Football & Cricket";
  if (type.contains('football')) return "Football";
  if (type.contains('cricket')) return "Cricket";
  if (type.contains('badminton')) return "Badminton";
  if (type.contains('pickleball') || type.contains('pickle ball')) return "Pickleball";
  if (type.contains('basketball')) return "Basketball";
  if (type.contains('volleyball')) return "Volleyball";
  if (type.contains('tennis')) return "Tennis";
  return gameType;
}

Color getSportColor(String gameType) {
  final type = gameType.toLowerCase();
  if (type.contains('football')) return Colors.green.shade700;
  if (type.contains('cricket')) return Colors.green.shade700;
  if (type.contains('badminton')) return Colors.deepPurple.shade700;
  if (type.contains('pickleball') || type.contains('pickle ball')) return Colors.orange.shade700;
  if (type.contains('basketball')) return Colors.orange.shade700;
  if (type.contains('volleyball')) return Colors.blue.shade700;
  if (type.contains('tennis')) return Colors.lime.shade700;
  return Colors.green.shade700;
}

IconData getSportIcon(String gameType) {
  final type = gameType.toLowerCase();
  if (type.contains('football')) return Icons.sports_soccer;
  if (type.contains('cricket')) return Icons.sports_cricket;
  if (type.contains('badminton')) return Icons.sports_tennis;
  if (type.contains('pickleball') || type.contains('pickle ball')) return Icons.sports_tennis;
  if (type.contains('basketball')) return Icons.sports_basketball;
  if (type.contains('volleyball')) return Icons.sports_volleyball;
  if (type.contains('tennis')) return Icons.sports_tennis;
  return Icons.sports;
}

String getSportImage(String gameType) {
  final type = gameType.toLowerCase();
  if (type.contains('football') || type.contains('cricket')) {
    return 'assets/sports/human_cricket.png';
  }
  if (type.contains('badminton')) {
    return 'assets/sports/human_badminton.png';
  }
  if (type.contains('pickleball') || type.contains('pickle ball')) {
    return 'assets/sports/human_pickle.png';
  }
  return 'assets/sports/all .png';
}

bool isCricketOrFootball(String gameType) {
  final type = gameType.toLowerCase();
  return type.contains('cricket') || type.contains('football');
}

// ==================== SLOT HELPERS ====================

bool isNextDaySlot(String startTime) {
  if (startTime.isEmpty) return false;
  try {
    final parts = startTime.split(':');
    if (parts.isNotEmpty) {
      int hour = int.parse(parts[0]);
      return hour >= 0 && hour < 6;
    }
  } catch (e) {
    return false;
  }
  return false;
}

List<Map<String, dynamic>> sortSlots(List<Map<String, dynamic>> slots) {
  final List<Map<String, dynamic>> regularSlots = [];
  final List<Map<String, dynamic>> nextDaySlots = [];

  for (var slot in slots) {
    final startTime = slot['start_time'] ?? '';
    final isNextDay = isNextDaySlot(startTime);
    if (isNextDay) {
      nextDaySlots.add(slot);
    } else {
      regularSlots.add(slot);
    }
  }
  regularSlots.sort((a, b) {
    final timeA = a['start_time'] ?? '00:00';
    final timeB = b['start_time'] ?? '00:00';
    return timeA.compareTo(timeB);
  });
  nextDaySlots.sort((a, b) {
    final timeA = a['start_time'] ?? '00:00';
    final timeB = b['start_time'] ?? '00:00';
    return timeA.compareTo(timeB);
  });
  return [...regularSlots, ...nextDaySlots];
}

// ==================== NOTIFICATION HELPERS ====================

String getNotificationTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'booking':
    case 'booking_confirmed':
      return '📅';
    case 'wallet':
    case 'wallet_topup':
      return '💰';
    case 'coins':
    case 'coins_earned':
      return '🪙';
    case 'offer':
    case 'promotion':
      return '🎉';
    default:
      return '📱';
  }
}

Color getNotificationTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'booking':
    case 'booking_confirmed':
      return Colors.blue;
    case 'wallet':
    case 'wallet_topup':
      return Colors.green;
    case 'coins':
    case 'coins_earned':
      return Colors.orange;
    case 'offer':
    case 'promotion':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}

// ==================== JSON HELPERS ====================

bool isValidJson(String jsonString) {
  try {
    jsonDecode(jsonString);
    return true;
  } catch (e) {
    return false;
  }
}

Map<String, dynamic> safeJsonDecode(String jsonString) {
  try {
    return jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (e) {
    return {};
  }
}

// ==================== DEVICE HELPERS ====================

String generateDeviceId() {
  return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().hashCode.abs()}';
}

// ==================== PAYMENT HELPERS ====================

String getPaymentTypeDisplay(String type) {
  switch (type.toLowerCase()) {
    case 'advance':
      return 'Advance Payment';
    case 'full':
      return 'Full Payment';
    case 'wallet':
      return 'Wallet Payment';
    default:
      return type;
  }
}

String getPaymentStatusDisplay(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Pending';
    case 'advance paid':
    case 'advance':
      return 'Advance Paid';
    case 'fully paid':
    case 'full':
      return 'Fully Paid';
    case 'failed':
      return 'Failed';
    case 'refunded':
      return 'Refunded';
    default:
      return status;
  }
}

Color getPaymentStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'advance paid':
    case 'advance':
      return Colors.blue;
    case 'fully paid':
    case 'full':
      return Colors.green;
    case 'failed':
      return Colors.red;
    case 'refunded':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

// ==================== BOOKING HELPERS ====================

String getBookingStatusDisplay(String status) {
  switch (status.toLowerCase()) {
    case 'upcoming':
      return 'Upcoming';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'today':
      return 'Today';
    default:
      return status;
  }
}

Color getBookingStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'upcoming':
      return Colors.blue;
    case 'completed':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    case 'today':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

// ==================== DISTANCE HELPERS ====================

String formatDistance(double distanceInKm) {
  if (distanceInKm < 1) {
    return '${(distanceInKm * 1000).toInt()} m away';
  }
  return '${distanceInKm.toStringAsFixed(1)} km away';
}

// ==================== TRUNCATE HELPERS ====================

String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

// ==================== RATING HELPERS ====================

String getRatingDisplay(double rating) {
  if (rating == 0) return 'No ratings';
  return rating.toStringAsFixed(1);
}

// ==================== CAPITALIZATION ====================

String capitalizeWords(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

// ==================== IMAGE HELPERS ====================

String getImageUrl(String url, {int? width, int? height}) {
  if (url.isEmpty) return '';
  // Add image optimization parameters if needed
  if (url.contains('?')) {
    return url;
  }
  return url;
}