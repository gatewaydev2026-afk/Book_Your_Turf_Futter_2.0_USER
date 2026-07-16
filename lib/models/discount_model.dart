// lib/models/discount_model.dart
// ✅ Fixed: applicable_payment_type "full" now correctly filtered
// ✅ Added debug logs to verify filtering

import 'package:flutter/material.dart';

class DiscountModel {
  final int id;
  final String name;
  final String description;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final double? maxDiscountAmount;
  final double? minAmount;
  final int? minSlots;
  final String? applicableTimeStart;
  final String? applicableTimeEnd;
  final bool mon;
  final bool tue;
  final bool wed;
  final bool thu;
  final bool fri;
  final bool sat;
  final bool sun;
  final bool isActive;
  final String? startDate;
  final String? endDate;
  final int? usageLimit;
  final int? usedCount;
  final String source; // 'admin' or 'partner'
  final String? partnerName;
  final String? turfName;
  final String? applicablePaymentType; // 'advance', 'full', 'both'
  final String? discountApplicationType; // 'overall' or 'payable'
  final Map<String, dynamic>? requirements;
  final double? calculatedDiscount;

  DiscountModel({
    required this.id,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountAmount,
    this.minAmount,
    this.minSlots,
    this.applicableTimeStart,
    this.applicableTimeEnd,
    this.mon = false,
    this.tue = false,
    this.wed = false,
    this.thu = false,
    this.fri = false,
    this.sat = false,
    this.sun = false,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.usageLimit,
    this.usedCount,
    required this.source,
    this.partnerName,
    this.turfName,
    this.applicablePaymentType,
    this.discountApplicationType,
    this.requirements,
    this.calculatedDiscount,
  });

  factory DiscountModel.fromJson(Map<String, dynamic> json) {
    print('📦 Parsing Discount from JSON:');
    print('   id: ${json['id']}');
    print('   name: ${json['name']}');
    print('   applicable_payment_type: ${json['applicable_payment_type']}');
    print('   source: ${json['source']}');
    print('   calculated_discount: ${json['calculated_discount']}');

    if (json['applicable_payment_type'] == 'full') {
      print('   🔥 FULL PAYMENT DISCOUNT FOUND!');
    }

    return DiscountModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      discountType: json['discount_type'] ?? 'percentage',
      discountValue: double.tryParse(json['discount_value']?.toString() ?? '0') ?? 0,
      maxDiscountAmount: double.tryParse(json['max_discount_amount']?.toString() ?? ''),
      minAmount: double.tryParse(json['min_amount']?.toString() ?? ''),
      minSlots: json['min_slots'],
      applicableTimeStart: json['applicable_time_start'],
      applicableTimeEnd: json['applicable_time_end'],
      mon: json['mon'] ?? false,
      tue: json['tue'] ?? false,
      wed: json['wed'] ?? false,
      thu: json['thu'] ?? false,
      fri: json['fri'] ?? false,
      sat: json['sat'] ?? false,
      sun: json['sun'] ?? false,
      isActive: json['is_active'] ?? true,
      startDate: json['start_date'],
      endDate: json['end_date'],
      usageLimit: json['usage_limit'],
      usedCount: json['used_count'],
      source: json['source'] ?? 'admin',
      partnerName: json['partner_name'],
      turfName: json['turf_name'],
      applicablePaymentType: json['applicable_payment_type'] ?? 'both',
      discountApplicationType: json['discount_application_type'] ?? 'overall',
      requirements: json['requirements'],
      calculatedDiscount: double.tryParse(json['calculated_discount']?.toString() ?? ''),
    );
  }

  // ✅ FIXED: This method now correctly handles "full" payment type
  bool isApplicableForPaymentType(String paymentType) {
    // ✅ Normalize both sides - strips hidden whitespace/case mismatches
    // that would otherwise silently fail the exact string comparison below.
    final normalizedApplicable = applicablePaymentType?.trim().toLowerCase();
    final normalizedPaymentType = paymentType.trim().toLowerCase();

    print('\n🔍 ===== DISCOUNT FILTER CHECK =====');
    print('   Discount: "$name" (ID: $id)');
    print('   applicablePaymentType from API (raw): "${applicablePaymentType ?? "null"}"');
    print('   paymentType passed from UI (raw): "$paymentType"');
    print('   normalized: "$normalizedApplicable" vs "$normalizedPaymentType"');

    // ✅ If applicablePaymentType is null or 'both', always return true
    if (normalizedApplicable == null || normalizedApplicable == 'both') {
      print('   ✅ RESULT: TRUE (applicablePaymentType is null or "both")');
      print('====================================\n');
      return true;
    }

    // ✅ Direct comparison - "full" == "full" or "advance" == "advance"
    final result = normalizedApplicable == normalizedPaymentType;
    print('   📊 Comparing: "${normalizedApplicable}" == "$normalizedPaymentType"');
    print('   ${result ? '✅ RESULT: TRUE (match found)' : '❌ RESULT: FALSE (no match)'}');

    // ✅ Extra check for full payment
    if (normalizedApplicable == 'full' && normalizedPaymentType == 'full') {
      print('   🔥 FULL PAYMENT DISCOUNT MATCHED!');
    }

    print('====================================\n');
    return result;
  }

  bool isApplicableOnDay(int weekday) {
    switch (weekday) {
      case 1: return mon;
      case 2: return tue;
      case 3: return wed;
      case 4: return thu;
      case 5: return fri;
      case 6: return sat;
      case 7: return sun;
      default: return false;
    }
  }

  List<String> getApplicableDays() {
    final days = <String>[];
    if (mon) days.add('Mon');
    if (tue) days.add('Tue');
    if (wed) days.add('Wed');
    if (thu) days.add('Thu');
    if (fri) days.add('Fri');
    if (sat) days.add('Sat');
    if (sun) days.add('Sun');
    return days;
  }

  String getDisplayText() {
    if (discountType == 'percentage') {
      return '${discountValue.toInt()}% OFF';
    } else {
      return '₹${discountValue.toStringAsFixed(0)} OFF';
    }
  }

  String getSourceBadge() {
    if (source == 'partner') {
      return 'Venue Offer';
    }
    return 'Platform Offer';
  }

  Color getSourceColor() {
    if (source == 'partner') {
      return Colors.purple;
    }
    return Colors.blue;
  }

  int? getRemainingUses() {
    if (usageLimit == null) return null;
    return usageLimit! - (usedCount ?? 0);
  }

  String getPaymentTypeBadge() {
    if (applicablePaymentType == null || applicablePaymentType == 'both') {
      return 'All Payments';
    }
    return applicablePaymentType == 'advance' ? 'Advance Only' : 'Full Only';
  }

  Color getPaymentTypeColor() {
    if (applicablePaymentType == null || applicablePaymentType == 'both') {
      return Colors.green;
    }
    return applicablePaymentType == 'advance' ? Colors.orange : Colors.blue;
  }

  String getApplicationTypeBadge() {
    if (discountApplicationType == 'payable') {
      return 'Advance Only';
    } else {
      return 'Full Amount';
    }
  }

  Color getApplicationTypeColor() {
    if (discountApplicationType == 'payable') {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  String getFormattedDiscount() {
    if (calculatedDiscount == null || calculatedDiscount == 0) return 'No discount';
    return '₹${calculatedDiscount!.toStringAsFixed(2)} OFF';
  }

  String getFullDescription() {
    final conditions = <String>[];

    if (minSlots != null && minSlots! > 0) {
      conditions.add('Minimum ${minSlots} slots required');
    }
    if (minAmount != null && minAmount! > 0) {
      conditions.add('Minimum order ₹${minAmount!.toStringAsFixed(0)}');
    }
    if (applicableTimeStart != null && applicableTimeEnd != null) {
      conditions.add('Valid ${_formatTime(applicableTimeStart!)} - ${_formatTime(applicableTimeEnd!)}');
    }
    final days = getApplicableDays();
    if (days.isNotEmpty && days.length < 7) {
      conditions.add('Available on: ${days.join(", ")}');
    }
    if (startDate != null && endDate != null) {
      conditions.add('Valid until ${_formatDate(endDate!)}');
    }
    final remaining = getRemainingUses();
    if (remaining != null && remaining > 0) {
      conditions.add('${remaining} uses left');
    }

    return conditions.join(' • ');
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        String period = hour >= 12 ? 'PM' : 'AM';
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        return '$hour12:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {}
    return time;
  }

  String _formatDate(String date) {
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${int.parse(parts[2])} ${months[int.parse(parts[1]) - 1]} ${parts[0]}';
      }
    } catch (e) {}
    return date;
  }

  void debugPrint() {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  📋 DISCOUNT DETAILS                                       ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('   ID: $id');
    print('   Name: $name');
    print('   applicablePaymentType: "${applicablePaymentType ?? "both"}"');
    print('   discountApplicationType: "${discountApplicationType ?? "overall"}"');
    print('   calculatedDiscount: ${calculatedDiscount ?? "N/A"}');
    print('═══════════════════════════════════════════════════════════════\n');
  }
}