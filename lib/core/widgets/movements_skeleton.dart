import 'package:flutter/material.dart';
import 'shimmer_loading.dart';

class MovementsSkeleton extends StatelessWidget {
  const MovementsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Banner Skeleton
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                3,
                (index) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 60, height: 12, borderRadius: 4),
                    SizedBox(height: 8),
                    SkeletonBox(width: 75, height: 16, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Movements Items Skeleton
          ...List.generate(
            6,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: const Row(
                  children: [
                    SkeletonBox(width: 44, height: 44, borderRadius: 12),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SkeletonBox(width: 130, height: 15, borderRadius: 4),
                          SizedBox(height: 6),
                          SkeletonBox(width: 80, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonBox(width: 75, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        SkeletonBox(width: 45, height: 10, borderRadius: 3),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
