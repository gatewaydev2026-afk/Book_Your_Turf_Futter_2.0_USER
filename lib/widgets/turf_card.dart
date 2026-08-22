// widgets/turf_card.dart - Fixed to show City, District, State

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

class _TurfCardState extends State<TurfCard> {
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

    // ✅ Split label at "+"
    String mainLabel = discountLabel;
    String extraLabel = '';
    if (discountLabel.contains('+')) {
      final idx = discountLabel.indexOf('+');
      mainLabel = discountLabel.substring(0, idx).trim();
      extraLabel = discountLabel.substring(idx + 1).trim();
      if (mainLabel.isEmpty) {
        mainLabel = extraLabel;
        extraLabel = '';
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    // ✅ Check if this is a search result
    final isSearchResult = homeVm.searchQuery.value.isNotEmpty;
    final distance = latestTurf.distanceKm ?? 0;
    final isFarAway = distance > 25.0;

    // ✅ Get the CORRECT location to display - Show City, District, State
    String locationDisplay = '';

    // Extract city from address
    String city = '';
    final addressParts = latestTurf.address.split(',');
    if (addressParts.length >= 2) {
      // City is usually the second part from the end or second part
      if (addressParts.length >= 3) {
        city = addressParts[addressParts.length - 3]?.trim() ?? '';
      } else if (addressParts.length >= 2) {
        city = addressParts[1]?.trim() ?? '';
      }
    }

    // If city is empty, try to use district
    if (city.isEmpty || city == 'India') {
      city = latestTurf.district.isNotEmpty && latestTurf.district != 'null'
          ? latestTurf.district
          : '';
    }

    String district = latestTurf.district.isNotEmpty && latestTurf.district != 'null'
        ? latestTurf.district
        : '';

    String state = latestTurf.state.isNotEmpty && latestTurf.state != 'null'
        ? latestTurf.state
        : '';

    // Build location from City, District, State
    List<String> parts = [];

    // Add City (if available and not same as district)
    if (city.isNotEmpty && city != district && city != state) {
      parts.add(city);
    }

    // Add District (if available)
    if (district.isNotEmpty) {
      parts.add(district);
    }

    // Add State (if available and not same as district)
    if (state.isNotEmpty && district != state) {
      parts.add(state);
    }

    // If we have no parts, use the address or district
    if (parts.isEmpty) {
      if (district.isNotEmpty) {
        parts.add(district);
      }
      if (state.isNotEmpty && district != state) {
        parts.add(state);
      }
    }

    locationDisplay = parts.isNotEmpty ? parts.join(', ') : latestTurf.address;

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

                    // Subtle bottom scrim for badge legibility
                    if (mainLabel.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 46,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.0),
                                Colors.black.withOpacity(0.28),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ✅ CHANGED: Verified badge replaced with image overlay
                    // Now shows an image icon in the top-right position
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      child:  Image.asset(
                            // 🔁 Replace this URL with your actual image URL
                            'assets/images/blue.jpeg',
                            fit: BoxFit.fill,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
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

                    // Discount badge
                    if (mainLabel.isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        right: 8,
                        child: _DiscountBadge(
                          mainLabel: mainLabel,
                          extraLabel: extraLabel,
                          isSmallScreen: isSmallScreen,
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

                    // ✅ Location - Show City, District, State
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
                            locationDisplay.isNotEmpty ? locationDisplay : latestTurf.district,
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

                    // ✅ Distance - Always show
                    if (homeVm.currentLocation.value != null &&
                        latestTurf.latitude != null &&
                        latestTurf.longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              isFarAway ? Icons.flight_takeoff : Icons.directions_walk,
                              size: 10,
                              color: isFarAway ? Colors.orange.shade600 : Colors.green.shade600,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                homeVm.getDistanceString(latestTurf),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isFarAway ? Colors.orange.shade600 : Colors.green.shade600,
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

// ── Discount Badge Widget ──────────────────────────────────────────────
// A compact, professional offer tag — replaces the old animated gold
// ribbon. Sits as a translucent gradient strip along the bottom of the
// image so it never overpowers the photo, with an optional secondary
// chip for a second offer (e.g. "10% OFF" + "First booking").
class _DiscountBadge extends StatelessWidget {
  final String mainLabel;
  final String extraLabel;
  final bool isSmallScreen;

  const _DiscountBadge({
    required this.mainLabel,
    required this.extraLabel,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 9,
              vertical: isSmallScreen ? 4 : 5,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFEF6C00)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sell_rounded,
                  size: isSmallScreen ? 10 : 11,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    mainLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 9.5 : 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (extraLabel.isNotEmpty) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 6 : 7,
                vertical: isSmallScreen ? 3.5 : 4.5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                extraLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 8 : 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}