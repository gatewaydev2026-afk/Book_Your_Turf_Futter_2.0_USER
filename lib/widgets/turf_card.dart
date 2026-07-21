// widgets/turf_card.dart - With Responsive Lemon Yellow Blinking Discount Badge
// ✅ Added Discount Badge from API (best_discount_label)
// ✅ ONLY LEMON YELLOW color for discount badge
// ✅ Yellow blinking animation with clean label design
// ✅ NO extra symbols (arrow, offer icon removed)
// ✅ FULLY RESPONSIVE - shows complete text in one line
// ✅ Auto-adjusts font size based on text length
// ✅ RenderFlex Overflow Fixed

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/turf_model.dart';
import '../view_models/home_view_model.dart';
import '../routes/app_routes.dart';

class TurfCard extends StatefulWidget {
  final TurfModel turf;
  const TurfCard(this.turf, {super.key});

  @override
  State<TurfCard> createState() => _TurfCardState();
}

class _TurfCardState extends State<TurfCard> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeInOut,
      ),
    );

    _blinkController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  void _handleTap() {
    Get.toNamed(AppRoutes.turfDetail, arguments: widget.turf);
  }

  Future<void> _handleFavoriteTap() async {
    final homeVm = Get.find<HomeViewModel>();
    await homeVm.toggleFavorite(widget.turf.id);
  }

  @override
  Widget build(BuildContext context) {
    final homeVm = Get.find<HomeViewModel>();
    final isFavorited = homeVm.isFavorite(widget.turf.id);

    final latestTurf = homeVm.allTurfs.firstWhere(
          (t) => t.id == widget.turf.id,
      orElse: () => widget.turf,
    );

    String discountLabel = latestTurf.bestDiscountLabel ?? '';

    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Section ──────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                height: 120,
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
                      child: const Icon(Icons.sports_soccer, size: 30),
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
                              color: isFavorited ? Colors.red : Colors.grey,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                    // ✅ RESPONSIVE LEMON YELLOW BLINKING DISCOUNT BADGE
                    if (discountLabel.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0, // Allow full width
                        child: AnimatedBuilder(
                          animation: _blinkAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Opacity(
                                opacity: _blinkAnimation.value,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 10,
                                    vertical: isSmallScreen ? 3 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEB3B), // ✅ Pure Lemon Yellow
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFEB3B).withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: const Color(0xFFFFD600),
                                      width: 1.2,
                                    ),
                                  ),
                                  // Use ConstrainedBox to limit width and allow text to fit
                                  constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.6, // Max 60% of screen
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown, // Shrink text if needed
                                    child: Text(
                                      discountLabel,
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: isSmallScreen ? 8 : 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.white70,
                                            blurRadius: 3,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Enquiry badge
                    if (!latestTurf.isBookable)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
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
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Turf name
                    Text(
                      latestTurf.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Address
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 10,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            "${latestTurf.address.split(',').length > 1 ? latestTurf.address.split(',')[1].trim() : latestTurf.address}, "
                                "${latestTurf.district}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Distance
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
                              size: 10,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                homeVm.getDistanceString(latestTurf),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w500,
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
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        latestTurf.gameType.isNotEmpty
                            ? latestTurf.gameType
                            : 'Contact',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 4),

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
                            borderRadius: BorderRadius.circular(6),
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
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              latestTurf.isBookable
                                  ? 'Book Now'
                                  : 'View Details',
                              style: const TextStyle(
                                fontSize: 10,
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