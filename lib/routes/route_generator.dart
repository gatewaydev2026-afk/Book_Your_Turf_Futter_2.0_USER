// route_generator.dart - Fix registerWithBooking route

import 'package:get/get.dart';
import '../services/notification_service.dart';
import '../views/booking_summary_view.dart';
import '../views/demoview/GuestOrLoginView.dart';
import '../views/demoview/signup_with_booking_view.dart';
import '../views/notification_view.dart';
import '../views/splash_view.dart';
import '../views/login_view.dart' hide HomeView;
import '../views/signup_view.dart';
import '../views/forgot_password_view.dart';
import '../views/otp_verification_view.dart';
import '../views/reset_password_view.dart';
import '../views/home_view.dart';
import '../views/main_page.dart';
import '../views/booking_history_view.dart';
import '../views/profile_view.dart';
import '../views/turf_details_view.dart';
import '../views/slot_view.dart';
import '../views/term_condition_view.dart';
import '../views/privacy_policy_view.dart';
import '../views/about_us_view.dart';
import '../views/favorites_view.dart';
import 'app_routes.dart';

class RouteGenerator {
  static List<GetPage> routes = [
    GetPage(name: AppRoutes.splash, page: () => const SplashView()),
    GetPage(name: AppRoutes.guestOrLogin, page: () => const GuestOrLoginView()),
    GetPage(name: AppRoutes.bookingSummary, page: () => BookingSummaryView()),
    GetPage(name: AppRoutes.login, page: () => const LoginView(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.register, page: () => const SignupView(), transition: Transition.rightToLeft),
    // ✅ FIXED: registerWithBooking now
    //   1) reads the REAL bookingData (turf + selected slots) from Get.arguments
    //      instead of always sending an empty map,
    //   2) on successful OTP verify + login, REPLACES this page with
    //      Get.offNamed(...) so it's removed from the stack — this means
    //      the OTP screen can never reappear when the user presses back
    //      from Booking Summary,
    //   3) if this route is ever opened without valid booking data (no
    //      turf/slots in the stack below), it falls back to MainPage
    //      instead of leaving the user stranded.
    GetPage(
      name: AppRoutes.registerWithBooking,
      page: () {
        final args = Get.arguments;
        final Map<String, dynamic> bookingData =
        (args is Map<String, dynamic>) ? args : <String, dynamic>{};
        final bool hasValidBooking = bookingData.containsKey('turf') &&
            bookingData.containsKey('selectedSlots');

        return GuestBookingAuthDialog(
          bookingData: bookingData,
          onSuccess: () {
            if (hasValidBooking) {
              // ✅ Same slot selection carried forward; SlotView (if it's
              // below this route in the stack) stays untouched, so back
              // from Booking Summary lands on it with the slots intact.
              Get.offNamed(AppRoutes.bookingSummary, arguments: bookingData);
            } else {
              // ✅ No slot view / booking context to return to.
              Get.offAllNamed(AppRoutes.mainPage);
            }
          },
        );
      },
      transition: Transition.rightToLeft,
    ),
    GetPage(name: AppRoutes.forgotPassword, page: () => const ForgotPasswordView(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.otpVerification, page: () => const OtpVerificationView()),
    GetPage(name: AppRoutes.home, page: () => HomeView()),
    GetPage(name: AppRoutes.mainPage, page: () => MainPage()),
    GetPage(name: AppRoutes.bookingHistory, page: () => BookingHistoryView()),
    GetPage(name: AppRoutes.profile, page: () => ProfileView()),
    GetPage(name: AppRoutes.turfDetail, page: () => const TurfDetailsView()),
    // ✅ SlotView - Ensure proper argument passing
    GetPage(
      name: AppRoutes.slotSelection,
      page: () => SlotView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(name: AppRoutes.termAndCondition, page: () => const TermConditionView()),
    GetPage(name: AppRoutes.privacyPolicy, page: () => const PrivacyPolicyView()),
    GetPage(name: AppRoutes.aboutUs, page: () => const AboutUsView()),
    GetPage(name: AppRoutes.favorites, page: () => FavoritesView()),
    GetPage(
      name: AppRoutes.notifications,
      page: () => NotificationScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<NotificationService>()) {
          Get.put(NotificationService());
        }
      }),
    ),
  ];
}