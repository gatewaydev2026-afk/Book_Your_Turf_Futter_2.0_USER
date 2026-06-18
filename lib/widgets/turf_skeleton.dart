// widgets/turf_skeleton.dart - MATCHES TURFCARD EXACTLY

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section - matches TurfCard height
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.white,
              ),
            ),

            // Content Section - matches TurfCard padding
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Turf name skeleton
                  Container(
                    width: double.infinity,
                    height: 14, // matches font size 12 + some margin
                    color: Colors.white,
                  ),
                  const SizedBox(height: 2),

                  // Address skeleton
                  Row(
                    children: [
                      Container(width: 9, height: 9, color: Colors.white), // icon placeholder
                      const SizedBox(width: 2),
                      Expanded(
                        child: Container(
                          height: 11, // matches font size 9 + margin
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Game type chip skeleton
                  Container(
                    width: 60, // approximate width for game type
                    height: 16, // matches chip height
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Action Button skeleton - matches button height
                  Container(
                    width: double.infinity,
                    height: 26, // matches button height
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}