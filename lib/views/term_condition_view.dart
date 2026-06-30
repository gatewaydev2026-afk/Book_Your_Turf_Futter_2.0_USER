import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/app_colors.dart';

class TermConditionView extends StatelessWidget {
  const TermConditionView({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isTablet = screenWidth > 600;
    double horizontalPadding = isTablet ? screenWidth * 0.15 : 20.0;

    double titleFontSize = isTablet ? 32 : 28;
    double headerFontSize = isTablet ? 22 : 20;
    double sectionTitleFontSize = isTablet ? 20 : 18;
    double bodyFontSize = isTablet ? 16 : 14;
    double subTextFontSize = isTablet ? 16 : 15;
    double companyFontSize = isTablet ? 16 : 14;
    double ownedByFontSize = isTablet ? 13 : 12;

    return Scaffold(
      // ✅ Pinned AppBar — header never scrolls away
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Terms & Conditions',
          style: TextStyle(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
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
            opacity: 0.2,
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Big title inside scroll (decorative)
                    Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // ✅ Underline starts from left edge — no offset margin
                    Container(
                      height: 4,
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 25),
                    _buildHeader("Welcome to Book Your Turf", headerFontSize),
                    Text(
                      "The online platform that helps you easily book your sports venues for Box Cricket, Football, Badminton & more.",
                      style: TextStyle(
                        fontSize: subTextFontSize,
                        height: 1.5,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildSection("Booking Policy", [
                      "Bookings are confirmed based on advance / full payment.",
                      "Valid only for the selected time slot & date.",
                      "Arrive 10–15 minutes before the slot time.",
                      "Playtime starts and ends as per the allotted schedule.",
                    ], sectionTitleFontSize, bodyFontSize),
                    _buildSection("Payment Terms", [
                      "Payments must be made through our secure gateway.",
                      "Prices include applicable taxes and convenience charges.",
                      "We are not responsible for network-related payment failures.",
                    ], sectionTitleFontSize, bodyFontSize),
                    _buildSection("Cancellation & Refund", [
                      "Cancellation is NOT allowed for bookings made within 6 hours of the slot start time (instant bookings).",
                      "For advance bookings (made more than 6 hours before slot time), cancellation is allowed up to 6 hours before the start time.",
                      "No cancellation charges apply for eligible cancellations.",
                      "Upon successful cancellation, the full money will be credited to your wallet as refund credits.",
                      "Wallet credits can be used for future bookings and have no expiry date.",
                      "Refund credits will be processed instantly to your wallet upon cancellation confirmation.",
                      "Once booked, if you do not show up or fail to play, no refund or wallet credit will be provided.",
                    ], sectionTitleFontSize, bodyFontSize),
                    _buildSection("User Responsibilities", [
                      "Follow venue rules (dress code, footwear, etc.).",
                      "Damage to property (nets, lights, grass) will be charged.",
                      "Alcohol, smoking, or abusive behavior is strictly prohibited.",
                    ], sectionTitleFontSize, bodyFontSize),
                    _buildSection("Liability Disclaimer", [
                      "Book Your Turf is a platform; we are not liable for on-ground injuries.",
                      "Venue management is responsible for safety and maintenance.",
                    ], sectionTitleFontSize, bodyFontSize),
                    _buildSection("Wallet Credits Policy", [
                      "Wallet credits are non-transferable to other accounts.",
                      "Credits cannot be withdrawn as cash - only usable for bookings.",
                      "Credits will be automatically applied to your next booking.",
                      "In case of disputes, the decision of Book Your Turf management will be final.",
                    ], sectionTitleFontSize, bodyFontSize),
                    const Divider(height: 60, thickness: 1),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Owned by',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: ownedByFontSize,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "NOTTAM INFOTECH PRIVATE LIMITED",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Balloon',
                              fontWeight: FontWeight.bold,
                              fontSize: companyFontSize,
                              letterSpacing: 1.1,
                              color: AppColors.primary,
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

  Widget _buildSection(String title, List<String> points,
      double sectionTitleFontSize, double bodyFontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: sectionTitleFontSize,
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
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      point.startsWith('❌') ? Icons.cancel :
                      point.startsWith('✅') ? Icons.check_circle :
                      point.startsWith('💰') ? Icons.attach_money :
                      point.startsWith('💳') ? Icons.account_balance_wallet :
                      point.startsWith('⏱️') ? Icons.timer :
                      point.startsWith('🔄') ? Icons.refresh :
                      point.startsWith('🚫') ? Icons.block :
                      Icons.circle,
                      size: point.startsWith('❌') || point.startsWith('✅') ||
                          point.startsWith('💰') || point.startsWith('💳') ||
                          point.startsWith('⏱️') || point.startsWith('🔄') ||
                          point.startsWith('🚫') ? 16 : 6,
                      color: point.startsWith('❌') ? Colors.red :
                      point.startsWith('✅') ? Colors.green :
                      point.startsWith('💰') ? Colors.orange :
                      point.startsWith('💳') ? Colors.blue :
                      point.startsWith('⏱️') ? Colors.purple :
                      point.startsWith('🔄') ? Colors.teal :
                      point.startsWith('🚫') ? Colors.red :
                      Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _stripLeadingEmoji(point),
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        height: 1.5,
                        color: Colors.grey[800],
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

  String _stripLeadingEmoji(String point) {
    final prefixes = ['❌ ', '✅ ', '💰 ', '💳 ', '⏱️ ', '🔄 ', '🚫 ',
      '❌', '✅', '💰', '💳', '⏱️', '🔄', '🚫', '️ '];
    for (final prefix in prefixes) {
      if (point.startsWith(prefix)) {
        return point.substring(prefix.length).trim();
      }
    }
    return point;
  }

  Widget _buildHeader(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
          color: Colors.black87,
        ),
      ),
    );
  }
}