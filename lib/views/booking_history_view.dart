// booking_history_view.dart - COMPLETE WITH LAZY LOADING & DISCOUNT SUPPORT
// FIXED: Uses loadBookings() instead of fetch() for lazy loading
// ADDED: Discount display with strikethrough pricing
// ADDED: Discount breakdown in booking details
// FIXED: CircularProgressIndicator division by zero error
// FIXED: Extra closing bracket removed
// FIXED: Duplicate API call prevention with flags

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../config/app_config.dart';
import '../view_models/booking_view_model.dart';
import '../view_models/profile_view_model.dart';
import '../view_models/main_page_view_model.dart';
import '../models/booking_model.dart';
import '../utils/helpers.dart';
import '../routes/app_routes.dart';
import '../models/turf_model.dart';
import '../views/wallet_recharge_dialog.dart';
import '../services/notification_service.dart';

class BookingHistoryView extends StatelessWidget {
  BookingHistoryView({super.key});
  final vm = Get.find<BookingViewModel>();
  final profileVm = Get.find<ProfileViewModel>();

  // ✅ DUPLICATE API CALL PREVENTION FLAGS
  static bool _isPayingBalance = false;
  static bool _isRefreshing = false;
  static bool _isShowingDetails = false;
  static bool _isShowingCancelDialog = false;
  static bool _isShowingPaymentMethod = false;

  // Helper: Format price with decimals only when needed
  String _formatPrice(double price) {
    if (price == price.toInt()) {
      return price.toInt().toString();
    }
    String formatted = price.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  // Helper to determine if sport is Cricket or Football
  bool _isCricketOrFootball(String gameType) {
    final type = gameType.toLowerCase();
    return type.contains('cricket') || type.contains('football');
  }

  String _getSportImage(String gameType) {
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

  // Parse date from string - handles both DD-MM-YYYY and YYYY-MM-DD formats
  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    try {
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          int first = int.tryParse(parts[0]) ?? 0;
          int second = int.tryParse(parts[1]) ?? 0;
          int third = int.tryParse(parts[2]) ?? 0;

          if (first > 31) {
            return DateTime(first, second, third);
          } else {
            return DateTime(third, second, first);
          }
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (e) {
      print('Error parsing date: $dateStr - $e');
      return null;
    }
  }

  // Check if booking can be cancelled (all slots > 6 hours away)
  bool _canCancelBooking(BookingModel booking) {
    if (booking.isCancelled) return false;
    if (booking.isCompleted) return false;

    final now = DateTime.now();

    for (var slot in booking.slots) {
      final slotDateStr = slot['date'] ?? '';
      final startTime = slot['start_time'] ?? '';
      final isNextDay = slot['is_next_day'] ?? false;

      if (slotDateStr.isEmpty || startTime.isEmpty) continue;

      DateTime? slotDate = _parseDate(slotDateStr);
      if (slotDate == null) continue;

      final timeParts = startTime.split(':');
      if (timeParts.length < 2) continue;

      int hour = int.tryParse(timeParts[0]) ?? 0;
      int minute = int.tryParse(timeParts[1]) ?? 0;

      DateTime slotStartDateTime;
      if (isNextDay) {
        slotStartDateTime = DateTime(
            slotDate.year, slotDate.month, slotDate.day, hour, minute)
            .add(const Duration(days: 1));
      } else {
        slotStartDateTime = DateTime(
            slotDate.year, slotDate.month, slotDate.day, hour, minute);
      }

      final minutesDifference = slotStartDateTime.difference(now).inMinutes;

      if (minutesDifference < 360) {
        return false;
      }
    }

    return true;
  }

  // Get earliest slot time for warning message
  DateTime? _getEarliestSlotDateTime(BookingModel booking) {
    DateTime? earliest;

    for (var slot in booking.slots) {
      final slotDateStr = slot['date'] ?? '';
      final startTime = slot['start_time'] ?? '';
      final isNextDay = slot['is_next_day'] ?? false;

      if (slotDateStr.isEmpty || startTime.isEmpty) continue;

      DateTime? slotDate = _parseDate(slotDateStr);
      if (slotDate == null) continue;

      final timeParts = startTime.split(':');
      if (timeParts.length < 2) continue;

      int hour = int.tryParse(timeParts[0]) ?? 0;
      int minute = int.tryParse(timeParts[1]) ?? 0;

      DateTime slotDateTime;
      if (isNextDay) {
        slotDateTime = DateTime(
            slotDate.year,
            slotDate.month,
            slotDate.day,
            hour, minute
        ).add(const Duration(days: 1));
      } else {
        slotDateTime = DateTime(
            slotDate.year,
            slotDate.month,
            slotDate.day,
            hour, minute
        );
      }

      if (earliest == null || slotDateTime.isBefore(earliest)) {
        earliest = slotDateTime;
      }
    }

    return earliest;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

    // ✅ Load bookings when screen opens (lazy loading)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.loadBookings();
    });

    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/byt-bg.png"),
              fit: BoxFit.cover,
              opacity: 0.3,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _header(screenWidth, context),
                const SizedBox(height: 6),
                _filterSection(screenWidth, isSmallScreen),
                const SizedBox(height: 6),
                _tabs(isSmallScreen),
                const SizedBox(height: 8),
                Expanded(child: _list(isSmallScreen)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(double screenWidth, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth < 380 ? 12 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              final mainPageVm = Get.find<MainPageViewModel>();
              mainPageVm.changeTab(0);
            },
            icon: Icon(Icons.arrow_back, color: Colors.green, size: screenWidth < 380 ? 20 : 24),
          ),
          Text(
            "My Bookings",
            style: TextStyle(
              fontSize: screenWidth < 380 ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => vm.refreshBookings(),
                icon: Icon(Icons.refresh, color: Colors.green, size: screenWidth < 380 ? 20 : 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterSection(double screenWidth, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth < 380 ? 12 : 16),
      padding: EdgeInsets.all(screenWidth < 380 ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  const Text(
                    "Filters",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Obx(() => TextButton(
                onPressed: vm.hasActiveFilters.value
                    ? () => vm.clearDateFilters()
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: const Size(0, 28),
                ),
                child: Text(
                  "Clear All",
                  style: TextStyle(
                    color: vm.hasActiveFilters.value ? Colors.red : Colors.grey,
                    fontSize: isSmallScreen ? 10 : 11,
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildFilterButton("Today", Icons.today, () => vm.filterBySingleDate(DateTime.now()), isSmallScreen),
                    const SizedBox(width: 6),
                    _buildFilterButton("Tomorrow", Icons.calendar_today, () => vm.filterBySingleDate(DateTime.now().add(const Duration(days: 1))), isSmallScreen),
                    const SizedBox(width: 6),
                    _buildFilterButton("This Week", Icons.date_range, () {
                      final now = DateTime.now();
                      final startDate = DateTime(now.year, now.month, now.day - now.weekday + 1);
                      final endDate = DateTime(now.year, now.month, now.day + (7 - now.weekday));
                      vm.filterByDateRange(startDate, endDate);
                    }, isSmallScreen),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildFilterButton("This Month", Icons.calendar_month, () {
                      final now = DateTime.now();
                      final startDate = DateTime(now.year, now.month, 1);
                      final endDate = DateTime(now.year, now.month + 1, 0);
                      vm.filterByDateRange(startDate, endDate);
                    }, isSmallScreen),
                    const SizedBox(width: 6),
                    _buildFilterButton("Custom", Icons.edit_calendar, () => _showDatePicker(), isSmallScreen),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Obx(
                () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: vm.selectedPaymentStatus.value.isEmpty ? "All" : vm.selectedPaymentStatus.value,
                  hint: Text("Payment Status", style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.green.shade700)),
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade600),
                  items: vm.paymentStatusOptions.map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status, style: TextStyle(fontSize: isSmallScreen ? 11 : 12))
                  )).toList(),
                  onChanged: (value) => vm.filterByPaymentStatus(value ?? "All"),
                ),
              ),
            ),
          ),
          Obx(() {
            if (!vm.hasActiveFilters.value) return const SizedBox();
            List<String> activeFilters = [];
            if (vm.selectedDate.value != null) activeFilters.add("Date: ${_formatDate(vm.selectedDate.value!)}");
            if (vm.startDate.value != null && vm.endDate.value != null) {
              activeFilters.add("${_formatDate(vm.startDate.value!)} - ${_formatDate(vm.endDate.value!)}");
            }
            if (vm.selectedPaymentStatus.value.isNotEmpty && vm.selectedPaymentStatus.value != "All") {
              activeFilters.add("Status: ${vm.selectedPaymentStatus.value}");
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: activeFilters.map((filter) => Chip(
                  label: Text(filter, style: const TextStyle(fontSize: 9)),
                  backgroundColor: Colors.green.shade100,
                  deleteIcon: const Icon(Icons.close, size: 10),
                  onDeleted: () => vm.clearDateFilters(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                )).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, IconData icon, VoidCallback onTap, bool isSmallScreen) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade100,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isSmallScreen ? 14 : 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs(bool isSmallScreen) {
    return Obx(() {
      final tabs = ["today", "upcoming", "completed", "cancelled"];
      final labels = ["Today", "Upcoming", "Completed", "Cancelled"];
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isSelected = vm.selectedTab.value == tab;
            int count = 0;
            if (tab == "today") {
              final todayStr = _formatDate(DateTime.now());
              count = vm.bookings.where((b) => b.formattedDate == todayStr && !b.isCancelled).length;
            } else if (tab == "upcoming") {
              count = vm.getUpcomingCount();
            } else if (tab == "completed") {
              count = vm.getCompletedCount();
            } else if (tab == "cancelled") {
              count = vm.getCancelledCount();
            }
            return Expanded(
              child: GestureDetector(
                onTap: () => vm.changeTab(tab),
                child: Container(
                  height: isSmallScreen ? 32 : 36,
                  decoration: isSelected ? BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(25)) : null,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black54,
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 9 : 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (count > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "$count",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 7 : 9,
                                color: isSelected ? Colors.green : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    });
  }

  Widget _list(bool isSmallScreen) {
    return Obx(() {
      if (vm.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (vm.filteredBookings.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/no.json', height: 120),
              const SizedBox(height: 16),
              Text("No Bookings Found", style: TextStyle(fontSize: isSmallScreen ? 14 : 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  vm.hasActiveFilters.value ? "No bookings match your filters" : "Make your first booking!",
                  style: TextStyle(color: Colors.grey, fontSize: isSmallScreen ? 11 : 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              if (vm.hasActiveFilters.value)
                ElevatedButton.icon(
                  onPressed: () => vm.clearDateFilters(),
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text("Clear Filters"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          // ✅ Prevent duplicate refreshes
          if (_isRefreshing) {
            print('⏭️ Booking refresh already in progress - skipping duplicate');
            return;
          }
          _isRefreshing = true;
          try {
            await vm.refreshBookings();
          } finally {
            _isRefreshing = false;
          }
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: vm.filteredBookings.length,
          itemBuilder: (_, i) => _bookingCard(vm.filteredBookings[i], isSmallScreen),
        ),
      );
    });
  }

  Widget _bookingCard(BookingModel b, bool isSmallScreen) {
    final needsBalancePayment = b.paymentStatus == "Advance Paid" && b.remainingAmount > 0 && !b.isCancelled;
    final isFullyPaid = b.paymentStatus == "Fully Paid" && !b.isCancelled;
    final canCancelByRule = _canCancelBooking(b);
    final canCancel = !b.isCancelled && !b.isCompleted && canCancelByRule;

    String? cancelDisabledReason;
    String? cancelTimeRemainingLabel;
    if (!b.isCancelled && !b.isCompleted && !canCancelByRule) {
      final earliestSlot = _getEarliestSlotDateTime(b);
      if (earliestSlot != null) {
        final now = DateTime.now();
        final diff = earliestSlot.difference(now);
        final totalMinutesLeft = diff.inMinutes;
        final hoursLeft = diff.inHours;
        final minsLeft = totalMinutesLeft % 60;
        if (totalMinutesLeft > 0 && totalMinutesLeft < 360) {
          cancelDisabledReason =
          'Cancellation not allowed within 6 hours of the slot. '
              'Your slot starts in ${hoursLeft > 0 ? '${hoursLeft}h ' : ''}${minsLeft}m.';
          cancelTimeRemainingLabel =
          hoursLeft > 0 ? '${hoursLeft}h ${minsLeft}m to slot' : '${minsLeft}m to slot';
        } else if (totalMinutesLeft <= 0) {
          cancelDisabledReason = 'Slot has already started or passed — cancellation not available';
          cancelTimeRemainingLabel = 'Slot started';
        } else {
          cancelDisabledReason = 'Cancellation not available for this booking';
        }
      } else {
        cancelDisabledReason = 'Cancellation not available for this booking';
      }
    }

    final sortedSlots = _getSortedSlots(b.slots);
    final isCricketOrFootball = _isCricketOrFootball(b.gameType);
    final courtTurfLabel = isCricketOrFootball ? "Turf" : "Court";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showBookingDetails(b, isSmallScreen),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: isSmallScreen ? 40 : 45,
                            height: isSmallScreen ? 40 : 45,
                            decoration: BoxDecoration(
                              color: _getSportColor(b.gameType).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                            ),
                            child: Image.asset(_getSportImage(b.gameType), width: isSmallScreen ? 30 : 35, height: isSmallScreen ? 30 : 35, fit: BoxFit.contain),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.turfName, style: TextStyle(fontSize: isSmallScreen ? 13 : 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(_getGameTypeDisplay(b.gameType), style: TextStyle(fontSize: isSmallScreen ? 9 : 10, color: _getSportColor(b.gameType))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusChip(b, isSmallScreen),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: isSmallScreen ? 10 : 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(child: Text(b.formattedDate, style: TextStyle(fontSize: isSmallScreen ? 9 : 11), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.confirmation_number, size: isSmallScreen ? 10 : 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(child: Text("$courtTurfLabel ${b.courtNumber}", style: TextStyle(fontSize: isSmallScreen ? 9 : 11), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    _indicatior(b, isSmallScreen),
                  ],
                ),
                const SizedBox(height: 8),
                // ========== UPDATED: Amount with Discount Display ==========
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.currency_rupee, size: isSmallScreen ? 10 : 12, color: Colors.green),
                          const SizedBox(width: 4),
                          if (b.hasDiscount) ...[
                            // Original price with strikethrough
                            Text(
                              "₹${_formatPrice(b.totalAmount)}",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Discounted price (actual amount)
                            Text(
                              "₹${_formatPrice(b.discountedTotalAmount)}",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Discount percentage badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "-${((b.totalDiscountAmount ?? 0) / b.totalAmount * 100).toInt()}%",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7 : 8,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ] else ...[
                            // No discount - show regular price
                            Text(
                              "₹${_formatPrice(b.discountedTotalAmount)}",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: isSmallScreen ? 10 : 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text("${b.slots.length} slots", style: TextStyle(fontSize: isSmallScreen ? 9 : 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sortedSlots.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: sortedSlots.map((slot) {
                      final start = _formatTime12Hour(slot['start_time'] ?? '');
                      final end = _formatTime12Hour(slot['end_time'] ?? '');
                      final isNextDay = _isNextDaySlot(slot['start_time'] ?? '');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isNextDay ? Colors.purple.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isNextDay ? Colors.purple.shade200 : Colors.green.shade200, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 8, color: isNextDay ? Colors.purple : Colors.green),
                            const SizedBox(width: 3),
                            Text("$start - $end", style: TextStyle(fontSize: isSmallScreen ? 8 : 9, color: isNextDay ? Colors.purple.shade700 : Colors.green.shade700)),
                            if (isNextDay) ...[
                              const SizedBox(width: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(3)),
                                child: Text("Next Day", style: TextStyle(fontSize: isSmallScreen ? 5 : 7, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (canCancel)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showCancelConfirmDialog(b),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cancel, size: 14),
                              const SizedBox(width: 4),
                              Text("Cancel", style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                            ],
                          ),
                        ),
                      ),
                    if (canCancel) const SizedBox(width: 8),
                    if (cancelDisabledReason != null && !b.isCancelled && !b.isCompleted && !canCancelByRule)
                      Expanded(
                        child: Tooltip(
                          message: cancelDisabledReason,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_clock, size: 14, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text("Cancel", style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Colors.grey.shade400)),
                                  ],
                                ),
                              ),
                              if (cancelTimeRemainingLabel != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.timer_outlined, size: 10, color: Colors.red.shade400),
                                      const SizedBox(width: 3),
                                      Text(
                                        cancelTimeRemainingLabel!,
                                        style: TextStyle(fontSize: isSmallScreen ? 8 : 9, color: Colors.red.shade400, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(width: 20,),
                    Expanded(
                      child: _buildActionButton(b, needsBalancePayment, isFullyPaid, isSmallScreen),
                    ),
                  ],
                ),
                if (canCancelByRule && _getEarliestSlotDateTime(b) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Cancellation available until 6 hours before slot time',
                            style: TextStyle(fontSize: 9, color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: Safe CircularProgressIndicator with division by zero protection
  Widget _indicatior(BookingModel b, bool isSmallScreen) {
    // ✅ SAFE CALCULATION - Prevent division by zero
    double progressValue = 0.0;
    if (b.discountedTotalAmount > 0) {
      progressValue = b.paidAmount / b.discountedTotalAmount;
      // Clamp between 0 and 1
      if (progressValue > 1.0) progressValue = 1.0;
      if (progressValue < 0) progressValue = 0.0;
    } else if (b.paidAmount > 0 && b.totalAmount > 0) {
      // Fallback to original total amount
      progressValue = b.paidAmount / b.totalAmount;
      if (progressValue > 1.0) progressValue = 1.0;
      if (progressValue < 0) progressValue = 0.0;
    }

    return SizedBox(
      width: isSmallScreen ? 55 : 65,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: isSmallScreen ? 35 : 45,
            height: isSmallScreen ? 35 : 45,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressValue,  // ✅ SAFE VALUE (0.0 to 1.0)
                  strokeWidth: isSmallScreen ? 4 : 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            b.paymentStatus == "Fully Paid" ? "Fully Paid" : "Partial",
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 11,
              fontWeight: FontWeight.bold,
              color: b.paymentStatus == "Fully Paid" ? Colors.green : Colors.orange,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BookingModel b, bool needsBalancePayment,
      bool isFullyPaid, bool isSmallScreen) {
    if (needsBalancePayment) {
      return ElevatedButton(
        onPressed: () => _showBalancePaymentMethodSelection(b),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text(
          "Pay ₹${_formatPrice(b.remainingAmount)}",
          style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Colors.white),
        ),
      );
    }

    if (b.isCompleted) {
      return ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text("Completed", style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Colors.white)),
      );
    }

    if (b.isCancelled) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text("Cancelled", style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
      );
    }

    if (isFullyPaid && !b.isCompleted) {
      return ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text("Confirmed", style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: Colors.white)),
      );
    }

    return ElevatedButton(
      onPressed: () {
        final turf = TurfModel(
          id: 0,
          name: b.turfName,
          address: '',
          gameType: b.gameType,
          description: '',
          maxPersons: 0,
          courts: 1,
          openTime: '',
          closeTime: '',
          state: '',
          district: '',
          pincode: '',
          images: [],
          turfCode: '',
        );
        Get.toNamed(AppRoutes.slotSelection, arguments: turf);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
        minimumSize: const Size(0, 32),
      ),
      child: Text("Book Again", style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
    );
  }

  // ==================== BALANCE PAYMENT METHODS ====================

  // ✅ FIXED: Balance payment method selection with duplicate prevention
  void _showBalancePaymentMethodSelection(BookingModel booking) {
    if (_isShowingPaymentMethod || (Get.isBottomSheetOpen ?? false)) {
      print('⏭️ Payment method already showing - skipping duplicate');
      return;
    }

    _isShowingPaymentMethod = true;

    showModalBottomSheet(
      context: Get.context!,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pay Balance Amount',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (booking.hasDiscount) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer, size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'You saved ₹${_formatPrice(booking.totalDiscountAmount!)} (${((booking.totalDiscountAmount! / booking.totalAmount) * 100).toInt()}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Balance Amount:',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    '₹${_formatPrice(booking.remainingAmount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.credit_card, color: Colors.blue),
              ),
              title: const Text(
                'Pay Online',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Pay using Razorpay'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                vm.initiateBalancePayment(booking.id, booking.remainingAmount);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.green),
              ),
              title: const Text(
                'Pay with Wallet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Obx(() => Text(
                'Wallet Balance: ₹${_formatPrice(profileVm.walletBalance.value)}',
                style: TextStyle(
                  color: profileVm.walletBalance.value >= booking.remainingAmount
                      ? Colors.green
                      : Colors.red,
                ),
              )),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _proceedWithWalletBalancePayment(booking);
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ).whenComplete(() {
      _isShowingPaymentMethod = false;
    });
  }

  // ✅ FIXED: Proceed with wallet balance payment with duplicate prevention
  void _proceedWithWalletBalancePayment(BookingModel booking) async {
    if (Get.isDialogOpen ?? false) return;

    if (profileVm.walletBalance.value < booking.remainingAmount) {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Insufficient Balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Required Amount: ₹${_formatPrice(booking.remainingAmount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Your Balance: ₹${_formatPrice(profileVm.walletBalance.value)}', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              const Text('Please recharge your wallet to continue.', style: TextStyle(fontSize: 14)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Get.back();
                showDialog(context: Get.context!, builder: (context) => const WalletRechargeDialog());
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Recharge Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Wallet Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking ID: ${booking.bookingId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            if (booking.hasDiscount) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Original Price:', style: TextStyle(fontSize: 12)),
                  Text('₹${_formatPrice(booking.totalAmount)}', style: TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount:', style: TextStyle(fontSize: 12, color: Colors.green)),
                  Text('-₹${_formatPrice(booking.totalDiscountAmount!)}', style: TextStyle(fontSize: 12, color: Colors.green)),
                ],
              ),
              const Divider(),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to Pay:', style: TextStyle(fontSize: 14)),
                Text('₹${_formatPrice(booking.remainingAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Wallet Balance:', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                Text('₹${_formatPrice(profileVm.walletBalance.value)}', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount after payment:', style: TextStyle(fontSize: 12)),
                Text('₹${_formatPrice(profileVm.walletBalance.value - booking.remainingAmount)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _payBalanceWithWallet(booking);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  // ✅ FIXED: Wallet payment with duplicate prevention
  Future<void> _payBalanceWithWallet(BookingModel booking) async {
    if (_isPayingBalance) {
      print('⏭️ Balance payment already in progress - skipping duplicate');
      return;
    }

    if (vm.isPayingBalance.value) return;

    _isPayingBalance = true;
    vm.isPayingBalance.value = true;

    try {
      final dio = Get.find<Dio>();
      final response = await dio.post(
        AppConfig.payBalanceWallet,
        data: {
          'booking_id': booking.id,
          'amount': booking.remainingAmount.toString(),
        },
      );

      vm.isPayingBalance.value = false;
      _isPayingBalance = false;

      if (response.data['result'] == 'success') {
        if (Get.context != null) {
          Get.snackbar(
            'Payment Successful',
            '₹${_formatPrice(booking.remainingAmount)} deducted from wallet',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
        }

        await _refreshAfterPayment();

      } else {
        if (Get.context != null) {
          Get.snackbar(
            'Payment Failed',
            response.data['message'] ?? 'Something went wrong',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      print('Wallet balance payment error: $e');
      vm.isPayingBalance.value = false;
      _isPayingBalance = false;

      if (Get.context != null) {
        Get.snackbar(
          'Error',
          'Payment failed: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  // ✅ NEW: Refresh after payment with duplicate prevention
  Future<void> _refreshAfterPayment() async {
    if (_isRefreshing) {
      print('⏭️ Refresh already in progress - skipping duplicate');
      return;
    }

    _isRefreshing = true;

    try {
      await profileVm.fetchUser(forceRefresh: true);
      await vm.refreshBookings();
      vm.filteredBookings.refresh();
      vm.bookings.refresh();
    } catch (e) {
      print('❌ Refresh error: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  // ==================== CANCEL CONFIRMATION ====================

  // ✅ FIXED: Cancel dialog with duplicate prevention
  void _showCancelConfirmDialog(BookingModel booking) {
    if (_isShowingCancelDialog || (Get.isDialogOpen ?? false)) {
      print('⏭️ Cancel dialog already showing - skipping duplicate');
      return;
    }

    _isShowingCancelDialog = true;

    final bookingId = booking.id;
    final bookingCode = booking.bookingId;
    final isFullyPaid = booking.paymentStatus == "Fully Paid";
    final isAdvancePaid = booking.paymentStatus == "Advance Paid";
    final paidAmount = booking.paidAmount;

    // Build refund message based on payment type
    Widget _refundInfoWidget() {
      if (isFullyPaid) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Full Payment Refund',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatPrice(paidAmount)} will be refunded to your wallet',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      if (isAdvancePaid) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Advance Payment Refund',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_formatPrice(paidAmount)} (advance paid) will be refunded to your wallet',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Remaining balance payment is not required after cancellation',
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade600),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      // No payment made (pending state)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'No payment was made — booking will be cancelled',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Booking"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Cancel booking #$bookingCode?", style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            _refundInfoWidget(),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: TextStyle(fontSize: 10, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("No"),
          ),
          Obx(
                () => ElevatedButton(
              onPressed: vm.isCancelling.value
                  ? null
                  : () async {
                Get.back();
                final success = await vm.cancelBooking(bookingId);
                if (success) {
                  await vm.refreshBookings();
                  await profileVm.fetchUser();
                  vm.changeTab("cancelled");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: vm.isCancelling.value
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Yes, Cancel", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    ).whenComplete(() {
      _isShowingCancelDialog = false;
    });
  }

  Widget _statusChip(BookingModel b, bool isSmallScreen) {
    String statusText;
    Color bgColor;
    Color textColor;

    if (b.isCancelled) {
      statusText = "Cancelled";
      bgColor = Colors.red.shade50;
      textColor = Colors.red;
    } else if (b.isCompleted) {
      statusText = "Completed";
      bgColor = Colors.green.shade50;
      textColor = Colors.green;
    } else if (b.paymentStatus == "Fully Paid") {
      statusText = "Confirmed";
      bgColor = Colors.green.shade50;
      textColor = Colors.green;
    } else if (b.paymentStatus == "Advance Paid") {
      statusText = "Advance";
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange;
    } else {
      statusText = "Pending";
      bgColor = Colors.grey.shade50;
      textColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 8, vertical: isSmallScreen ? 2 : 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Text(statusText, style: TextStyle(fontSize: isSmallScreen ? 8 : 10, color: textColor, fontWeight: FontWeight.w600)),
    );
  }

  void _showDatePicker() {
    DateTime? tempStart;
    DateTime? tempEnd;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Date Range"),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text("Start Date"),
                  subtitle: Text(tempStart != null ? _formatDate(tempStart!) : "Not selected"),
                  trailing: const Icon(Icons.calendar_today, color: Colors.green),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: tempStart ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D32), onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
                        ),
                        child: child!,
                      ),
                    );
                    if (date != null) setState(() => tempStart = date);
                  },
                ),
                ListTile(
                  title: const Text("End Date"),
                  subtitle: Text(tempEnd != null ? _formatDate(tempEnd!) : "Not selected"),
                  trailing: const Icon(Icons.calendar_today, color: Colors.green),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: tempEnd ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFF2E7D32), onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
                        ),
                        child: child!,
                      ),
                    );
                    if (date != null) setState(() => tempEnd = date);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (tempStart != null && tempEnd != null) {
                vm.filterByDateRange(tempStart!, tempEnd!);
              } else if (tempStart != null) {
                vm.filterBySingleDate(tempStart!);
              }
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Apply", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";

  String _formatTime12Hour(String time24) {
    if (time24.isEmpty || time24 == 'null') return 'Not specified';
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

  bool _isNextDaySlot(String startTime) {
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

  List<Map<String, dynamic>> _getSortedSlots(List<Map<String, dynamic>> slots) {
    final List<Map<String, dynamic>> regularSlots = [];
    final List<Map<String, dynamic>> nextDaySlots = [];

    for (var slot in slots) {
      final startTime = slot['start_time'] ?? '';
      final isNextDay = _isNextDaySlot(startTime);
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

  IconData _getSportIcon(String gameType) {
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

  Color _getSportColor(String gameType) {
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

  String _getGameTypeDisplay(String gameType) {
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

  // ==================== UPDATED: Booking Details with Discount Breakdown ====================

  // ✅ FIXED: Show booking details with duplicate prevention
  void _showBookingDetails(BookingModel b, bool isSmallScreen) {
    if (_isShowingDetails || (Get.isBottomSheetOpen ?? false)) {
      print('⏭️ Booking details already showing - skipping duplicate');
      return;
    }

    _isShowingDetails = true;

    final sortedSlots = _getSortedSlots(b.slots);
    final isCricketOrFootball = _isCricketOrFootball(b.gameType);
    final courtTurfLabel = isCricketOrFootball ? "Turf" : "Court";
    final canCancel = _canCancelBooking(b);

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _getSportColor(b.gameType).withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(_getSportIcon(b.gameType), size: 40, color: _getSportColor(b.gameType)),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(b.turfName, style: TextStyle(fontSize: isSmallScreen ? 18 : 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _getSportColor(b.gameType).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(_getGameTypeDisplay(b.gameType), style: TextStyle(fontSize: 12, color: _getSportColor(b.gameType))),
                ),
              ),
              const SizedBox(height: 20),
              _detailRow("Booking ID", b.bookingId, isSmallScreen),
              _detailRow("Turf Name", b.turfName, isSmallScreen),
              _detailRow("$courtTurfLabel Number", "$courtTurfLabel ${b.courtNumber}", isSmallScreen),
              _detailRow("Payment Status", b.paymentStatus, isSmallScreen),

              // ========== DISCOUNT BREAKDOWN SECTION ==========
              if (b.hasDiscount) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_offer, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Discount Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (b.adminDiscountAmount != null && b.adminDiscountAmount! > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Admin Discount', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              Text(
                                '-₹${_formatPrice(b.adminDiscountAmount!)}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                      if (b.partnerDiscountAmount != null && b.partnerDiscountAmount! > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Partner Discount', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              Text(
                                '-₹${_formatPrice(b.partnerDiscountAmount!)}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Discount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(
                            '-₹${_formatPrice(b.totalDiscountAmount!)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Original Price', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text(
                            '₹${_formatPrice(b.totalAmount)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Final Price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${_formatPrice(b.discountedTotalAmount)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              _detailRow("Total Amount", "₹${_formatPrice(b.discountedTotalAmount)}", isSmallScreen),
              _detailRow("Paid Amount", "₹${_formatPrice(b.paidAmount)}", isSmallScreen),
              _detailRow("Pending Amount", "₹${_formatPrice(b.remainingAmount)}", isSmallScreen),
              _detailRow("Booking Date", b.formattedDate, isSmallScreen),
              const SizedBox(height: 10),
              const Text("Slots", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...sortedSlots.map((slot) {
                final start = _formatTime12Hour(slot['start_time'] ?? '');
                final end = _formatTime12Hour(slot['end_time'] ?? '');
                final isNextDay = _isNextDaySlot(slot['start_time'] ?? '');
                final slotDate = slot['date'] ?? b.formattedDate;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isNextDay ? Colors.purple.shade50 : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: isNextDay ? Colors.purple : Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("$start - $end", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            if (isNextDay) const Text("Next Day Slot", style: TextStyle(fontSize: 11, color: Colors.purple)),
                          ],
                        ),
                      ),
                      Text(slotDate, style: TextStyle(fontSize: 12, color: isNextDay ? Colors.purple : Colors.grey)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Get.back(), child: const Text("Close"))),
                  if (!b.isCancelled && !b.isCompleted && canCancel)
                    const SizedBox(width: 12),
                  if (!b.isCancelled && !b.isCompleted && canCancel)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          _showCancelConfirmDialog(b);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Cancel Booking"),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      _isShowingDetails = false;
    });
  }

  Widget _detailRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: isSmallScreen ? 90 : 100, child: Text(label, style: TextStyle(color: Colors.grey, fontSize: isSmallScreen ? 11 : 12))),
          Expanded(child: Text(value, style: TextStyle(fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final today = vm.bookings.where((b) => b.formattedDate == todayStr && !b.isCancelled).length;
    final upcoming = vm.getUpcomingCount();
    final completed = vm.getCompletedCount();
    final cancelled = vm.getCancelledCount();
    final totalAmount = vm.bookings.fold(0.0, (sum, b) => sum + b.discountedTotalAmount);
    final paidAmount = vm.bookings.fold(0.0, (sum, b) => sum + b.paidAmount);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Booking Statistics"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statItem("Today's Bookings", today.toString(), Icons.today, Colors.orange),
            _statItem("Upcoming", upcoming.toString(), Icons.access_time, Colors.green),
            _statItem("Completed", completed.toString(), Icons.check_circle, Colors.blue),
            _statItem("Cancelled", cancelled.toString(), Icons.cancel, Colors.red),
            const Divider(),
            _statItem("Total Spent", "${_formatPrice(totalAmount)}", Icons.money, Colors.green),
            _statItem("Total Paid", "${_formatPrice(paidAmount)}", Icons.payment, Colors.orange),
          ],
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text("Close"))],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
    );
  }
}