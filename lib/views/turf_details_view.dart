// turf_details_view.dart - NO API CALL, Use passed data only
// ✅ FIXED: Arguments parsed once in initState, cached for rebuilds
// ✅ Added Lemon Yellow Blinking Discount Badge below Verified badge

import 'package:book_your_turf/widgets/sports_amentites.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/turf_model.dart';
import '../routes/app_routes.dart';
import '../utils/helpers.dart';

class TurfDetailsView extends StatefulWidget {
  const TurfDetailsView({Key? key}) : super(key: key);

  @override
  State<TurfDetailsView> createState() => _TurfDetailsViewState();
}

class _TurfDetailsViewState extends State<TurfDetailsView> with SingleTickerProviderStateMixin {
  int _currentImageIndex = 0;
  late CarouselSliderController _carouselController;
  bool _isCarouselInitialized = false;
  Timer? _autoSlideTimer;
  bool _isAutoSliding = true;
  int _imageCount = 0;

  // ✅ Blinking animation for discount badge
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late Animation<double> _scaleAnimation;

  final ScrollController _scrollController = ScrollController();
  double _cardElevation = 4.0;
  double _cardMargin = 16.0;
  double _scrollOffset = 0.0;

  // ✅ Cached turf - parsed once in initState
  TurfModel? _cachedTurf;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselSliderController();

    // ✅ Parse arguments ONCE in initState
    _parseArguments();

    // ✅ Initialize blinking animation
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _isCarouselInitialized = true;
        _startAutoSlide();
      }
    });

    _scrollController.addListener(_onScroll);
  }

  // ✅ Parse arguments once - called from initState
  void _parseArguments() {
    final dynamic args = Get.arguments;

    print('🔍 TurfDetailsView - Args type: ${args.runtimeType}');

    if (args == null) {
      print('❌ TurfDetailsView: No arguments provided');
      _isInitialized = false;
      return;
    }

    try {
      if (args is TurfModel) {
        // ✅ Already a TurfModel - use it directly
        _cachedTurf = args;
        print('✅ TurfDetailsView: Received TurfModel directly: ${_cachedTurf!.name}');
        _isInitialized = true;
      } else if (args is Map<String, dynamic>) {
        // ✅ Check if this Map contains a TurfModel
        if (args.containsKey('turf') && args['turf'] is TurfModel) {
          _cachedTurf = args['turf'] as TurfModel;
          print('✅ TurfDetailsView: Extracted TurfModel from Map: ${_cachedTurf!.name}');
        } else {
          // ✅ Convert Map to TurfModel
          _cachedTurf = TurfModel.fromJson(args);
          print('✅ TurfDetailsView: Converted Map to TurfModel: ${_cachedTurf!.name}');
        }
        _isInitialized = true;
      } else {
        print('❌ TurfDetailsView: Invalid arguments type: ${args.runtimeType}');
        _isInitialized = false;
      }
    } catch (e) {
      print('❌ TurfDetailsView: Error parsing arguments: $e');
      _isInitialized = false;
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_isAutoSliding && mounted && _isCarouselInitialized && _imageCount > 1) {
        try {
          _carouselController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        } catch (e) {
          // Silently ignore error when carousel is not ready
        }
      }
    });
  }

  void _stopAutoSlide() {
    _isAutoSliding = false;
  }

  void _resumeAutoSlide() {
    _isAutoSliding = true;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final scrollOffset = _scrollController.offset;
    setState(() {
      _scrollOffset = scrollOffset;
      _cardElevation = 4.0 + (scrollOffset / 50).clamp(0.0, 8.0);
      _cardMargin = 16.0 - (scrollOffset / 100).clamp(0.0, 12.0);
      if (_cardMargin < 4) _cardMargin = 4;
    });
  }

  bool _isCricketOrFootball(String gameType) {
    final type = gameType.toLowerCase();
    return type.contains('cricket') || type.contains('football');
  }

  String _getCourtTurfLabel(TurfModel turf) {
    if (_isCricketOrFootball(turf.gameType)) {
      return "Turf";
    }
    return "Court";
  }

  bool _isClosingTimeNextDay(String openTime, String closeTime) {
    if (openTime.isEmpty || closeTime.isEmpty) return false;

    try {
      final openParts = openTime.split(':');
      final closeParts = closeTime.split(':');

      if (openParts.isEmpty || closeParts.isEmpty) return false;

      int openHour = int.parse(openParts[0]);
      int openMinute = openParts.length > 1 ? int.parse(openParts[1]) : 0;

      int closeHour = int.parse(closeParts[0]);
      int closeMinute = closeParts.length > 1 ? int.parse(closeParts[1]) : 0;

      if (closeHour == 24) return true;

      int openTotalMinutes = openHour * 60 + openMinute;
      int closeTotalMinutes = closeHour * 60 + closeMinute;

      return closeTotalMinutes <= openTotalMinutes;
    } catch (e) {
      return false;
    }
  }

  Future<void> _openMap(TurfModel turf) async {
    double? lat = turf.latitude;
    double? lng = turf.longitude;
    String query = turf.address;

    String url;
    if (lat != null && lng != null) {
      url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else {
      url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar(
        'Error',
        'Could not open maps',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      Get.snackbar(
        'Cannot Call',
        'Phone number not available for this venue',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch phone dialer';
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not make call: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _handlePrimaryAction(TurfModel turf) {
    if (turf.isBookable) {
      Get.toNamed(AppRoutes.slotSelection, arguments: turf);
    } else {
      _makePhoneCall(turf.phoneNumber);
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _blinkController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ If not initialized or no turf, show error
    if (!_isInitialized || _cachedTurf == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  "Failed to load turf details",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please go back and try again",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final turf = _cachedTurf!;

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final hasImages = turf.images.isNotEmpty;
    final hasMultipleImages = turf.images.length > 1;
    _imageCount = turf.images.length;
    final courtTurfLabel = _getCourtTurfLabel(turf);
    final isCricketOrFootball = _isCricketOrFootball(turf.gameType);
    final isNextDayClose = _isClosingTimeNextDay(turf.openTime, turf.closeTime);

    final advanceDisplayText = turf.getAdvanceDisplayText();
    final minSlotsDisplayText = turf.getMinSlotsDisplayText();

    // ✅ Get discount label from API
    String discountLabel = turf.bestDiscountLabel ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: _scrollOffset > 20 ? 4 : 0,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _scrollOffset > 50 ? 1.0 : 0.0,
              child: Text(
                turf.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Get.back(),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // IMAGE INSIDE CARD
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: _cardMargin),
                  child: Card(
                    elevation: _cardElevation,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          height: 280,
                          width: double.infinity,
                          color: Colors.black87,
                          child: hasImages
                              ? GestureDetector(
                            onHorizontalDragStart: (_) {
                              _stopAutoSlide();
                            },
                            onHorizontalDragEnd: (_) {
                              Future.delayed(const Duration(seconds: 3), () {
                                if (mounted) {
                                  _resumeAutoSlide();
                                }
                              });
                            },
                            child: CarouselSlider(
                              carouselController: _carouselController,
                              options: CarouselOptions(
                                height: 280,
                                viewportFraction: 1.0,
                                enlargeCenterPage: false,
                                autoPlay: true,
                                autoPlayInterval: const Duration(seconds: 4),
                                autoPlayAnimationDuration: const Duration(milliseconds: 500),
                                autoPlayCurve: Curves.easeInOutCubic,
                                pauseAutoPlayOnTouch: true,
                                pauseAutoPlayOnManualNavigate: true,
                                enableInfiniteScroll: true,
                                onPageChanged: (index, reason) {
                                  setState(() {
                                    _currentImageIndex = index;
                                  });
                                },
                              ),
                              items: turf.images.map((imgUrl) {
                                return Builder(
                                  builder: (BuildContext context) {
                                    return Container(
                                      width: double.infinity,
                                      height: 280,
                                      child: CachedNetworkImage(
                                        imageUrl: imgUrl,
                                        width: double.infinity,
                                        height: 280,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey[800],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey[800],
                                          child: const Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              size: 50,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          )
                              : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.sports, size: 60, color: Colors.white),
                            ),
                          ),
                        ),

                        if (hasMultipleImages)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: turf.images.asMap().entries.map((entry) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: _currentImageIndex == entry.key ? 12 : 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: _currentImageIndex == entry.key
                                        ? Colors.green
                                        : Colors.grey.shade400,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // REST OF THE CONTENT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Turf Name
                      Text(
                        turf.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ✅ Verified Badge + Lemon Yellow Discount Badge Row
                      Row(
                        children: [
                          // Verified Badge
                          if (turf.showVerifiedBadge)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Image.asset(
                                    // 🔁 Replace this URL with your actual image URL
                                    'assets/images/blue.jpeg',
                                    height: 20,
                                    fit: BoxFit.fill,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.image,
                                      size: 16,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  SizedBox(width: 10,),
                                  Text("Verified",style: TextStyle(color: Colors.white),)
                                ],
                              ),
                            ),

                          const SizedBox(width: 8),

                          // ✅ LEMON YELLOW BLINKING DISCOUNT BADGE
                          if (discountLabel.isNotEmpty)
                            AnimatedBuilder(
                              animation: _blinkAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _scaleAnimation.value,
                                  child: Opacity(
                                    opacity: _blinkAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade900, // ✅ Pure Lemon Yellow
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color:  Colors.orange.shade900,
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                        border: Border.all(
                                          color:  Colors.orange.shade900,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding:  EdgeInsets.all(2),
                                            decoration:  BoxDecoration(
                                              color: Colors.orange.shade900,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.local_offer,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            discountLabel,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.white70,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.black26,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward_ios,
                                              size: 8,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Address with Map Link
                      GestureDetector(
                        onTap: () => _openMap(turf),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                turf.address,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Game Type
                      Row(
                        children: [
                          const Icon(Icons.sports, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            turf.gameType.isNotEmpty
                                ? turf.gameType
                                : 'Contact for details',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Opening & Closing Times
                      if (turf.isBookable) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Opening Time",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          formatTo12Hour(turf.openTime),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.shade300,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Closing Time",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            formatTo12Hour(turf.closeTime),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isNextDayClose) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.orange.shade300,
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.nightlight_round,
                                                    size: 12,
                                                    color: Colors.orange.shade700,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Next Day',
                                                    style: TextStyle(
                                                      fontSize: 6,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.orange.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],

                      // Amenities & Sports
                      buildAmenitiesAndSportsSection(
                        context: context,
                        turf: turf,
                        isTablet: isTablet,
                      ),
                      const SizedBox(height: 15),

                      // Description
                      if (turf.isBookable && turf.description.isNotEmpty) ...[
                        const Text(
                          "Description",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          turf.description,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Max persons & courts/turfs
                      if (turf.isBookable) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.people,
                                      size: 22,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Max ${turf.maxPersons} persons",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      isCricketOrFootball
                                          ? Icons.sports_soccer
                                          : Icons.sports_tennis,
                                      size: 22,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${turf.courts} ${turf.courts > 1 ? '${courtTurfLabel}s' : courtTurfLabel}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ACTION BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () => _handlePrimaryAction(turf),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: turf.isBookable ? Colors.green : Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                turf.isBookable ? Icons.calendar_today : Icons.call,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                turf.isBookable ? "BOOK NOW" : "CALL NOW",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Enquiry Listing Info (non-bookable)
                      if (!turf.isBookable) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Enquiry Listing',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This is an enquiry listing. Please call us to get details about availability, pricing, and booking for this venue.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                  height: 1.4,
                                ),
                              ),
                              if (turf.phoneNumber != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        color: Colors.blue.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        turf.phoneNumber!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}