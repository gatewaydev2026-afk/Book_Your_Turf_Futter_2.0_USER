import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AboutUsView extends StatelessWidget {
  final String appName = "Book Your Turf";
  final String version = "2.0";

  const AboutUsView({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double horizontalPadding = screenWidth > 600 ? screenWidth * 0.15 : 20.0;

    return Scaffold(
      // ✅ Pinned AppBar — always visible, never scrolls away
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          "App Info",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
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
          top: false, // AppBar handles top safe area
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
                  children: [
                    // Logo
                    Image.asset(
                      'assets/logo.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      'Version $version',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Our Mission",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Book Your Turf is a smart and modern sports booking app designed for players, teams, and sports enthusiasts who want quick, easy, and reliable access to nearby sports venues. The app helps you discover sports courts, grounds, turfs, and arenas around you — with real-time availability, transparent pricing, and instant online booking.",
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.grey[850],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Whether you play Football, Box Cricket, Badminton, Futsal and soon Tennis, Pickle Ball, Basketball, Skating, Billiards, Swimming, or any other indoor/outdoor sport — Book Your Turf helps you find and book the perfect spot, slot and sport in seconds.",
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.grey[850],
                          ),
                        ),
                        const SizedBox(height: 25),
                        _buildFeatureBox(
                          title: "Secure Payments",
                          content:
                          "To make the experience even smoother, Book Your Turf offers easy-access payment options including GPay, PhonePe, UPI QR, and Cards.",
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      'Owned by',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "NOTTAM INFOTECH PRIVATE LIMITED",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Balloon',
                        fontSize: 14,
                        color: Color(0xFF387135),
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

  Widget _buildFeatureBox({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}