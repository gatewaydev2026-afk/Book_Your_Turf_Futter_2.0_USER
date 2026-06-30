// widgets/turf_card.dart - RenderFlex Overflow Fixed

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/turf_model.dart';
import '../view_models/home_view_model.dart';
import '../routes/app_routes.dart';

class TurfCard extends StatelessWidget {
  final TurfModel turf;
  const TurfCard(this.turf, {super.key});

  void _handleTap() {
    Get.toNamed(AppRoutes.turfDetail, arguments: turf);
  }

  Future<void> _handleFavoriteTap() async {
    final homeVm = Get.find<HomeViewModel>();
    await homeVm.toggleFavorite(turf.id);
  }

  @override
  Widget build(BuildContext context) {
    final homeVm = Get.find<HomeViewModel>();
    final isFavorited = homeVm.isFavorite(turf.id);

    final latestTurf = homeVm.allTurfs.firstWhere(
          (t) => t.id == turf.id,
      orElse: () => turf,
    );

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // ✅ Column fills the grid cell — no mainAxisSize: min
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Section ──────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                height: 130, // ✅ Reduced from 150 → gives content more room
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    latestTurf.images.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: latestTurf.images[0],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) =>
                          Container(color: Colors.grey[200]),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 30,
                        ),
                      ),
                    )
                        : Container(
                      color: Colors.grey[200],
                      child:
                      const Icon(Icons.sports_soccer, size: 30),
                    ),

                    // Verified badge
                    if (latestTurf.showVerifiedBadge)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.green,
                          ),
                        ),
                      ),

                    // Favourite button
                    if (latestTurf.isBookable)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: GestureDetector(
                          onTap: _handleFavoriteTap,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorited
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                              isFavorited ? Colors.red : Colors.grey,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                    // Enquiry badge
                    if (!latestTurf.isBookable)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Enquiry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Content Section ────────────────────────────────────
            // ✅ Expanded fills remaining height → no overflow
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Turf name
                    Text(
                      latestTurf.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Address
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 9,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            "${latestTurf.address.split(',').length > 1 ? latestTurf.address.split(',')[1].trim() : latestTurf.address}, "
                                "${latestTurf.district}",
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Distance (conditional)
                    if (latestTurf.showVerifiedBadge &&
                        homeVm.currentLocation.value != null &&
                        latestTurf.latitude != null &&
                        latestTurf.longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              size: 9,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                homeVm.getDistanceString(latestTurf),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.green.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Game type chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        latestTurf.gameType.isNotEmpty
                            ? latestTurf.gameType
                            : 'Contact',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.green.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // ✅ Spacer pushes button to bottom of Expanded area
                    const Spacer(),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: _handleTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: latestTurf.isBookable
                              ? Colors.green
                              : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 26),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              latestTurf.isBookable
                                  ? Icons.calendar_today
                                  : Icons.info,
                              size: 9,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              latestTurf.isBookable
                                  ? 'Book Now'
                                  : 'View Details',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}