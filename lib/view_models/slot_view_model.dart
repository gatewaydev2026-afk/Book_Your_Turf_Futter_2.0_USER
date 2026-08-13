// slot_view_model.dart - Updated with updateTurf method

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
            Get.snackbar(
              'Not Available',
              'This slot time has already passed',
              backgroundColor: Colors.grey,
              colorText: Colors.white,
            );
            return;
          }
        } else {
          // ✅ FIX: 00:00 end time = midnight = 1440 minutes (not 0!)
          int slotEndMinutes = (endHour == 0 && endMinute == 0)
              ? 1440
              : endHour * 60 + endMinute;
          int currentTimeMinutes = now.hour * 60 + now.minute;

          if (currentTimeMinutes > slotEndMinutes) {
            Get.snackbar(
              'Not Available',
              'This slot time has already passed',
              backgroundColor: Colors.grey,
              colorText: Colors.white,
            );
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
      Get.snackbar(
        'Not Available',
        message,
        backgroundColor: slot.isReserved ? Colors.orange : Colors.grey,
        colorText: Colors.white,
      );
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
    Get.snackbar(
      'Refreshed',
      'Showing slots from yesterday onwards',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }

  List<SlotModel> get allSlots => availableSlots.toList();

  String getDayName(DateTime date) {
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.weekday % 7];
  }

  String getMonth(DateTime date) {
    return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][date.month - 1];
  }
}