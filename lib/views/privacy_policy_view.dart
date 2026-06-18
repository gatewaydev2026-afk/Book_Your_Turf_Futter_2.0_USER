import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/app_colors.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double horizontalPadding = screenWidth > 600 ? screenWidth * 0.15 : 20.0;

    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/byt-bg.png'),
            opacity: 0.3,
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(Icons.arrow_back_ios_new),
                        ),
                        const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.only(left: 10),
                      height: 4,
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      "Book Your Turf is committed to protecting your privacy. This policy explains how we handle your information.",
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.grey[800],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildSection("Information We Collect", [
                      "Personal: Name, Email, Phone Number, Profile details.",
                      "Booking: Turf schedules and Transaction history.",
                      "Location: To show nearby venues and turfs.",
                      "Device: OS type, app statistics, and IP address.",
                    ]),
                    _buildSection("How We Use Your Information", [
                      "To process bookings and secure payments.",
                      "To display nearby venues based on location.",
                      "To send booking confirmations and reminders.",
                      "To improve app experience and prevent fraud.",
                    ]),
                    _buildSection("Payment Security", [
                      "Supported: GPay, PhonePe, UPI, Cards, Netbanking.",
                      "We do NOT store sensitive payment details locally.",
                      "All transactions are processed via secure 3rd-party gateways.",
                    ]),
                    _buildSection("Data Sharing", [
                      "Shared only with Turf Owners (booking details only).",
                      "Shared with payment gateways for transactions.",
                      "We never sell, rent, or trade your personal data.",
                    ]),
                    _buildSection("User Rights", [
                      "Access and update your personal data anytime.",
                      "Opt-out of promotional notifications.",
                      "Directly delete your account from the app.",
                    ]),
                    const Divider(height: 60, thickness: 1),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            "CONTACT US",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Email: nottaminfotech@gmail.com",
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 15),
                          const Text('Owned by'),
                          const Text(
                            "NOTTAM INFOTECH PRIVATE LIMITED",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Balloon',
                              fontSize: 14,
                              color: Color(0xFF387135),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
