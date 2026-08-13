// slot_view.dart - Complete with proper back navigation, argument handling, and duplicate prevention

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/slot_model.dart';
import '../models/turf_model.dart';
import '../view_models/slot_view_model.dart';
import '../routes/app_routes.dart';
import '../utils/helpers.dart';
import '../services/shared_prefs_helper.dart';
import 'demoview/signup_with_booking_view.dart';

// Helper functions
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
  if (type.contains('badminton')) return Colors.purple.shade700;
  if (type.contains('pickleball') || type.contains('pickle ball')) return Colors.orange.shade700;
  if (type.contains('basketball')) return Colors.orange.shade700;
  if (type.contains('volleyball')) return Colors.blue.shade700;
  if (type.contains('tennis')) return Colors.lime.shade700;
  return Colors.green.shade700;
}

bool _isCricketOrFootball(String gameType) {
  final type = gameType.toLowerCase();
  return type.contains('cricket') || type.contains('football');
}

String _getTotalHours(String openTime, String closeTime) {
  try {
    List<String> openParts = openTime.split(':');
    int openHour = int.parse(openParts[0]);
    int openMinute = int.parse(openParts[1]);

    List<String> closeParts = closeTime.split(':');
    int closeHour = int.parse(closeParts[0]);
    int closeMinute = int.parse(closeParts[1]);

    int totalMinutes = (closeHour * 60 + closeMinute) - (openHour * 60 + openMinute);

    if (totalMinutes < 0) {
      totalMinutes += 24 * 60;
    }

    if (totalMinutes <= 0) {
      return '';
    }

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;

    if (minutes > 0) {
      return '$hours hrs $minutes min';
    }
    return '$hours hrs';
  } catch (e) {
    return '';
  }
}

class SlotView extends StatefulWidget {
  final dynamic _args;

  SlotView({super.key}) : _args = Get.arguments;

  @override
  State<SlotView> createState() => _SlotViewState();
}

class _SlotViewState extends State<SlotView> {
  bool _pendingRestored = false;
  TurfModel? _cachedTurf;
  SlotViewModel? _cachedVm;
  bool _isInitialized = false;

  // ✅ Prevent multiple "Proceed to Pay" calls
  bool _isProceedingToPay = false;

  @override
  void initState() {
    super.initState();
    _initializeView();
  }

  void _initializeView() {
    if (_isInitialized) return;

    final args = widget._args;

    if (args == null) {
      print('❌ SlotView: No arguments provided');
      return;
    }

    try {
      TurfModel? turf;

      if (args is Map && args['_pendingBooking'] == true) {
        print('🔄 Restoring pending booking data from Get.back()...');

        final turfArg = args['turf'];
        if (turfArg is TurfModel) {
          turf = turfArg;
          print('✅ SlotView: Received TurfModel from pending booking: ${turf.name}');
        } else if (turfArg is Map<String, dynamic>) {
          print('✅ SlotView: Converting Map to TurfModel from pending booking');
          turf = TurfModel.fromJson(turfArg);
        }

        if (turf != null) {
          _cachedTurf = turf;
          _setupViewModel(turf!);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restorePendingBooking(args, turf!);
          });
        }
      }
      else if (args is TurfModel) {
        turf = args;
        print('✅ SlotView: Received TurfModel directly: ${turf.name}');
        _cachedTurf = turf;
        _setupViewModel(turf);
      }
      else if (args is Map<String, dynamic>) {
        print('✅ SlotView: Received Map, converting to TurfModel');
        if (args.containsKey('turf') && args['turf'] is TurfModel) {
          turf = args['turf'] as TurfModel;
          print('✅ SlotView: Extracted TurfModel from Map: ${turf.name}');
        } else {
          try {
            turf = TurfModel.fromJson(args);
            print('✅ SlotView: Converted Map to TurfModel: ${turf.name}');
          } catch (e) {
            print('❌ SlotView: Error converting Map to TurfModel: $e');
            if (args.containsKey('turf') && args['turf'] is Map<String, dynamic>) {
              turf = TurfModel.fromJson(args['turf'] as Map<String, dynamic>);
            }
          }
        }
        if (turf != null) {
          _cachedTurf = turf;
          _setupViewModel(turf);
        }
      }
      else {
        print('❌ SlotView: Invalid arguments type: ${args.runtimeType}');
      }

      _isInitialized = true;
    } catch (e) {
      print('❌ SlotView initialization error: $e');
    }
  }

  void _setupViewModel(TurfModel turf) {
    if (Get.isRegistered<SlotViewModel>()) {
      final existing = Get.find<SlotViewModel>();
      if (existing.turf.id == turf.id) {
        print('♻️ Reusing existing SlotViewModel for turf ${turf.name}');
        _cachedVm = existing;
        return;
      }
      print('🆕 Different turf selected — resetting SlotViewModel');
      Get.delete<SlotViewModel>();
    }
    _cachedVm = Get.put(SlotViewModel(turf));
  }

  void _restorePendingBooking(Map args, TurfModel turf) {
    if (_pendingRestored) return;
    _pendingRestored = true;

    final vm = _cachedVm;
    if (vm == null) return;

    final pendingSlots = args['pendingSlots'] as List<SlotModel>?;
    if (pendingSlots != null && pendingSlots.isNotEmpty) {
      vm.selectedSlots.assignAll(pendingSlots);
      print('✅ Restored ${pendingSlots.length} slots');
    }

    final pendingCourt = args['pendingCourt'] as int?;
    if (pendingCourt != null && vm.courtCount > 0) {
      vm.selectedCourt.value = pendingCourt - 1;
      print('✅ Restored court: $pendingCourt');
    }

    final pendingDate = args['pendingDate'] as DateTime?;
    if (pendingDate != null) {
      final dateIndex = vm.dates.indexWhere((d) =>
      d.year == pendingDate.year &&
          d.month == pendingDate.month &&
          d.day == pendingDate.day
      );
      if (dateIndex != -1) {
        vm.selectedDateIndex.value = dateIndex;
        print('✅ Restored date: ${pendingDate.toIso8601String().split('T').first}');
      }
    }

    final pendingPaymentType = args['pendingPaymentType'] as String?;
    if (pendingPaymentType != null) {
      vm.selectedPaymentType.value = pendingPaymentType;
      print('✅ Restored payment type: $pendingPaymentType');
    }

    Get.snackbar(
      '✅ Welcome!',
      'Your selected slots are restored. Please proceed to pay.',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Unable to load turf details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please go back and try again',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Go Back', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cachedTurf == null) {
      return _buildErrorWidget();
    }

    final turf = _cachedTurf!;
    final vm = _cachedVm;

    if (vm == null) {
      return _buildErrorWidget();
    }

    return _buildSlotViewUI(context, vm, turf);
  }

  Widget _buildSlotViewUI(BuildContext context, SlotViewModel vm, TurfModel turf) {
    final width = MediaQuery.of(context).size.width;
    final isGuest = SharedPrefsHelper.getToken() == null || SharedPrefsHelper.getToken()!.isEmpty;

    int crossCount = width > 600 ? 4 : 3;
    double timeFontSize = width > 600 ? 12 : 11;
    final courtTurfLabel = _isCricketOrFootball(turf.gameType) ? "Turf" : "Court";

    return Scaffold(
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _buildHeader(turf, vm, courtTurfLabel),
            const SizedBox(height: 4),
            _buildDatePicker(vm),
            if (vm.courtCount > 1) _buildCourtSelector(context, vm, courtTurfLabel),
            const SizedBox(height: 6),
            _buildLegend(),
            const SizedBox(height: 6),
            _buildTodayInfoBanner(vm),
            const SizedBox(height: 6),
            Expanded(
              child: Obx(() {
                return RefreshIndicator(
                  key: ValueKey('${vm.selectedDateIndex.value}_${vm.selectedCourt.value}_${vm.isLoadingSlots.value}'),
                  onRefresh: () async {
                    await vm.refresh();
                  },
                  color: Colors.green,
                  child: _buildSlotGrid(context, vm, crossCount, timeFontSize),
                );
              }),
            ),
            _buildBottomBar(context, vm, turf, width, isGuest),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TurfModel turf, SlotViewModel vm, String courtTurfLabel) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () {
                  print('🔙 Going back to TurfDetailsView');
                  Get.back();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  turf.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: Colors.green.shade700),
                onPressed: () => vm.resetToToday(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              if (vm.courtCount > 1)
                Obx(
                      () => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      '$courtTurfLabel ${vm.selectedCourt.value + 1}/${vm.courtCount}',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getSportColor(turf.gameType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getSportIcon(turf.gameType),
                      size: 10,
                      color: _getSportColor(turf.gameType),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      turf.gameType.isNotEmpty ? turf.gameType : 'Sports',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getSportColor(turf.gameType),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (turf.openTime.isNotEmpty && turf.closeTime.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text(
                      '${formatTo12Hour(turf.openTime)} - ${formatTo12Hour(turf.closeTime)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    Builder(
                      builder: (context) {
                        final totalHours = _getTotalHours(turf.openTime, turf.closeTime);
                        if (totalHours.isNotEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              totalHours,
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(SlotViewModel vm) {
    return SizedBox(
      height: 75,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vm.dates.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (_, i) {
          final d = vm.dates[i];
          final now = DateTime.now();
          final isToday = d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;

          return Obx(() {
            final isSel = vm.selectedDateIndex.value == i;
            return GestureDetector(
              onTap: () {
                vm.selectDate(i);
              },
              child: Container(
                width: 60,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSel ? Colors.green : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? Colors.green : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isToday ? "TODAY" : vm.getDayName(d),
                      style: TextStyle(
                        fontSize: isToday ? 8 : 9,
                        color: isSel
                            ? Colors.white
                            : (isToday ? Colors.green : Colors.black),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      "${d.day}",
                      style: TextStyle(
                        fontSize: 14,
                        color: isSel ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      vm.getMonth(d),
                      style: TextStyle(
                        fontSize: 9,
                        color: isSel ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildCourtSelector(BuildContext context, SlotViewModel vm, String courtTurfLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: () => _showCourtSheet(context, vm, courtTurfLabel),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 3,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                _isCricketOrFootball(vm.turf.gameType) ? Icons.sports_soccer : Icons.sports_tennis,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 6),
              Text(
                "Select $courtTurfLabel",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Obx(
                    () => Text(
                  "$courtTurfLabel ${vm.selectedCourt.value + 1}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.green, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          _legendItem('Available', Colors.white, Colors.green),
          _legendItem('Selected', Colors.green, Colors.white),
          _legendItem('Booked', Colors.red, Colors.white),
          _legendItem('Reserved', Colors.orange, Colors.white),
          _legendItem('Blocked', Colors.grey, Colors.grey),
          _legendItem('Next Day', Colors.purple.shade100, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildTodayInfoBanner(SlotViewModel vm) {
    return Obx(() {
      final selectedDate = vm.dates[vm.selectedDateIndex.value];
      final now = DateTime.now();
      final isToday = selectedDate.year == now.year &&
          selectedDate.month == now.month &&
          selectedDate.day == now.day;

      if (isToday && vm.allSlots.isNotEmpty) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Next-day slots (until 4 AM) belong to current date | Time: ${_getCurrentTimeFormatted()}',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  List<SlotModel> _getDisplaySlots(SlotViewModel vm) {
    final selectedDate = vm.dates[vm.selectedDateIndex.value];
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    if (!isToday) {
      return vm.allSlots;
    }

    final currentTimeMinutes = now.hour * 60 + now.minute;

    return vm.allSlots.where((slot) {
      if (slot.isNextDay) {
        return true;
      }

      try {
        int endHour = 0;
        int endMinute = 0;
        final endParts = slot.endTime.split(':');
        endHour = int.parse(endParts[0]);
        endMinute = int.parse(endParts[1]);

        int slotEndMinutes = (endHour == 0 && endMinute == 0)
            ? 1440
            : endHour * 60 + endMinute;
        return slotEndMinutes > currentTimeMinutes;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Widget _buildSlotGrid(BuildContext context, SlotViewModel vm, int crossCount, double timeFontSize) {
    if (vm.isLoadingSlots.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final displaySlots = _getDisplaySlots(vm);

    if (displaySlots.isEmpty) {
      return _buildEmptyState(context, vm);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: displaySlots.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        childAspectRatio: 1.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        final slot = displaySlots[i];
        return _buildSlotCard(slot, vm, timeFontSize);
      },
    );
  }

  Widget _buildSlotCard(SlotModel slot, SlotViewModel vm, double timeFontSize) {
    final isAvailable = slot.isAvailable;
    final isBooked = slot.isBooked;
    final isReserved = slot.isReserved;
    final isBlocked = slot.status == 'Blocked' || slot.isUnavailable;

    final bool isNextDaySlot = slot.isNextDay;
    final String formattedPrice = slot.formattedPrice;

    return Obx(() {
      final isSelected = vm.selectedSlots.contains(slot);
      final canSelect = vm.canSelectSlot(slot);

      Color backgroundColor;
      Color borderColor;
      Color textColor;
      String statusText = "";

      if (isNextDaySlot && isAvailable && !isSelected) {
        backgroundColor = Colors.purple.shade50;
        borderColor = Colors.purple;
        textColor = Colors.purple.shade800;
        statusText = "NEXT DAY";
      }
      else if (isSelected && isAvailable) {
        backgroundColor = Colors.green;
        borderColor = Colors.green;
        textColor = Colors.white;
      }
      else if (isAvailable) {
        backgroundColor = Colors.white;
        borderColor = Colors.green;
        textColor = Colors.black;
      }
      else if (isBlocked) {
        backgroundColor = Colors.grey.shade300;
        borderColor = Colors.grey.shade500;
        textColor = Colors.grey.shade700;
        statusText = "Blocked";
      }
      else if (isReserved) {
        backgroundColor = Colors.orange.shade100;
        borderColor = Colors.orange;
        textColor = Colors.orange.shade800;
        statusText = "Reserved";
      }
      else if (isBooked) {
        backgroundColor = Colors.red;
        borderColor = Colors.red;
        textColor = Colors.white;
        statusText = "Booked";
      }
      else {
        backgroundColor = Colors.grey.shade200;
        borderColor = Colors.grey.shade300;
        textColor = Colors.grey.shade500;
        statusText = "N/A";
      }

      return GestureDetector(
        onTap: (isAvailable && !isBlocked && canSelect) ? () => vm.toggleSlot(slot) : null,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isNextDaySlot && isAvailable && !isSelected
                ? [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 4)]
                : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      slot.formattedTimeRange,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: isSelected && isAvailable
                            ? FontWeight.bold
                            : (isNextDaySlot ? FontWeight.w600 : FontWeight.normal),
                        color: textColor,
                        fontSize: timeFontSize - 1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (statusText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: isNextDaySlot && isAvailable && !isSelected
                            ? Colors.purple
                            : (isBlocked ? Colors.grey.shade500 : textColor.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: isNextDaySlot && isAvailable && !isSelected
                              ? Colors.white
                              : (isBlocked ? Colors.grey.shade800 : textColor),
                        ),
                      ),
                    ),
                  if (slot.price != '0' && isAvailable && !isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '₹$formattedPrice',
                        style: TextStyle(
                          fontSize: 7,
                          color: isNextDaySlot ? Colors.purple.shade600 : Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState(BuildContext context, SlotViewModel vm) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text("No slots available", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 6),
              Obx(() {
                final selectedDate = vm.dates[vm.selectedDateIndex.value];
                final now = DateTime.now();
                final isToday = selectedDate.year == now.year &&
                    selectedDate.month == now.month &&
                    selectedDate.day == now.day;
                if (isToday) {
                  return const Text(
                    'All slots may have passed. Next-day slots are shown with purple color.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => vm.refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text("Refresh Slots", style: TextStyle(fontSize: 12,color: Colors.white),),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ BOTTOM BAR - Always shows "Proceed to Pay"
  // ============================================================
  Widget _buildBottomBar(BuildContext context, SlotViewModel vm, TurfModel turf, double width, bool isGuest) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Obx(
                      () => GestureDetector(
                    onTap: () {
                      print('🟠 Advance Payment Selected');
                      vm.selectedPaymentType.value = 'advance';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: vm.selectedPaymentType.value == 'advance'
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: vm.selectedPaymentType.value == 'advance'
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Advance Payment",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: vm.selectedPaymentType.value == 'advance'
                                  ? Colors.green
                                  : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "₹${vm.requiredAdvance.toStringAsFixed(vm.requiredAdvance == vm.requiredAdvance.toInt() ? 0 : 2)}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: vm.selectedPaymentType.value == 'advance'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          Text(
                            vm.turf.getAdvanceDisplayText(),
                            style: TextStyle(
                              fontSize: 9,
                              color: vm.selectedPaymentType.value == 'advance'
                                  ? Colors.green.shade600
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(
                      () => GestureDetector(
                    onTap: () {
                      print('🔵 Full Payment Selected');
                      vm.selectedPaymentType.value = 'full';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: vm.selectedPaymentType.value == 'full'
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: vm.selectedPaymentType.value == 'full'
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Full Payment",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: vm.selectedPaymentType.value == 'full'
                                  ? Colors.green
                                  : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            "₹${vm.totalPrice.toStringAsFixed(vm.totalPrice == vm.totalPrice.toInt() ? 0 : 2)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: vm.selectedPaymentType.value == 'full'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(() {
            if (!vm.isMinSlotsMet && vm.selectedSlots.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Need ${turf.minSlots - vm.selectedSlots.length} more slot(s)',
                          style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(
                        () => Text(
                      "Pay: ₹${vm.getPayableAmount.toStringAsFixed(vm.getPayableAmount == vm.getPayableAmount.toInt() ? 0 : 2)}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  Obx(
                        () => Text(
                      "Slots selected: ${vm.selectedSlots.length} (Min: ${turf.minSlots})",
                      style: const TextStyle(color: Colors.blue, fontSize: 11),
                    ),
                  ),
                  Obx(
                        () => Text(
                      "Total: ₹${vm.totalPrice.toStringAsFixed(vm.totalPrice == vm.totalPrice.toInt() ? 0 : 2)}",
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Obx(
                    () => GestureDetector(
                  onTap: vm.selectedSlots.isEmpty || !vm.isMinSlotsMet
                      ? null
                      : () => _proceedToPay(context, vm, turf, isGuest),
                  child: Container(
                    width: width * 0.45,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: vm.selectedSlots.isEmpty || !vm.isMinSlotsMet
                          ? Colors.grey
                          : Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        "Proceed to Pay",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: width > 600 ? 14 : 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isGuest)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '🔒 You will be asked to sign up before payment',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ PROCEED TO PAY - With duplicate prevention
  // ============================================================
  void _proceedToPay(BuildContext context, SlotViewModel vm, TurfModel turf, bool isGuest) {
    // ✅ Prevent multiple calls
    if (_isProceedingToPay) {
      print('⏭️ Already proceeding to pay - skipping duplicate');
      return;
    }

    final selectedPaymentType = vm.selectedPaymentType.value;
    final totalAmount = vm.totalPrice;
    final requiredAdvance = vm.requiredAdvance;

    double payableAmount;
    if (selectedPaymentType == 'advance') {
      payableAmount = requiredAdvance;
    } else {
      payableAmount = totalAmount;
    }

    final selectedSlots = vm.selectedSlots.toList();
    final selectedCourt = vm.selectedCourt.value + 1;
    final selectedDate = vm.dates[vm.selectedDateIndex.value];

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  🔍 PROCEEDING TO PAY - Guest Mode: $isGuest               ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('   📌 Payment Type: "$selectedPaymentType"');
    print('   💰 Total Amount: ₹$totalAmount');
    print('   💵 Payable Amount: ₹$payableAmount');
    print('   📅 Date: ${selectedDate.toIso8601String().split('T').first}');
    print('   🏟️ Turf: ${turf.name}');
    print('   📋 Slots Selected: ${selectedSlots.length}');
    print('═══════════════════════════════════════════════════════════════\n');

    final bookingData = {
      'turf': turf,
      'selectedSlots': selectedSlots,
      'selectedCourt': selectedCourt,
      'selectedDate': selectedDate,
      'selectedPaymentType': selectedPaymentType,
      'totalAmount': totalAmount,
      'payableAmount': payableAmount,
      'requiredAdvance': requiredAdvance,
    };

    // ✅ Set flag to prevent duplicate calls
    _isProceedingToPay = true;

    // ✅ If guest, show the signup+OTP dialog ON TOP of this SlotView
    if (isGuest) {
      print('👤 Guest user - Showing signup/OTP dialog');
      showGuestBookingAuthDialog(
        bookingData: bookingData,
        onSuccess: () {
          // ✅ Reset flag
          _isProceedingToPay = false;
          // ✅ Navigate to booking summary
          Get.toNamed(
            AppRoutes.bookingSummary,
            arguments: bookingData,
          );
        },
      ).whenComplete(() {
        // ✅ Reset flag if dialog is closed without success (e.g., user pressed back)
        _isProceedingToPay = false;
      });
      return;
    }

    // ✅ Logged-in user - Go directly to summary
    Get.toNamed(
      AppRoutes.bookingSummary,
      arguments: bookingData,
    );
    // ✅ Reset flag after navigation
    _isProceedingToPay = false;
  }

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showCourtSheet(BuildContext context, SlotViewModel vm, String courtTurfLabel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(
              "Select $courtTurfLabel",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: vm.courtCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (_, i) {
                  return Obx(() {
                    final isSelected = vm.selectedCourt.value == i;
                    return GestureDetector(
                      onTap: () {
                        vm.selectCourt(i);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.green : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Colors.green : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "$courtTurfLabel ${i + 1}",
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color bgColor, Color borderColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1.2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}