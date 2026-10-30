import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Transparent, non-interactive fireworks layer for an app-wide Stack.
class DiwaliBottomRocketOverlay extends StatefulWidget {
  const DiwaliBottomRocketOverlay({
    super.key,
    required this.bottomClearance,
    this.showTitle = false,
  });

  final double bottomClearance;
  final bool showTitle;

  @override
  State<DiwaliBottomRocketOverlay> createState() =>
      _DiwaliBottomRocketOverlayState();
}

class _DiwaliBottomRocketOverlayState extends State<DiwaliBottomRocketOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomClearance),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _FullScreenRocketPainter(_controller),
                  isComplex: false,
                  willChange: true,
                ),
                if (widget.showTitle)
                  AnimatedBuilder(
                    animation: _controller,
                    child: const _DarkDiwaliTitle(compact: false),
                    builder: (context, child) {
                      final time = _controller.value;
                      final opacity = _titleOpacity(time);
                      return Align(
                        alignment: const Alignment(0, -0.18),
                        child: Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: .84 + (opacity * .16),
                            child: child,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rocket {
  const _Rocket({
    required this.start,
    required this.startX,
    required this.targetX,
    required this.targetY,
    required this.color,
    required this.accent,
  });

  final double start;
  final double startX;
  final double targetX;
  final double targetY;
  final Color color;
  final Color accent;
}

class _FullScreenRocketPainter extends CustomPainter {
  _FullScreenRocketPainter(Animation<double> progress)
      : _progress = progress,
        super(repaint: progress);

  final Animation<double> _progress;
  final Paint _paint = Paint()..strokeCap = StrokeCap.round;

  static const rockets = <_Rocket>[
    _Rocket(
      start: 0.00,
      startX: 0.10,
      targetX: 0.28,
      targetY: 0.18,
      color: Color(0xFFFFC400),
      accent: Color(0xFFFF5722),
    ),
    _Rocket(
      start: 0.06,
      startX: 0.35,
      targetX: 0.20,
      targetY: 0.78,
      color: Color(0xFFFF8F00),
      accent: Color(0xFFE53935),
    ),
    _Rocket(
      start: 0.12,
      startX: 0.82,
      targetX: 0.68,
      targetY: 0.30,
      color: Color(0xFF40C4FF),
      accent: Color(0xFFE040FB),
    ),
    _Rocket(
      start: 0.25,
      startX: 0.22,
      targetX: 0.50,
      targetY: 0.12,
      color: Color(0xFFFF6D00),
      accent: Color(0xFFFFEB3B),
    ),
    _Rocket(
      start: 0.39,
      startX: 0.92,
      targetX: 0.78,
      targetY: 0.44,
      color: Color(0xFF76FF03),
      accent: Color(0xFF00E5FF),
    ),
    _Rocket(
      start: 0.47,
      startX: 0.62,
      targetX: 0.76,
      targetY: 0.76,
      color: Color(0xFF7C4DFF),
      accent: Color(0xFF40C4FF),
    ),
    _Rocket(
      start: 0.53,
      startX: 0.48,
      targetX: 0.18,
      targetY: 0.35,
      color: Color(0xFFFF80AB),
      accent: Color(0xFFB388FF),
    ),
    _Rocket(
      start: 0.68,
      startX: 0.60,
      targetX: 0.86,
      targetY: 0.22,
      color: Color(0xFFFFAB40),
      accent: Color(0xFFFFF176),
    ),
    _Rocket(
      start: 0.82,
      startX: 0.14,
      targetX: 0.38,
      targetY: 0.52,
      color: Color(0xFF69F0AE),
      accent: Color(0xFF18FFFF),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final time = _progress.value;
    _paintAmbientBursts(canvas, size, time);
    for (var index = 0; index < rockets.length; index++) {
      final rocket = rockets[index];
      final local = (time - rocket.start + 1.0) % 1.0;
      if (local < .33) {
        _launch(canvas, size, rocket, local / .33, index);
      } else if (local < .62) {
        _burst(canvas, size, rocket, (local - .33) / .29, index);
      } else if (local < .78) {
        _sparkleCloud(canvas, size, rocket, (local - .62) / .16, index);
      }
    }
  }

  void _paintAmbientBursts(Canvas canvas, Size size, double time) {
    const centers = <Offset>[
      Offset(.16, .24),
      Offset(.34, .48),
      Offset(.56, .19),
      Offset(.74, .40),
      Offset(.87, .16),
      Offset(.26, .62),
      Offset(.43, .78),
      Offset(.72, .82),
    ];
    const colors = <Color>[
      Color(0x66FFD54F),
      Color(0x7740C4FF),
      Color(0x66E040FB),
      Color(0x77FF8A65),
      Color(0x6669F0AE),
      Color(0x77B388FF),
      Color(0x77FF8F00),
      Color(0x777C4DFF),
    ];

    for (var index = 0; index < centers.length; index++) {
      final local = (time - index * .11 + 1.0) % 1.0;
      if (local > .18) continue;
      final burst = local / .18;
      final center = Offset(
        centers[index].dx * size.width,
        centers[index].dy * size.height,
      );
      final radius =
          (14 + size.shortestSide * .04) * Curves.easeOut.transform(burst);
      final alpha = ((1 - burst) * 118).round();
      for (var spoke = 0; spoke < 10; spoke++) {
        final angle = spoke * 2 * math.pi / 10 + index * .2;
        final unit = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + unit * (radius - 5),
          center + unit * radius,
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..color = const Color(0xFF251039).withAlpha(alpha ~/ 2),
        );
        canvas.drawLine(
          center + unit * (radius - 5),
          center + unit * radius,
          _paint
            ..strokeWidth = 1.15
            ..color = colors[index].withAlpha(alpha),
        );
      }
    }
  }

  Offset _rocketPoint(Size size, _Rocket rocket, double time, int seed) {
    final start = Offset(rocket.startX * size.width, size.height + 10);
    final end = Offset(
      rocket.targetX * size.width,
      rocket.targetY * size.height,
    );
    final control = Offset(
      ((rocket.startX + rocket.targetX) * .5 + (seed.isEven ? -.08 : .08)) *
          size.width,
      size.height * (.56 - (seed % 3) * .06),
    );
    final inverse = 1 - time;
    final point = (start * (inverse * inverse)) +
        (control * (2 * inverse * time)) +
        (end * (time * time));
    return point +
        Offset(
          math.sin((time * math.pi * 2.4) + seed) * (4.0 + seed % 3 * 1.3),
          0,
        );
  }

  void _launch(
    Canvas canvas,
    Size size,
    _Rocket rocket,
    double time,
    int seed,
  ) {
    final eased = Curves.easeOutCubic.transform(time);
    final head = _rocketPoint(size, rocket, eased, seed);
    final previous =
        _rocketPoint(size, rocket, math.max(0.0, eased - .04), seed);
    final delta = head - previous;
    final direction =
        delta.distance == 0 ? const Offset(0, 1) : delta / delta.distance;

    for (var index = 0; index < 11; index++) {
      final alpha = ((1 - index / 11) * 230).round();
      final tail = head - direction * (index * 8.0);
      canvas.drawLine(
        tail,
        tail - direction * 7,
        _paint
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF241038).withAlpha(alpha ~/ 3)
          ..strokeWidth = math.max(2.1, 4.4 - index * .18),
      );
      canvas.drawLine(
        tail,
        tail - direction * 7,
        _paint
          ..color = rocket.color.withAlpha(alpha)
          ..strokeWidth = math.max(.7, 3.0 - index * .22),
      );
    }

    canvas.drawCircle(
      head,
      3.3,
      _paint
        ..style = PaintingStyle.fill
        ..color = Colors.white,
    );
    for (var index = 0; index < 5; index++) {
      final ember = Offset(
        math.sin(index * 1.8 + seed) * 4,
        8 + index * 8.0,
      );
      _paint.color = (index.isEven ? rocket.accent : rocket.color)
          .withAlpha(165 - index * 24);
      canvas.drawCircle(head + ember, 1.9 - index * .24, _paint);
    }
  }

  void _burst(
    Canvas canvas,
    Size size,
    _Rocket rocket,
    double time,
    int seed,
  ) {
    final expansion = Curves.easeOutCubic.transform(time);
    final opacity = (1.0 - Curves.easeInQuad.transform(time)).clamp(0.0, 1.0);
    final center = Offset(
      rocket.targetX * size.width,
      rocket.targetY * size.height,
    );
    final radius = math.min(size.width * .16, 70.0) * expansion;

    for (var index = 0; index < 20; index++) {
      final angle = index * math.pi * 2 / 20 + seed * .22;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final tip = center + direction * radius + Offset(0, 20 * time * time);
      final tail = tip - direction * (7 + 13 * opacity);
      canvas.drawLine(
        tail,
        tip,
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = index.isEven ? 4.4 : 3.2
          ..color = const Color(0xFF241038).withAlpha((opacity * 72).round()),
      );
      canvas.drawLine(
        tail,
        tip,
        _paint
          ..strokeWidth = index.isEven ? 2.2 : 1.25
          ..color = (index % 3 == 0
                  ? Colors.white
                  : (index.isEven ? rocket.color : rocket.accent))
              .withAlpha((opacity * 245).round()),
      );
    }

    for (var mini = 0; mini < 3; mini++) {
      final angle = seed * .7 + mini * 2.2;
      final offset =
          Offset(math.cos(angle), math.sin(angle)) * (14 + 12.0 * mini);
      _paintMiniBurst(
        canvas,
        center + offset,
        time,
        mini.isEven ? rocket.accent : rocket.color,
        spokeCount: 8 + mini,
        maxRadius: 10 + mini * 5.0,
      );
    }

    if (time < .22) {
      canvas.drawCircle(
        center,
        (1 - time / .22) * 5.5,
        _paint
          ..style = PaintingStyle.fill
          ..color = Colors.white.withAlpha(((1 - time / .22) * 240).round()),
      );
    }
  }

  void _sparkleCloud(
    Canvas canvas,
    Size size,
    _Rocket rocket,
    double time,
    int seed,
  ) {
    final center = Offset(
      rocket.targetX * size.width,
      rocket.targetY * size.height,
    );
    final fade = (1 - time).clamp(0.0, 1.0);
    for (var index = 0; index < 7; index++) {
      final angle = seed * .45 + index * .92;
      final orbit = 10 + index * 5.0 + time * 8;
      final point = center +
          Offset(math.cos(angle), math.sin(angle)) * orbit +
          Offset(0, time * 8);
      canvas.drawCircle(
        point,
        index % 3 == 0 ? 1.9 : 1.3,
        _paint
          ..style = PaintingStyle.fill
          ..color = (index.isEven ? rocket.color : rocket.accent)
              .withAlpha((fade * 160).round()),
      );
    }
  }

  void _paintMiniBurst(
    Canvas canvas,
    Offset center,
    double time,
    Color color, {
    required int spokeCount,
    required double maxRadius,
  }) {
    final progress = Curves.easeOut.transform(time);
    final alpha = ((1 - time) * 200).round();
    final radius = 4 + maxRadius * progress;
    for (var index = 0; index < spokeCount; index++) {
      final angle = index * 2 * math.pi / spokeCount;
      final unit = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + unit * (radius - 4),
        center + unit * radius,
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..color = const Color(0xFF241038).withAlpha(alpha ~/ 3),
      );
      canvas.drawLine(
        center + unit * (radius - 4),
        center + unit * radius,
        _paint
          ..strokeWidth = 1.05
          ..color = color.withAlpha(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FullScreenRocketPainter oldDelegate) => false;
}

/// Header fireworks retained on Turf Details and Slot Booking.
class DiwaliTurfAnimation extends StatefulWidget {
  const DiwaliTurfAnimation({super.key, this.compact = false});

  final bool compact;

  @override
  State<DiwaliTurfAnimation> createState() => _DiwaliTurfAnimationState();
}

class _DiwaliTurfAnimationState extends State<DiwaliTurfAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
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
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _MiniFireworksPainter(_controller)),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final time = _controller.value;
                    final opacity = _titleOpacity(time);
                    return Center(
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: _DarkDiwaliTitle(compact: widget.compact),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _titleOpacity(double time) {
  if (time < .69) return 0;
  if (time < .82) return (time - .69) / .13;
  if (time < .94) return 1;
  return ((1 - time) / .06).clamp(0.0, 1.0);
}

class _DarkDiwaliTitle extends StatelessWidget {
  const _DarkDiwaliTitle({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: compact ? 24 : 30,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: compact ? 1.1 : 1.7,
      height: 1,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(2.5, 3.5),
          child: Text(
            'HAPPY DIWALI',
            style: style.copyWith(
              color: const Color(0xFF3A1608),
              shadows: const [
                Shadow(color: Color(0xAA2A0B00), blurRadius: 4),
              ],
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE082),
              Color(0xFFD18A00),
              Color(0xFF8A3D00),
              Color(0xFF5A1F00),
            ],
          ).createShader(bounds),
          child: Text(
            'HAPPY DIWALI',
            style: style.copyWith(
              color: Colors.white,
              shadows: const [
                Shadow(color: Color(0xFFFFB300), blurRadius: 6),
                Shadow(color: Color(0xFF5A1F00), blurRadius: 2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniFireworksPainter extends CustomPainter {
  _MiniFireworksPainter(Animation<double> progress)
      : _progress = progress,
        super(repaint: progress);

  final Animation<double> _progress;
  final Paint _paint = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final time = _progress.value;
    const centers = <Offset>[
      Offset(.18, .40),
      Offset(.80, .28),
      Offset(.52, .58),
    ];
    const colors = <Color>[
      Color(0xFFFFB300),
      Color(0xFF40C4FF),
      Color(0xFFE040FB),
    ];

    for (var index = 0; index < 2; index++) {
      final local = (time - index * .34 + 1) % 1;
      if (local >= .42) continue;
      final progress = local / .42;
      final start = Offset(
        (index == 0 ? .10 : .90) * size.width,
        size.height - 2,
      );
      final end = Offset(
        (index == 0 ? .28 : .72) * size.width,
        (index == 0 ? .26 : .20) * size.height,
      );
      final middle = Offset(
        (index == 0 ? .18 : .82) * size.width,
        .55 * size.height,
      );
      final inverse = 1 - progress;
      final head = (start * (inverse * inverse)) +
          (middle * (2 * inverse * progress)) +
          (end * (progress * progress));
      final previousProgress = math.max(0.0, progress - .04);
      final previousInverse = 1 - previousProgress;
      final previous = (start * (previousInverse * previousInverse)) +
          (middle * (2 * previousInverse * previousProgress)) +
          (end * (previousProgress * previousProgress));
      final delta = head - previous;
      final direction =
          delta.distance == 0 ? const Offset(0, 1) : delta / delta.distance;
      for (var tailIndex = 0; tailIndex < 7; tailIndex++) {
        final tail = head - direction * (tailIndex * 5.5);
        canvas.drawLine(
          tail,
          tail - direction * 4.5,
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.8, 3.3 - tailIndex * .14)
            ..color = const Color(0xFF241038).withAlpha(70),
        );
        canvas.drawLine(
          tail,
          tail - direction * 4.5,
          _paint
            ..strokeWidth = math.max(.7, 2.0 - tailIndex * .18)
            ..color =
                colors[index].withAlpha(((1 - tailIndex / 7) * 200).round()),
        );
      }
      canvas.drawCircle(
        head,
        2.2,
        _paint
          ..style = PaintingStyle.fill
          ..color = Colors.white,
      );
    }

    for (var index = 0; index < centers.length; index++) {
      final local = (time - index * .22 + 1) % 1;
      if (local > .58) continue;
      final progress = local / .58;
      final center = Offset(
        centers[index].dx * size.width,
        centers[index].dy * size.height,
      );
      final radius = 8 + 30 * Curves.easeOut.transform(progress);
      final alpha = ((1 - progress) * 220).round();
      for (var spoke = 0; spoke < 12; spoke++) {
        final angle = spoke * 2 * math.pi / 12;
        final unit = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + unit * (radius - 7),
          center + unit * radius,
          _paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..color = const Color(0xFF241038).withAlpha(alpha ~/ 3),
        );
        canvas.drawLine(
          center + unit * (radius - 7),
          center + unit * radius,
          _paint
            ..strokeWidth = 1.6
            ..color = colors[index].withAlpha(alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniFireworksPainter oldDelegate) => false;
}

class DiwaliFilterBadge extends StatelessWidget {
  const DiwaliFilterBadge({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 58,
        height: 26,
        child: CustomPaint(painter: _StaticDiwaliSparkPainter(12)),
      );
}

class DiwaliFilterSpark extends StatelessWidget {
  const DiwaliFilterSpark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _StaticDiwaliSparkPainter(8)),
      );
}

/// Compact burning diya and firecracker shown at the end of the Home filter.
class DiwaliFilterLampFirecracker extends StatefulWidget {
  const DiwaliFilterLampFirecracker({super.key, this.size = 34});

  final double size;

  @override
  State<DiwaliFilterLampFirecracker> createState() =>
      _DiwaliFilterLampFirecrackerState();
}

class _DiwaliFilterLampFirecrackerState
    extends State<DiwaliFilterLampFirecracker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
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
      child: SizedBox(
        width: widget.size * (44 / 34),
        height: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _LampFirecrackerPainter(_controller),
            willChange: true,
          ),
        ),
      ),
    );
  }
}

class _LampFirecrackerPainter extends CustomPainter {
  _LampFirecrackerPainter(Animation<double> progress)
      : _progress = progress,
        super(repaint: progress);

  final Animation<double> _progress;
  final Paint _paint = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 34;
    canvas.save();
    canvas.scale(scale);
    final time = _progress.value;
    final flicker = .86 + ((math.sin(time * math.pi * 8) + 1) * .07);
    const diyaCenter = Offset(12, 25);

    canvas.drawOval(
      const Rect.fromLTWH(0, 27, 25, 5),
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF211018).withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: diyaCenter, width: 23, height: 10),
      _paint
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB300), Color(0xFFD45A00), Color(0xFF5A1F00)],
        ).createShader(const Rect.fromLTWH(0, 20, 24, 12))
        ..maskFilter = null,
    );
    canvas.drawArc(
      const Rect.fromLTWH(1, 20, 22, 12),
      0,
      math.pi,
      false,
      _paint
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = const Color(0xFFD86B00),
    );
    canvas.drawArc(
      const Rect.fromLTWH(3, 20, 18, 8),
      math.pi,
      math.pi,
      false,
      _paint..color = const Color(0xFFFFC107),
    );
    canvas.drawArc(
      const Rect.fromLTWH(4, 21, 15, 5),
      math.pi,
      math.pi,
      false,
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFFFF1A6),
    );

    final flamePath = Path()
      ..moveTo(12, 20)
      ..quadraticBezierTo(6.8, 14, 12.4, 7.5 * flicker)
      ..quadraticBezierTo(18, 14, 12, 20)
      ..close();
    canvas.drawPath(
      flamePath,
      _paint
        ..style = PaintingStyle.fill
        ..shader = null
        ..color = const Color(0xFFFF6D00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
    canvas.drawPath(
      flamePath,
      _paint
        ..color = const Color(0xFFFF6D00)
        ..maskFilter = null,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(12.2, 15.4),
        width: 3.2,
        height: 7 * flicker,
      ),
      _paint
        ..color = const Color(0xFFFFF59D)
        ..maskFilter = null,
    );

    final burst = (time * 1.35) % 1.0;
    final radius = 3 + (11 * Curves.easeOut.transform(burst));
    final alpha = ((1 - burst) * 230).round();
    const burstCenter = Offset(33, 12);
    const colors = [Color(0xFFFFD54F), Color(0xFFE040FB), Color(0xFF40C4FF)];
    canvas.drawCircle(
      burstCenter,
      3 + radius * .32,
      _paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFB300).withAlpha(alpha ~/ 3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    _paint.maskFilter = null;
    for (var index = 0; index < 9; index++) {
      final angle = index * math.pi * 2 / 9;
      final unit = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        burstCenter + unit * (radius * .45),
        burstCenter + unit * radius,
        _paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.7
          ..color = const Color(0xFF241038).withAlpha(alpha ~/ 3),
      );
      canvas.drawLine(
        burstCenter + unit * (radius * .45),
        burstCenter + unit * radius,
        _paint
          ..strokeWidth = 1.25
          ..color = colors[index % colors.length].withAlpha(alpha),
      );
      if (index.isEven) {
        final spark = burstCenter +
            unit * radius +
            Offset(0, burst * burst * (3 + index * .28));
        canvas.drawCircle(
          spark,
          index % 4 == 0 ? 1.3 : .8,
          _paint
            ..style = PaintingStyle.fill
            ..color = Colors.white.withAlpha(alpha),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LampFirecrackerPainter oldDelegate) => false;
}

/// Compact animated 3D festive identity used on every scrolling turf card.
class DiwaliTurfCardDecoration extends StatefulWidget {
  const DiwaliTurfCardDecoration({super.key, required this.variant});

  final int variant;

  @override
  State<DiwaliTurfCardDecoration> createState() =>
      _DiwaliTurfCardDecorationState();
}

class _DiwaliTurfCardDecorationState extends State<DiwaliTurfCardDecoration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _TurfCardDiwaliPainter(
            widget.variant,
            _controller,
          ),
        ),
      ),
    );
  }
}

class _TurfCardDiwaliPainter extends CustomPainter {
  _TurfCardDiwaliPainter(this.variant, Animation<double> progress)
      : _progress = progress,
        super(repaint: progress);

  final int variant;
  final Animation<double> _progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..strokeCap = StrokeCap.round;
    final time = (_progress.value + (variant * .17)) % 1.0;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndCorners(
        Offset.zero & size,
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
    );

    // Double metallic-gold frame around the turf photograph.
    final frame = RRect.fromRectAndCorners(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      topLeft: const Radius.circular(11),
      topRight: const Radius.circular(11),
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    canvas.drawRRect(
      frame,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF1A8), Color(0xFFFFB300), Color(0xFF8A4A00)],
        ).createShader(Offset.zero & size),
    );
    paint.shader = null;
    canvas.drawRRect(
      frame.deflate(2.4),
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = .55
        ..color = const Color(0xFFFFE082).withAlpha(185),
    );

    // Premium hanging-light garland between the two card action icons.
    final garlandStart = math.min(35.0, size.width * .25);
    final garlandEnd = size.width - garlandStart;
    final garland = Path()
      ..moveTo(garlandStart, 3.5)
      ..quadraticBezierTo(size.width * .5, 17, garlandEnd, 3.5);
    canvas.drawPath(
      garland,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF3A1900).withAlpha(125),
    );
    canvas.drawPath(
      garland,
      paint
        ..strokeWidth = 1.15
        ..color = const Color(0xFFFFD54F),
    );
    const bulbColors = [
      Color(0xFFFFD54F),
      Color(0xFFFF7043),
      Color(0xFFCE93D8),
      Color(0xFF80D8FF),
    ];
    for (var index = 1; index <= 5; index++) {
      final progress = index / 6;
      final inverse = 1 - progress;
      final point = Offset(
        garlandStart * inverse + garlandEnd * progress,
        (3.5 * inverse * inverse) +
            (17 * 2 * inverse * progress) +
            (3.5 * progress * progress),
      );
      final pulse =
          .72 + ((math.sin((time * math.pi * 8) + index + variant) + 1) * .14);
      canvas.drawCircle(
        point + const Offset(0, 2.4),
        3.3 * pulse,
        paint
          ..style = PaintingStyle.fill
          ..color =
              bulbColors[(index + variant) % bulbColors.length].withAlpha(72)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        point + const Offset(0, 2.4),
        1.35 * pulse,
        paint
          ..color = bulbColors[(index + variant) % bulbColors.length]
          ..maskFilter = null,
      );
    }

    // Moving golden glint across the top frame.
    final shimmerX = -12 + (time * (size.width + 24));
    canvas.drawLine(
      Offset(shimmerX - 8, 1.8),
      Offset(shimmerX + 8, 1.8),
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = const Color(0xFFFFFFFF).withAlpha(205)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    paint.maskFilter = null;

    // Realistic small diya below the garland, away from the action icons.
    final diyaX = size.width * .38;
    const diyaY = 25.0;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(diyaX, diyaY + 2), width: 17, height: 4),
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF1E0C00).withAlpha(110)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(diyaX, diyaY), width: 16, height: 6.2),
      paint
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD54F), Color(0xFFE36900), Color(0xFF5A1900)],
        ).createShader(Rect.fromLTWH(diyaX - 8, diyaY - 3, 16, 8))
        ..maskFilter = null,
    );
    paint.shader = null;
    canvas.drawArc(
      Rect.fromLTWH(diyaX - 7, diyaY - 3.2, 14, 7),
      0,
      math.pi,
      false,
      paint..color = const Color(0xFFE87500),
    );
    final flicker = .82 + ((math.sin(time * math.pi * 9) + 1) * .09);
    final flame = Path()
      ..moveTo(diyaX, diyaY - 2)
      ..quadraticBezierTo(
        diyaX - 3.2,
        diyaY - 7,
        diyaX + .4,
        diyaY - (13 * flicker),
      )
      ..quadraticBezierTo(diyaX + 3.5, diyaY - 7, diyaX, diyaY - 2)
      ..close();
    canvas.drawCircle(
      Offset(diyaX, diyaY - 7),
      5.4 * flicker,
      paint
        ..color = const Color(0xFFFF8F00).withAlpha(72)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      flame,
      paint
        ..color = const Color(0xFFFF6D00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(diyaX + .1, diyaY - 7),
        width: 1.7,
        height: 4.5,
      ),
      paint
        ..color = const Color(0xFFFFF7AE)
        ..maskFilter = null,
    );

    // Multi-depth firework balances the diya without hiding turf content.
    final center = Offset(size.width * .65, 19);
    const sparkColors = [
      Color(0xFFFFD54F),
      Color(0xFF40C4FF),
      Color(0xFFFF80AB),
    ];
    final burstTime = (time * 1.42) % 1.0;
    final expansion = Curves.easeOutCubic.transform(burstTime);
    final burstAlpha = ((1 - burstTime) * 255).round();
    canvas.drawCircle(
      center,
      2 + (expansion * 4),
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFC107).withAlpha(burstAlpha ~/ 3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    paint.maskFilter = null;
    for (var index = 0; index < 8; index++) {
      final angle = index * math.pi * 2 / 8 + variant * .21;
      final unit = Offset(math.cos(angle), math.sin(angle));
      final maxRadius = index.isEven ? 8.5 : 7.0;
      final radius = 2.2 + (maxRadius * expansion);
      canvas.drawLine(
        center + unit * (radius * .42),
        center + unit * radius,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF190B24).withAlpha(burstAlpha ~/ 2),
      );
      canvas.drawLine(
        center + unit * (radius * .42),
        center + unit * radius,
        paint
          ..strokeWidth = index.isEven ? 1.2 : .8
          ..color = sparkColors[(index + variant) % sparkColors.length]
              .withAlpha(burstAlpha),
      );
      if (index.isEven) {
        canvas.drawCircle(
          center + unit * radius + Offset(0, burstTime * burstTime * 2.5),
          .65,
          paint
            ..style = PaintingStyle.fill
            ..color = Colors.white.withAlpha(burstAlpha),
        );
      }
    }
    canvas.drawCircle(
      center,
      1.4,
      paint..color = Colors.white.withAlpha(burstAlpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TurfCardDiwaliPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

class _StaticDiwaliSparkPainter extends CustomPainter {
  const _StaticDiwaliSparkPainter(this.count);

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .43;
    const colors = [Color(0xFFFFD54F), Color(0xFFE040FB), Color(0xFF40C4FF)];
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var index = 0; index < count; index++) {
      final angle = index * 2 * math.pi / count;
      final unit = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + unit * radius * .38,
        center + unit * radius,
        paint
          ..color = colors[index % colors.length]
          ..strokeWidth = index.isEven ? 1.5 : 1,
      );
    }
    canvas.drawCircle(center, 1.8, paint..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _StaticDiwaliSparkPainter oldDelegate) => false;
}
