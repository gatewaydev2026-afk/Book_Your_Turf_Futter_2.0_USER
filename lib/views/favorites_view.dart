// views/favorites_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../view_models/home_view_model.dart';
import '../widgets/turf_card.dart';
import '../routes/app_routes.dart';
import '../view_models/main_page_view_model.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeViewModel homeVm = Get.find<HomeViewModel>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final isTablet = screenWidth > 600;

    // Responsive values
    final int crossAxisCount = isTablet ? 3 : (isSmallScreen ? 1 : 2);
    final double childAspectRatio = isTablet ? 0.72 : (isSmallScreen ? 1.1 : 0.75);
    final double gridPadding = isTablet ? 20 : 12;
    final double crossAxisSpacing = isTablet ? 16 : 12;
    final double mainAxisSpacing = isTablet ? 16 : 12;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "My Favorites",
          style: TextStyle(
            color: Colors.black,
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Obx(() {
        final favorites = homeVm.getFavoritedTurfs();

        if (homeVm.isLoading.value && favorites.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        if (favorites.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? screenWidth * 0.2 : 32,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/lottie/no.json',
                    height: isTablet ? 200 : 150,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "No Favorite Turfs",
                    style: TextStyle(
                      fontSize: isTablet ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Tap the ♥ heart icon on any turf to save it here",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isTablet ? 15 : 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: isTablet ? 220 : double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        Get.find<MainPageViewModel>().changeTab(0);
                      },
                      icon: const Icon(Icons.explore, color: Colors.white, size: 18),
                      label: Text(
                        "Browse Turfs",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Count header
            Padding(
              padding: EdgeInsets.fromLTRB(gridPadding, 14, gridPadding, 4),
              child: Text(
                "${favorites.length} Saved ${favorites.length == 1 ? 'Turf' : 'Turfs'}",
                style: TextStyle(
                  fontSize: isTablet ? 15 : 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(gridPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) => TurfCard(favorites[index]),
              ),
            ),
          ],
        );
      }),
    );
  }
}