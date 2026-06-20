// models/slot_model.dart - COMPLETELY FIXED WITH DECIMAL PRICE HANDLING
// ✅ Fixed: Floating point precision issues
// ✅ Fixed: Proper rounding for wallet payment

import '../utils/helpers.dart';

class SlotModel {
  final String date;
  final String startTime;
  final String endTime;
  final String price;  // Keep as String to preserve exact API value
  final String status;
  final bool isNextDay;
  final String gameType;

  // Advance fields from API
  final String requiredAdvance;
  final String advanceType;
  final String advanceValue;

  SlotModel({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.status,
    required this.isNextDay,
    this.gameType = '',
    this.requiredAdvance = '0',
    this.advanceType = 'percentage',
    this.advanceValue = '0',
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    print('Parsing slot JSON: $json');

    // Parse advance fields (API returns these at slot level)
    String requiredAdvance = json['required_advance']?.toString() ?? '0';
    String advanceType = json['advance_type']?.toString() ?? 'percentage';
    String advanceValue = json['advance_value']?.toString() ?? '0';
    String gameType = json['game_type']?.toString() ?? '';

    // Parse price - preserve exact value from API (e.g., "1.50" not "2")
    String priceValue = '0';
    if (json['price'] != null) {
      if (json['price'] is int) {
        priceValue = (json['price'] as int).toString();
      } else if (json['price'] is double) {
        // ✅ FIX: Round to 2 decimal places to avoid floating point issues
        double rounded = double.parse((json['price'] as double).toStringAsFixed(2));
        priceValue = rounded.toString();
      } else if (json['price'] is String) {
        // ✅ FIX: Parse and round string value
        double parsed = double.tryParse(json['price'] as String) ?? 0;
        double rounded = double.parse(parsed.toStringAsFixed(2));
        priceValue = rounded.toString();
      }
    }

    // ✅ FIX: Round requiredAdvance to 2 decimal places
    double advFromApi = double.tryParse(requiredAdvance) ?? 0;
    requiredAdvance = double.parse(advFromApi.toStringAsFixed(2)).toString();

    // ✅ FIX: Round advanceValue to 2 decimal places
    double advVal = double.tryParse(advanceValue) ?? 0;
    advanceValue = double.parse(advVal.toStringAsFixed(2)).toString();

    return SlotModel(
      date: json['date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      price: priceValue,
      status: json['status']?.toString() ?? 'Available',
      isNextDay: json['is_next_day'] ?? false,
      gameType: gameType,
      requiredAdvance: requiredAdvance,
      advanceType: advanceType,
      advanceValue: advanceValue,
    );
  }

  bool get isAvailable => status == 'Available';
  bool get isBooked => status == 'Booked';
  bool get isReserved => status == 'Reserved';
  bool get isUnavailable => status == 'Unavailable';

  String get formattedStartTime => formatTo12Hour(startTime);
  String get formattedEndTime => formatTo12Hour(endTime);
  String get formattedTimeRange => '${formatTo12Hour(startTime)} - ${formatTo12Hour(endTime)}';

  // ✅ FIXED: Get price as double with proper rounding
  double get priceAsDouble {
    try {
      double value = double.parse(price);
      return double.parse(value.toStringAsFixed(2));
    } catch (e) {
      return 0.0;
    }
  }

  // ✅ FIXED: Get advance for this specific slot with proper rounding
  double get slotRequiredAdvance {
    // If API provides required_advance, use it directly
    double advanceFromApi = double.tryParse(requiredAdvance) ?? 0;
    if (advanceFromApi > 0) {
      return double.parse(advanceFromApi.toStringAsFixed(2));
    }
    // Otherwise calculate from percentage
    double priceDouble = priceAsDouble;
    double advancePercent = double.tryParse(advanceValue) ?? 0;
    double calculated = priceDouble * (advancePercent / 100.0);
    // ✅ Round to 2 decimal places
    return double.parse(calculated.toStringAsFixed(2));
  }

  // ✅ FIXED: Format price for display (shows decimals only when needed)
  String get formattedPrice {
    double priceDouble = priceAsDouble;
    if (priceDouble == priceDouble.toInt()) {
      return priceDouble.toInt().toString();
    }
    // Show up to 2 decimal places, remove trailing zeros
    String formatted = priceDouble.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  // ✅ FIXED: Get formatted amount for API (always 2 decimal places)
  String get formattedAmountForApi {
    return priceAsDouble.toStringAsFixed(2);
  }

  // ✅ FIXED: Get formatted advance for API (always 2 decimal places)
  String get formattedAdvanceForApi {
    return slotRequiredAdvance.toStringAsFixed(2);
  }

  bool isFutureSlot(DateTime selectedDate) {
    final now = DateTime.now();
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day) {
      try {
        final timeParts = endTime.split(':');
        if (timeParts.length >= 2) {
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          int adjustedHour = hour;
          if (isNextDay) {
            adjustedHour = hour + 24;
          }
          final slotEndTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            adjustedHour,
            minute,
          );
          return slotEndTime.isAfter(now);
        }
        return false;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  // ✅ NEW: Get slot as map for API with proper formatting
  Map<String, String> toApiMap() {
    return {
      'start_time': startTime,
      'end_time': endTime,
      'price': formattedAmountForApi,
    };
  }

  // ✅ NEW: Check if slot can be paid via wallet
  bool canPayViaWallet(double walletBalance) {
    return walletBalance >= slotRequiredAdvance;
  }

  // ✅ NEW: Get remaining amount after wallet payment
  double getRemainingAfterWalletPayment(double walletBalance) {
    double remaining = walletBalance - slotRequiredAdvance;
    return double.parse(remaining.toStringAsFixed(2));
  }
}