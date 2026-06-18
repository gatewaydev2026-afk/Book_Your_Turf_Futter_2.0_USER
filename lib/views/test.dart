import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class Test extends StatefulWidget {
  const Test({super.key});

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Lottie.asset(
                        'assets/lottie/BYT_2_CP_splash.json',
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.sports_cricket,
                          size: 100,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
      ),
    );
  }
}