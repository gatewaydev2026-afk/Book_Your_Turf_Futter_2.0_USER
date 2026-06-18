import 'dart:async';
import 'package:get/get.dart';
import '../view_models/home_view_model.dart';
import '../view_models/booking_view_model.dart';
import '../view_models/profile_view_model.dart';

class AutoRefreshService extends GetxService {
  Timer? _timer;
  bool _isRunning = false;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      print('Auto-refresh triggered');
      if (Get.isRegistered<HomeViewModel>()) {
        await Get.find<HomeViewModel>();
      }
      if (Get.isRegistered<BookingViewModel>()) {
        await Get.find<BookingViewModel>().fetch();
      }
      if (Get.isRegistered<ProfileViewModel>()) {
        await Get.find<ProfileViewModel>().refresh();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}