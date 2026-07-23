// widgets/turf_card.dart - Ribbon-Banner Style Discount Badge + Separate "+X" Badge
// ✅ Real ribbon-banner shape (chevron notch ends + folded tail) like reference image
// ✅ Splits best_discount_label on "+" -> main text on ribbon, "+X more" on its own badge below
// ✅ GOLD gradient ribbon with green border, dark-gold folded tail peeking underneath
// ✅ BOTTOM-CENTER POSITION, WITHIN CARD BOUNDARIES
// ✅ Blinking animation kept
// ✅ FULLY RESPONSIVE

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

    // ✅ Split label at "+" -> main ribbon text + separate extra-offer badge text
    String mainLabel = discountLabel;
    String extraLabel = '';
    if (discountLabel.contains('+')) {
      final idx = discountLabel.indexOf('+');
      mainLabel = discountLabel.substring(0, idx).trim();
      extraLabel = discountLabel.substring(idx + 1).trim(); // "+" character dropped
      if (mainLabel.isEmpty) {
        // label started with "+" (no leading text) -> nothing to split really
        mainLabel = extraLabel;
        extraLabel = '';
      }
    }

    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final ribbonWidth = (screenWidth / 2.6).clamp(110.0, 175.0);
    final ribbonHeight = isSmallScreen ? 20.0 : 22.0;

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

                    // ✅ RIBBON-BANNER DISCOUNT BADGE + SEPARATE "+X" BADGE (bottom-center)
                    if (mainLabel.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _blinkAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Opacity(
                                  opacity: _blinkAnimation.value,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _RibbonBanner(
                                        text: mainLabel,
                                        width: ribbonWidth,
                                        height: ribbonHeight,
                                        fontSize: isSmallScreen ? 8 : 9.5,
                                      ),
                                      if (extraLabel.isNotEmpty)
                                        Transform.translate(
                                          // slight overlap so it reads as "attached" to the first ribbon
                                          offset: const Offset(0, -4),
                                          child: _RibbonBanner(
                                            text: extraLabel,
                                            width: ribbonWidth * 0.82,
                                            height: ribbonHeight * 0.82,
                                            fontSize: isSmallScreen ? 7 : 8,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
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

// ─────────────────────────────────────────────────────────────────────────
// ✅ Ribbon-banner widget: gold gradient band with chevron-cut ends and a
// darker folded tail peeking below each side (matches classic ribbon badge look)
// ─────────────────────────────────────────────────────────────────────────
class _RibbonBanner extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final double fontSize;

  const _RibbonBanner({
    required this.text,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final notch = height * 0.5;
    return SizedBox(
      width: width,
      height: height + 7, // extra room for the folded tail peeking below
      child: CustomPaint(
        painter: _RibbonBannerPainter(bandHeight: height, notch: notch),
        child: Padding(
          padding: EdgeInsets.only(
            left: notch + 6,
            right: notch + 6,
            bottom: 7,
          ),
          child: SizedBox(
            height: height,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    shadows: const [
                      Shadow(
                        color: Colors.white70,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonBannerPainter extends CustomPainter {
  final double bandHeight;
  final double notch;

  _RibbonBannerPainter({required this.bandHeight, required this.notch});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = bandHeight;

    final goldGradient = const LinearGradient(
      colors: [
        Color(0xFFFFF3B0), // light gold highlight
        Color(0xFFFFD700), // gold
        Color(0xFFFFB300), // deep amber gold
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final bandRect = Rect.fromLTWH(0, 0, w, h);
    final bandPaint = Paint()..shader = goldGradient.createShader(bandRect);

    final borderPaint = Paint()
      ..color = Colors.green.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final foldPaint = Paint()..color = const Color(0xFFB8860B); // dark goldenrod
    final foldBorderPaint = Paint()
      ..color = Colors.green.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Folded tail peeking BELOW the band at both ends (drawn first, sits behind band)
    final leftFold = Path()
      ..moveTo(0, h - 2)
      ..lineTo(notch * 0.85, h - 2)
      ..lineTo(0, h + 6)
      ..close();
    final rightFold = Path()
      ..moveTo(w, h - 2)
      ..lineTo(w - notch * 0.85, h - 2)
      ..lineTo(w, h + 6)
      ..close();

    canvas.drawPath(leftFold, foldPaint);
    canvas.drawPath(leftFold, foldBorderPaint);
    canvas.drawPath(rightFold, foldPaint);
    canvas.drawPath(rightFold, foldBorderPaint);

    // Main ribbon band with chevron (arrow) notch cut into both edges
    final bandPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - notch, h / 2)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(notch, h / 2)
      ..close();

    canvas.drawPath(bandPath, bandPaint);
    canvas.drawPath(bandPath, borderPaint);

    // subtle top highlight line for a glossy ribbon feel
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(notch + 2, h * 0.28),
      Offset(w - notch - 2, h * 0.28),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RibbonBannerPainter oldDelegate) =>
      oldDelegate.bandHeight != bandHeight || oldDelegate.notch != notch;
}