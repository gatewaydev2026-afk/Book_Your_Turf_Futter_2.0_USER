import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PrivacyPolicyViewWidget extends StatelessWidget {
  const PrivacyPolicyViewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double horizontalPadding =
        screenWidth > 600 ? screenWidth * 0.15 : 20.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                  const SizedBox(width: 5),
                  const Text(
                    "Privacy Policy",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              _buildSection("Information We Collect", [
                "Full Name",
                "Email Address",
                "Phone Number",
                "Profile details (if provided)",
                "Turf bookings and schedules",
                "Payment details processed through secure third-party payment gateways",
                "Transaction history",
                "Approximate or precise location for nearby turf suggestions",
                "Device type, operating system, app usage statistics, and log data",
              ]),

              _buildSection("How We Use Your Information", [
                "To provide and maintain our services",
                "To process bookings and payments securely",
                "To display nearby sports venues and availability",
                "To send booking confirmations and reminders",
                "To improve app functionality and user experience",
                "To provide customer support",
              ]),

              _buildSection("Payment Information", [
                "Google Pay (GPay)",
                "PhonePe",
                "UPI Payments",
                "Debit/Credit Cards",
                "Netbanking",
                "We do not store sensitive payment details.",
              ]),

              _buildSection("Data Security", [
                "Encryption and secure communication protocols",
                "Restricted data access controls",
                "Regular system monitoring",
              ]),

              _buildSection("User Rights & Control", [
                "Access personal data",
                "Update or correct information",
                "Opt out of marketing communications",
                "Delete account directly from the application",
              ]),

              _buildSection("Contact Us", [
                "Email: nottaminfotech@gmail.com",
                "Company Name: Book Your Turf",
              ]),

              const SizedBox(height: 40),

              
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 12),

          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
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