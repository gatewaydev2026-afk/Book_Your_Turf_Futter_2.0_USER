import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LaunchOfferOverlay extends StatefulWidget {
  const LaunchOfferOverlay({required this.onDismissed, super.key});

  final VoidCallback onDismissed;

  @override
  State<LaunchOfferOverlay> createState() => _LaunchOfferOverlayState();
}

class _LaunchOfferOverlayState extends State<LaunchOfferOverlay> {
  static const String _videoAsset = 'assets/videos/diwali_offer.mp4';

  static const String _posterAsset = 'assets/images/diwali_offer_poster.png';

  static const Duration _displayDuration = Duration(seconds: 5);

  static const Duration _transitionDuration = Duration(milliseconds: 180);

  static const double _posterAspectRatio = 1026 / 1530;

  // Slightly larger popup while still fitting compact phones safely.
  static const double _popupSizeFactor = 0.76;

  late final VideoPlayerController _videoController;

  Timer? _dismissTimer;

  bool _isVideoReady = false;
  bool _isVisible = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset(
      _videoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        _isVisible = true;
      });

      _startVideo();

      _dismissTimer = Timer(_displayDuration, _dismiss);
    });
  }

  Future<void> _startVideo() async {
    try {
      await _videoController.initialize();

      if (!mounted || _isDismissing) return;

      await _videoController.setLooping(false);
      await _videoController.setVolume(0);

      if (!mounted || _isDismissing) return;

      await _videoController.play();

      if (!mounted || _isDismissing) return;

      setState(() {
        _isVideoReady = true;
      });
    } catch (error) {
      debugPrint('Launch offer video failed: $error');
    }
  }

  Future<void> _dismiss() async {
    if (!mounted || _isDismissing) return;

    _isDismissing = true;
    _dismissTimer?.cancel();

    try {
      if (_videoController.value.isInitialized) {
        await _videoController.pause();
      }
    } catch (error) {
      debugPrint('Video pause failed: $error');
    }

    if (!mounted) return;

    setState(() {
      _isVisible = false;
    });

    await Future<void>.delayed(_transitionDuration);

    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: _transitionDuration,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth * _popupSizeFactor;

            final double maxHeight = constraints.maxHeight * _popupSizeFactor;

            final double posterWidth = math.min(
              maxWidth,
              maxHeight * _posterAspectRatio,
            );

            final double posterHeight = posterWidth / _posterAspectRatio;

            final double buttonSize = 38;

            return Stack(
              children: [
                Center(
                  child: AnimatedScale(
                    scale: _isVisible ? 1.0 : 0.92,
                    duration: _transitionDuration,
                    curve: Curves.easeOutCubic,
                    child: SizedBox(
                      width: posterWidth,
                      height: posterHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Poster and video.
                          Positioned(
                            left: 0,
                            top: 0,
                            width: posterWidth,
                            height: posterHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _dismiss,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        _posterAsset,
                                        fit: BoxFit.cover,
                                      ),

                                      if (_isVideoReady)
                                        Center(
                                          child: AspectRatio(
                                            aspectRatio: _videoController
                                                .value
                                                .aspectRatio,
                                            child: VideoPlayer(
                                              _videoController,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 12),
                      child: SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.75),
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: _dismiss,
                            tooltip: 'Close offer',
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
