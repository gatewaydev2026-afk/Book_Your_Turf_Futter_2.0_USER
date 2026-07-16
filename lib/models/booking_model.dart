// models/booking_model.dart
import '../utils/helpers.dart';

class BookingModel {
  final int id;
  final String bookingId;
  final String turfName;
  final String gameType;
  final int courtNumber;
  final String bookingType;

  // Amount fields - IMPORTANT: Use discounted_total_amount for payments
  final double totalAmount;              // Original (undiscounted) total
  final double discountedTotalAmount;    // Actual amount to pay
  final double paidAmount;
  final double pendingAmount;
  final String paymentStatus;

  // Discount details
  final int? adminDiscountId;
  final double? adminDiscountAmount;
  final int? partnerDiscountId;
  final double? partnerDiscountAmount;
  final double? totalDiscountAmount;

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
    required this.discountedTotalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    this.adminDiscountId,
    this.adminDiscountAmount,
    this.partnerDiscountId,
    this.partnerDiscountAmount,
    this.totalDiscountAmount,
    required this.isCancelled,
    required this.slots,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> slotsList = [];
    if (json['slots'] != null && json['slots'] is List) {
      slotsList = List<Map<String, dynamic>>.from(json['slots']).map((slot) {
        return {
          'date': slot['date'] ?? '',
          'start_time': slot['start_time'] ?? '',
          'end_time': slot['end_time'] ?? '',
          'price': slot['price']?.toString() ?? '0',
          'is_next_day': slot['is_next_day'] ?? false,
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

      // Parse amounts - handle string/num conversions
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      discountedTotalAmount: double.tryParse(json['discounted_total_amount']?.toString() ?? '0') ?? 0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0,
      pendingAmount: double.tryParse(json['pending_amount']?.toString() ?? '0') ?? 0,
      paymentStatus: json['payment_status'] ?? 'Pending',

      // Discount details
      adminDiscountId: json['admin_discount_id'],
      adminDiscountAmount: double.tryParse(json['admin_discount_amount']?.toString() ?? '0'),
      partnerDiscountId: json['partner_discount_id'],
      partnerDiscountAmount: double.tryParse(json['partner_discount_amount']?.toString() ?? '0'),
      totalDiscountAmount: double.tryParse(json['total_discount_amount']?.toString() ?? '0'),

      isCancelled: json['is_cancelled'] ?? false,
      slots: slotsList,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Helper: Check if discount was applied
  bool get hasDiscount => (totalDiscountAmount ?? 0) > 0;

  // Helper: Get display amount (use discounted for actual price)
  double get actualAmount => discountedTotalAmount;

  // Helper: Get remaining amount
  double get remainingAmount => discountedTotalAmount - paidAmount;

  DateTime? _parseSlotDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final iso = DateTime.tryParse(dateStr);
      if (iso != null) return iso;
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final first = int.tryParse(parts[0]) ?? 0;
        final second = int.tryParse(parts[1]) ?? 0;
        final third = int.tryParse(parts[2]) ?? 0;
        if (first > 31) {
          return DateTime(first, second, third);
        } else {
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

  bool get isCompleted => status == 'completed' && paymentStatus == 'Fully Paid';
  bool get isFullyPaid => paymentStatus == 'Fully Paid' && !isCancelled;
}