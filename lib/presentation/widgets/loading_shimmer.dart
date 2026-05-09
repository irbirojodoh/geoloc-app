import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Simple Material 3 shimmer placeholder.
class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 2,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest,
      highlightColor: colorScheme.surface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// Post card shimmer placeholder
class PostCardShimmer extends StatelessWidget {
  const PostCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingShimmer(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LoadingShimmer(width: 140, height: 16, borderRadius: 8),
                      SizedBox(height: 6),
                      LoadingShimmer(width: 88, height: 14, borderRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            LoadingShimmer(height: 16, borderRadius: 8),
            SizedBox(height: 8),
            LoadingShimmer(width: 240, height: 16, borderRadius: 8),
            SizedBox(height: 12),
            LoadingShimmer(height: 180, borderRadius: 12),
            SizedBox(height: 8),
            Row(
              children: [
                LoadingShimmer(width: 60, height: 24, borderRadius: 8),
                SizedBox(width: 12),
                LoadingShimmer(width: 60, height: 24, borderRadius: 8),
                SizedBox(width: 12),
                LoadingShimmer(width: 60, height: 24, borderRadius: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Feed page shimmer
class FeedShimmer extends StatelessWidget {
  const FeedShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: PostCardShimmer(),
      ),
    );
  }
}
