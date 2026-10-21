import 'package:flutter/material.dart';
import 'shimmer_loading.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // 1. Balance Card Skeleton
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 120, height: 16, borderRadius: 6),
                    SkeletonBox(width: 80, height: 26, borderRadius: 12),
                  ],
                ),
                SkeletonBox(width: 200, height: 38, borderRadius: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 110, height: 16, borderRadius: 6),
                    SkeletonBox(width: 90, height: 16, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Quick Actions Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (index) => const Column(
                children: [
                  SkeletonBox(width: 56, height: 56, borderRadius: 16),
                  SizedBox(height: 8),
                  SkeletonBox(width: 48, height: 12, borderRadius: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),

          // 3. Accounts Skeleton Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 130, height: 20, borderRadius: 6),
              SkeletonBox(width: 60, height: 14, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),

          // Accounts Cards
          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    SkeletonBox(width: 48, height: 48, borderRadius: 14),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SkeletonBox(width: 100, height: 16, borderRadius: 4),
                          SizedBox(height: 8),
                          SkeletonBox(width: 60, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    SkeletonBox(width: 80, height: 20, borderRadius: 6),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Limits Skeleton
          const SkeletonBox(width: 150, height: 20, borderRadius: 6),
          const SizedBox(height: 12),
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonBox(width: 140, height: 14, borderRadius: 4),
                SizedBox(height: 10),
                SkeletonBox(height: 8, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonBox(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
