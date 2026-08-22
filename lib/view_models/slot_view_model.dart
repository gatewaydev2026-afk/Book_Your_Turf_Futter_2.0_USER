// slot_view_model.dart - Updated with updateTurf method
// ✅ Small snackbar with 1-second duration at TOP

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../models/turf_model.dart';
import '../models/slot_model.dart';
import '../services/shared_prefs_helper.dart';

class SlotViewModel extends GetxController {
  late TurfModel turf;
  SlotViewModel(this.turf);

  final selectedDateIndex = 0.obs;
  final availableSlots = <SlotModel>[].obs;
  final selectedSlots = <SlotModel>[].obs;
  final selectedCourt = 0.obs;
  final isLoadingSlots = false.obs;
  final selectedPaymentType = 'full'.obs;

  late List<DateTime> dates;
  final errorMessage = ''.obs;

  final Map<String, List<SlotModel>> _slotsCache = {};
  bool _isFetching = false;

  // ============================================================
  // ✅ SHOW CUSTOM SMALL SNACKBAR AT TOP
  // ============================================================
  void _showSmallSnackbar(String title, String message, Color color) {
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: Colors.black,
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 8,
      maxWidth: 300,
      barBlur: 0,
      overlayBlur: 0,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOut,
      reverseAnimationCurve: Curves.easeIn,
      animationDuration: const Duration(milliseconds: 300),
      icon: Icon(
        color == Colors.red ? Icons.error_outline : Icons.check_circle,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  @override
  void onInit() {
    super.onInit();
    print('\n=== SLOT VIEW MODEL INITIALIZED ===');
    print('Turf: ${turf.name}');
    print('Courts: ${turf.courts}');
    print('Min Slots: ${turf.minSlots}');
    print('Advance Type: ${turf.advanceType}');
    print('Advance Value: ${turf.advanceValue}');
    print('====================================\n');

    _refreshDates();
    fetchSlotsForCurrentDate();
  }

  // ✅ NEW: Update turf and refresh data
  void updateTurf(TurfModel newTurf) {
    print('🔄 Updating turf in ViewModel');
    turf = newTurf;
    _refreshDates();
    _slotsCache.clear();
    selectedSlots.clear();
    fetchSlotsForCurrentDate();
    print('✅ Turf updated: ${turf.name}');
  }

  void _refreshDates() {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // Start from YESTERDAY (today - 1 day)
    final startDate = normalizedToday.subtract(Duration(days: 1));

    // Generate 60 days starting from yesterday
    dates = List.generate(30, (i) => startDate.add(Duration(days: i)));

    print('📅 Dates generated from: ${_formatDate(dates.first)} to ${_formatDate(dates.last)}');
    print('📅 Today is: ${_formatDate(normalizedToday)}');
    print('📅 Yesterday was: ${_formatDate(startDate)}');

    // Set selected index to point to TODAY (index 1, since index 0 is yesterday)
    int todayIndex = dates.indexWhere((date) =>
    date.year == normalizedToday.year &&
        date.month == normalizedToday.month &&
        date.day == normalizedToday.day);

    if (todayIndex != -1) {
      selectedDateIndex.value = todayIndex;
      print('📅 Selected today at index: $todayIndex');
    } else {
      selectedDateIndex.value = 1; // Default to index 1 (today)
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  void onClose() {
    _slotsCache.clear();
    super.onClose();
  }

  int get courtCount => turf.courts;

  // FIXED: totalPrice preserves decimals
  double get totalPrice {
    double total = 0.0;
    for (var slot in selectedSlots) {
      total += slot.priceAsDouble;
    }
    return total;
  }

  // FIXED: requiredAdvance preserves decimals
  double get requiredAdvance {
    double totalAdvance = 0.0;
    for (var slot in selectedSlots) {
      totalAdvance += slot.slotRequiredAdvance;
    }
    return totalAdvance;
  }

  double get calculatedAdvanceAmount => requiredAdvance;

  double get getPayableAmount {
    if (selectedPaymentType.value == 'full') {
      return totalPrice;
    } else {
      return calculatedAdvanceAmount;
    }
  }

  bool get isMinSlotsMet => selectedSlots.length >= turf.minSlots;

  String get _currentCacheKey {
    final date = dates[selectedDateIndex.value];
    return "${date.year}-${date.month}-${date.day}-court${selectedCourt.value}";
  }

  Future<void> fetchSlotsForCurrentDate() async {
    final date = dates[selectedDateIndex.value];
    await fetchSlotsForDate(date);
  }

  Future<void> fetchSlotsForDate(DateTime date) async {
    final cacheKey = _currentCacheKey;

    if (_slotsCache.containsKey(cacheKey)) {
      availableSlots.value = _slotsCache[cacheKey]!;
      selectedSlots.clear();
      return;
    }

    if (_isFetching) return;

    _isFetching = true;
    isLoadingSlots.value = true;

    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final courtNumber = selectedCourt.value + 1;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.get(
        '/user/${turf.id}/calendar/',
        queryParameters: {
          'date': formattedDate,
          'court': courtNumber,
        },
      );

      List<SlotModel> slots = [];

      if (response.data != null) {
        dynamic data = response.data;
        if (data is Map && data.containsKey('data')) {
          data = data['data'];
        }
        if (data is List) {
          slots = data.map((json) => SlotModel.fromJson(json)).toList();
        }
      }

      slots.sort((a, b) {
        if (a.isNextDay != b.isNextDay) return a.isNextDay ? 1 : -1;
        return a.startTime.compareTo(b.startTime);
      });

      _slotsCache[cacheKey] = slots;
      availableSlots.value = slots;
      selectedSlots.clear();

      print('✅ Total slots for ${_formatDate(date)}: ${slots.length}');
      for (var slot in slots) {
        print('   ${slot.startTime}-${slot.endTime} | Price: ₹${slot.formattedPrice} | NextDay: ${slot.isNextDay} | Status: ${slot.status}');
      }

    } catch (e) {
      print('❌ Error: $e');
      availableSlots.clear();
      errorMessage.value = 'Failed to load slots';
    } finally {
      isLoadingSlots.value = false;
      _isFetching = false;
    }
  }

  void selectDate(int index) {
    if (selectedDateIndex.value == index) return;

    final selectedDate = dates[index];
    print('🎯 Selected date: ${_formatDate(selectedDate)}');
    print('📱 Current device date: ${_formatDate(DateTime.now())}');

    selectedDateIndex.value = index;
    selectedSlots.clear();
    fetchSlotsForCurrentDate();
  }

  void selectCourt(int index) {
    if (selectedCourt.value == index) return;
    selectedCourt.value = index;
    selectedSlots.clear();
    _slotsCache.clear();
    fetchSlotsForCurrentDate();
  }

  void toggleSlot(SlotModel slot) {
    final selectedDate = dates[selectedDateIndex.value];
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    if (isToday) {
      try {
        int startHour = 0;
        int startMinute = 0;
        final startParts = slot.startTime.split(':');
        startHour = int.parse(startParts[0]);
        startMinute = int.parse(startParts[1]);

        int endHour = 0;
        int endMinute = 0;
        final endParts = slot.endTime.split(':');
        endHour = int.parse(endParts[0]);
        endMinute = int.parse(endParts[1]);

        bool isNextDaySlot = slot.isNextDay;

        if (isNextDaySlot) {
          DateTime slotEndDateTime = selectedDate.add(Duration(days: 1));
          slotEndDateTime = DateTime(
            slotEndDateTime.year,
            slotEndDateTime.month,
            slotEndDateTime.day,
            endHour,
            endMinute,
          );

          if (now.isAfter(slotEndDateTime)) {
            _showSmallSnackbar('Not Available', 'This slot time has already passed', Colors.grey);
            return;
          }
        } else {
          // ✅ FIX: 00:00 end time = midnight = 1440 minutes (not 0!)
          int slotEndMinutes = (endHour == 0 && endMinute == 0)
              ? 1440
              : endHour * 60 + endMinute;
          int currentTimeMinutes = now.hour * 60 + now.minute;

          if (currentTimeMinutes > slotEndMinutes) {
            _showSmallSnackbar('Not Available', 'This slot time has already passed', Colors.grey);
            return;
          }
        }
      } catch (e) {
        print('Error checking time: $e');
      }
    }

    if (!slot.isAvailable) {
      String message = slot.isBooked
          ? 'This slot is already booked'
          : slot.isReserved
          ? 'This slot is reserved'
          : 'This slot is not available';
      _showSmallSnackbar('Not Available', message, slot.isReserved ? Colors.orange : Colors.grey);
      return;
    }

    if (selectedSlots.contains(slot)) {
      selectedSlots.remove(slot);
      print('❌ Removed slot: ${slot.formattedTimeRange}');
    } else {
      selectedSlots.add(slot);
      print('✅ Added slot: ${slot.formattedTimeRange} - ₹${slot.formattedPrice}');
    }
  }

  bool canSelectSlot(SlotModel slot) {
    final selectedDate = dates[selectedDateIndex.value];
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    if (!isToday) return slot.isAvailable;

    try {
      int endHour = 0;
      int endMinute = 0;
      final endParts = slot.endTime.split(':');
      endHour = int.parse(endParts[0]);
      endMinute = int.parse(endParts[1]);

      bool isNextDaySlot = slot.isNextDay;

      if (isNextDaySlot) {
        DateTime slotEndDateTime = selectedDate.add(Duration(days: 1));
        slotEndDateTime = DateTime(
          slotEndDateTime.year,
          slotEndDateTime.month,
          slotEndDateTime.day,
          endHour,
          endMinute,
        );
        return slot.isAvailable && now.isBefore(slotEndDateTime);
      }

      // ✅ FIX: 00:00 end time = midnight = 1440 minutes (not 0!)
      int slotEndMinutes = (endHour == 0 && endMinute == 0)
          ? 1440
          : endHour * 60 + endMinute;
      int currentTimeMinutes = now.hour * 60 + now.minute;

      return slot.isAvailable && (slotEndMinutes > currentTimeMinutes);

    } catch (e) {
      print('Error in canSelectSlot: $e');
      return slot.isAvailable;
    }
  }

  Future<void> refresh() async {
    final currentCacheKey = _currentCacheKey;
    _slotsCache.remove(currentCacheKey);
    _refreshDates();
    await fetchSlotsForCurrentDate();
  }

  void resetToToday() {
    _refreshDates();
    _slotsCache.clear();
    selectedSlots.clear();
    fetchSlotsForCurrentDate();
    _showSmallSnackbar('Refreshed', 'Currently Available Slots', Colors.white);
  }

  List<SlotModel> get allSlots => availableSlots.toList();

  String getDayName(DateTime date) {
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.weekday % 7];
  }

  String getMonth(DateTime date) {
    return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][date.month - 1];
  }
}