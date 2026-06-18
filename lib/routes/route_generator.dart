import 'package:get/get.dart';
import '../services/notification_service.dart';
import '../views/booking_summary_view.dart';
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
    GetPage(name: AppRoutes.bookingSummary, page: () =>  BookingSummaryView()),
    GetPage(name: AppRoutes.login, page: () => const LoginView(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.register, page: () => const SignupView(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.forgotPassword, page: () => const ForgotPasswordView(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.otpVerification, page: () => const OtpVerificationView()),
    // GetPage(name: AppRoutes.resetPassword, page: () => const ResetPasswordView()),
    GetPage(name: AppRoutes.home, page: () => HomeView()),
    GetPage(name: AppRoutes.mainPage, page: () => MainPage()),
    GetPage(name: AppRoutes.bookingHistory, page: () => BookingHistoryView()),
    GetPage(name: AppRoutes.profile, page: () => ProfileView()),
    GetPage(name: AppRoutes.turfDetail, page: () => const TurfDetailsView()),
    GetPage(name: AppRoutes.slotSelection, page: () => SlotView()),
    GetPage(name: AppRoutes.termAndCondition, page: () => const TermConditionView()),
    GetPage(name: AppRoutes.privacyPolicy, page: () => const PrivacyPolicyView()),
    GetPage(name: AppRoutes.aboutUs, page: () => const AboutUsView()),
    GetPage(name: AppRoutes.favorites, page: () => FavoritesView()),
    GetPage(
      name: AppRoutes.notifications,
      page: () => const NotificationScreen(),
      binding: BindingsBuilder(() {
        if (!Get.isRegistered<NotificationService>()) {
          Get.put(NotificationService());
        }
      }),
    ),

  ];
}