// views/favorites_view.dart
// ✅ Complete as per API documentation
// ✅ Uses Get.find<FavoritesViewModel>() - registered in main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../models/turf_model.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/home_view_model.dart';
import '../widgets/turf_card.dart';
import '../routes/app_routes.dart';
import '../view_models/main_page_view_model.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Use Get.find() - ViewModel is registered in main.dart
    final FavoritesViewModel favVm = Get.find<FavoritesViewModel>();
    final HomeViewModel homeVm = Get.find<HomeViewModel>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final isTablet = screenWidth > 600;

    // ✅ Load favorites when screen opens (lazy loading)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      favVm.loadFavorites();
    });

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
        actions: [
          // ✅ Refresh button
          Obx(() => IconButton(
            icon: favVm.isLoading.value
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green,
              ),
            )
                : const Icon(Icons.refresh, color: Colors.green),
            onPressed: favVm.isLoading.value ? null : () => favVm.refreshFavorites(),
            tooltip: 'Refresh',
          )),
        ],
      ),
      body: Obx(() {
        // ✅ Loading State
        if (favVm.isLoading.value && favVm.favorites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'Loading your favorites...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // ✅ Error State
        if (favVm.errorMessage.value.isNotEmpty && favVm.favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Failed to load favorites',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  favVm.errorMessage.value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => favVm.refreshFavorites(),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ✅ Empty State
        if (favVm.favorites.isEmpty) {
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

        // ✅ Favorites List
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Count header
            Padding(
              padding: EdgeInsets.fromLTRB(gridPadding, 14, gridPadding, 4),
              child: Row(
                children: [
                  Text(
                    "${favVm.favorites.length} Saved ${favVm.favorites.length == 1 ? 'Turf' : 'Turfs'}",
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // ✅ Show discount count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${favVm.favorites.where((t) => t.bestDiscountLabel != null && t.bestDiscountLabel!.isNotEmpty).length} with offers',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => favVm.refreshFavorites(),
                color: Colors.green,
                child: GridView.builder(
                  padding: EdgeInsets.all(gridPadding),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: mainAxisSpacing,
                  ),
                  itemCount: favVm.favorites.length,
                  itemBuilder: (context, index) {
                    final turf = favVm.favorites[index];
                    // ✅ Ensure isFavorite is true for favorites list
                    final turfWithFavorite = turf.copyWith(isFavorite: true);
                    return TurfCard(turfWithFavorite);
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}