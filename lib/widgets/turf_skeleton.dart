// widgets/turf_skeleton.dart - Matches fixed TurfCard exactly

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TurfSkeleton extends StatelessWidget {
  const TurfSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
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
        // ✅ Column (no mainAxisSize: min) — matches fixed TurfCard
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image skeleton — matches reduced height 130
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                height: 130,
                width: double.infinity,
                color: Colors.white,
              ),
            ),

            // Content skeleton — Expanded like TurfCard
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name skeleton
                    Container(
                      width: double.infinity,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 3),

                    // Address skeleton
                    Row(
                      children: [
                        Container(width: 9, height: 9, color: Colors.white),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(
                            height: 9,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Game type chip skeleton
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),

                    // Spacer matches TurfCard
                    const Spacer(),

                    // Button skeleton
                    Container(
                      width: double.infinity,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
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