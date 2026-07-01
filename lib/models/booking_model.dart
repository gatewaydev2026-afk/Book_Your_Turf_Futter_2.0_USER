// models/booking_model.dart
import '../utils/helpers.dart';

class BookingModel {
  final int id;
  final String bookingId;
  final String turfName;
  final String gameType;
  final int courtNumber;
  final String bookingType;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final String paymentStatus;
  final bool isCancelled;
  final List<Map<String, dynamic>> slots;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.bookingId,
    required this.turfName,
    required this.gameType,
    required this.courtNumber,
    required this.bookingType,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    required this.isCancelled,
    required this.slots,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> slotsList = [];
    if (json['slots'] != null && json['slots'] is List) {
      slotsList = List<Map<String, dynamic>>.from(json['slots']).map((slot) {
        // Ensure is_next_day is properly parsed
        return {
          'date': slot['date'] ?? '',
          'start_time': slot['start_time'] ?? '',
          'end_time': slot['end_time'] ?? '',
          'price': slot['price']?.toString() ?? '0',
          'is_next_day':
          slot['is_next_day'] ?? false, // IMPORTANT: Parse this field
        };
      }).toList();
    }

    return BookingModel(
      id: json['id'] ?? 0,
      bookingId: json['booking_id'] ?? '',
      turfName: json['turf_name'] ?? '',
      gameType: json['game_type'] ?? '',
      courtNumber: json['court_number'] ?? 1,
      bookingType: json['booking_type'] ?? 'Online',
      totalAmount:
      double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0,
      pendingAmount:
      double.tryParse(json['pending_amount']?.toString() ?? '0') ?? 0,
      paymentStatus: json['payment_status'] ?? 'Pending',
      isCancelled: json['is_cancelled'] ?? false,
      slots: slotsList,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Parse slot date — handles both DD-MM-YYYY and YYYY-MM-DD
  DateTime? _parseSlotDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      // ISO format: 2026-07-01
      final iso = DateTime.tryParse(dateStr);
      if (iso != null) return iso;

      // DD-MM-YYYY format: 01-07-2026
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final first = int.tryParse(parts[0]) ?? 0;
        final second = int.tryParse(parts[1]) ?? 0;
        final third = int.tryParse(parts[2]) ?? 0;
        if (first > 31) {
          // YYYY-MM-DD (fallback)
          return DateTime(first, second, third);
        } else {
          // DD-MM-YYYY
          return DateTime(third, second, first);
        }
      }
    } catch (_) {}
    return null;
  }

  String get status {
    if (isCancelled) return 'cancelled';
    if (slots.isEmpty) return 'upcoming';
    final now = DateTime.now();
    bool allPast = true;
    for (var slot in slots) {
      final slotDate = _parseSlotDate(slot['date'] ?? '');
      if (slotDate == null) continue;
      // Compare against end of slot day (23:59:59) so today's bookings
      // are never treated as completed until the day is fully over.
      final endOfSlotDay = DateTime(slotDate.year, slotDate.month, slotDate.day, 23, 59, 59);
      if (endOfSlotDay.isAfter(now)) {
        allPast = false;
        break;
      }
    }
    return allPast ? 'completed' : 'upcoming';
  }

  String get formattedDate {
    DateTime? date;

    if (slots.isNotEmpty && (slots.first['date'] ?? '').isNotEmpty) {
      date = _parseSlotDate(slots.first['date']);
    }

    date ??= createdAt;

    return "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}";
  }

  String get slotDisplay {
    if (slots.isEmpty) return "No slots";
    return slots
        .map((s) {
      final start = formatTo12Hour(s['start_time'] ?? '');
      final end = formatTo12Hour(s['end_time'] ?? '');
      return "$start - $end";
    })
        .join(", ");
  }

  double get remainingAmount => totalAmount - paidAmount;
  bool get isCompleted =>
      status == 'completed' && paymentStatus == 'Fully Paid';
  bool get isFullyPaid => paymentStatus == 'Fully Paid' && !isCancelled;
}