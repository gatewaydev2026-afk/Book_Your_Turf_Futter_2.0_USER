import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedSearchHint extends StatefulWidget {
  const AnimatedSearchHint({super.key});

  @override
  State<AnimatedSearchHint> createState() => _AnimatedSearchHintState();
}

class _AnimatedSearchHintState extends State<AnimatedSearchHint> {
  final List<String> hints = ["Venues", "Locations"];
  int index = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => index = (index + 1) % hints.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text("Search by ", style: TextStyle(color: Colors.grey, fontSize: 17)),
        ClipRect(
          child: SizedBox(
            height: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Text(hints[index], key: ValueKey(hints[index]), style: const TextStyle(color: Colors.grey, fontSize: 17)),
            ),
          ),
        ),
      ],
    );
  }
}