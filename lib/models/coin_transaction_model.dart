// models/coin_transaction_model.dart
import 'package:intl/intl.dart';

class CoinTransactionModel {
  final String referenceId;
  final String transactionType; // credit / debit
  final int amount;
  final int previousBalance;
  final int currentBalance;
  final String description;
  final String status;
  final Map<String, dynamic>? booking;
  final DateTime createdAt;
  final String userEmail;

  CoinTransactionModel({
    required this.referenceId,
    required this.transactionType,
    required this.amount,
    required this.previousBalance,
    required this.currentBalance,
    required this.description,
    required this.status,
    this.booking,
    required this.createdAt,
    required this.userEmail,
  });

  factory CoinTransactionModel.fromJson(Map<String, dynamic> json) {
    print('Parsing coin transaction: $json');

    // Handle different API response formats
    String refId = '';
    if (json['reference_id'] != null) {
      refId = json['reference_id'].toString();
    } else if (json['id'] != null) {
      refId = json['id'].toString();
    }

    String type = json['transaction_type']?.toString() ?? json['type']?.toString() ?? 'credit';
    int amt = 0;
    if (json['amount'] != null) {
      amt = json['amount'] is int ? json['amount'] : int.tryParse(json['amount'].toString()) ?? 0;
    } else if (json['coins'] != null) {
      amt = json['coins'] is int ? json['coins'] : int.tryParse(json['coins'].toString()) ?? 0;
    }

    int prevBal = 0;
    if (json['previous_balance'] != null) {
      prevBal = json['previous_balance'] is int ? json['previous_balance'] : int.tryParse(json['previous_balance'].toString()) ?? 0;
    }

    int currBal = 0;
    if (json['current_balance'] != null) {
      currBal = json['current_balance'] is int ? json['current_balance'] : int.tryParse(json['current_balance'].toString()) ?? 0;
    }

    String desc = json['description']?.toString() ?? '';
    if (desc.isEmpty && json['remark'] != null) {
      desc = json['remark'].toString();
    }

    String stat = json['status']?.toString() ?? 'success';

    // FIX: Parse date and convert to local time
    DateTime createdAt = DateTime.now();
    if (json['created_at'] != null) {
      createdAt = _parseAndConvertToLocal(json['created_at'].toString());
    } else if (json['createdAt'] != null) {
      createdAt = _parseAndConvertToLocal(json['createdAt'].toString());
    } else if (json['date'] != null) {
      createdAt = _parseAndConvertToLocal(json['date'].toString());
    } else if (json['timestamp'] != null) {
      createdAt = _parseAndConvertToLocal(json['timestamp'].toString());
    }

    String email = json['user_email']?.toString() ?? '';

    Map<String, dynamic>? bookingData;
    if (json['booking'] != null && json['booking'] is Map) {
      bookingData = Map<String, dynamic>.from(json['booking']);
    }

    return CoinTransactionModel(
      referenceId: refId,
      transactionType: type,
      amount: amt,
      previousBalance: prevBal,
      currentBalance: currBal,
      description: desc,
      status: stat,
      booking: bookingData,
      createdAt: createdAt,
      userEmail: email,
    );
  }

  // Helper method to parse date and convert to local time
  static DateTime _parseAndConvertToLocal(String dateStr) {
    try {
      // Try to parse ISO format (2024-01-15T10:30:00Z or 2024-01-15T10:30:00+05:30)
      DateTime utcTime = DateTime.parse(dateStr);

      // If the time is in UTC (ends with Z), convert to local
      if (dateStr.endsWith('Z')) {
        return utcTime.toLocal();
      }

      // Check if it has timezone offset
      if (dateStr.contains('+') || dateStr.contains('-') && dateStr.lastIndexOf('-') > 10) {
        // Already has timezone, convert to local
        return utcTime.toLocal();
      }

      // If no timezone info, assume it's UTC
      return utcTime.toLocal();
    } catch (e) {
      print('Error parsing date: $dateStr - $e');

      // Try alternative format: DD-MM-YYYY HH:MM:SS
      try {
        final parts = dateStr.split(' ');
        if (parts.length >= 2) {
          final dateParts = parts[0].split('-');
          final timeParts = parts[1].split(':');

          if (dateParts.length == 3 && timeParts.length >= 2) {
            int year = int.parse(dateParts[2]);
            int month = int.parse(dateParts[1]);
            int day = int.parse(dateParts[0]);
            int hour = int.parse(timeParts[0]);
            int minute = int.parse(timeParts[1]);
            int second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

            return DateTime(year, month, day, hour, minute, second);
          }
        }
      } catch (e2) {
        print('Alternative parsing failed: $e2');
      }

      return DateTime.now();
    }
  }

  bool get isCredit => transactionType.toLowerCase() == 'credit';
  bool get isSuccess => status.toLowerCase() == 'success';

  // Get formatted date time string
  String get formattedDateTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (dateOnly == today) {
      return 'Today, ${_formatTime(createdAt)}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, ${_formatTime(createdAt)}';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}, ${_formatTime(createdAt)}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Map<String, dynamic> toJson() {
    return {
      'reference_id': referenceId,
      'transaction_type': transactionType,
      'amount': amount,
      'previous_balance': previousBalance,
      'current_balance': currentBalance,
      'description': description,
      'status': status,
      'booking': booking,
      'created_at': createdAt.toIso8601String(),
      'user_email': userEmail,
    };
  }
}