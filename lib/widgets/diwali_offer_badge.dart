import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Premium animated Diwali discount badge shared by turf cards and details.
class DiwaliOfferBadge extends StatefulWidget {
  final String mainLabel;
  final String extraLabel;
  final bool isSmallScreen;

  const DiwaliOfferBadge({
    super.key,
    required this.mainLabel,
    this.extraLabel = '',
    this.isSmallScreen = false,
  });

  @override
  State<DiwaliOfferBadge> createState() => _DiwaliOfferBadgeState();
}

class _DiwaliOfferBadgeState extends State<DiwaliOfferBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final time = _controller.value;
              final wave = math.sin(time * math.pi * 2);
              final glow = (math.sin(time * math.pi * 4) + 1) / 2;
              final label = widget.extraLabel.isEmpty
                  ? widget.mainLabel
                  : '${widget.mainLabel} • ${widget.extraLabel}';

              return Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(0, -0.8 * glow),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateX(-0.025 + wave * 0.012)
                      ..rotateY(wave * 0.055),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Transform.translate(
                            offset: const Offset(0, 3),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF65000F),
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 190),
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isSmallScreen ? 8 : 10,
                            vertical: widget.isSmallScreen ? 4 : 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF820015),
                                Color(0xFFE21D2F),
                                Color(0xFF940014),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(0xFFFFD54F),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFB300,
                                ).withValues(alpha: 0.28 + glow * 0.28),
                                blurRadius: 5 + glow * 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: widget.isSmallScreen ? 10 : 11,
                                      color: const Color(0xFFFFE082),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'DIWALI • $label',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: widget.isSmallScreen
                                              ? 9.5
                                              : 10.5,
                                          height: 1,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.15,
                                          shadows: const [
                                            Shadow(
                                              color: Color(0xFF55000C),
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment(-1.8 + time * 3.6, 0),
                                    child: Transform.rotate(
                                      angle: -0.35,
                                      child: Container(
                                        width: 12,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0),
                                              Colors.white.withValues(
                                                alpha: 0.48,
                                              ),
                                              Colors.white.withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -3,
                          child: Opacity(
                            opacity: 0.35 + glow * 0.65,
                            child: Transform.scale(
                              scale: 0.7 + glow * 0.35,
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 10,
                                color: Color(0xFFFFF59D),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
