import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

// =============================================================================
// Shimmer animation wrapper
// =============================================================================

/// A container that plays a horizontal shimmer gradient animation over its
/// child. Used internally by all skeleton primitives.
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: const [
                Color(0xFF2C2C2C), // AppColors.surfaceLight
                Color(0xFF3A3A3A), // slightly lighter
                Color(0xFF2C2C2C), // AppColors.surfaceLight
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// SkeletonText
// =============================================================================

/// A line-shaped shimmer placeholder for text.
class SkeletonText extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonText({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
    );
  }
}

// =============================================================================
// SkeletonCircle
// =============================================================================

/// A circle shimmer placeholder for avatars.
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }
}

// =============================================================================
// SkeletonCard
// =============================================================================

/// A card-shaped shimmer placeholder that mimics [RoomCard] dimensions.
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonCard({
    super.key,
    this.width,
    this.height = 120,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.tableEdge.withOpacity(0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Expanded(child: SkeletonText(height: 18)),
              const SizedBox(width: AppSpacing.md),
              SkeletonText(
                width: 60,
                height: 24,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Info row
          const Row(
            children: [
              SkeletonText(width: 70, height: 12),
              SizedBox(width: AppSpacing.md),
              SkeletonText(width: 50, height: 12),
              Spacer(),
              SkeletonText(width: 80, height: 12),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Bottom row
          const Row(
            children: [
              SkeletonText(width: 100, height: 12),
              Spacer(),
              SkeletonText(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SkeletonTable
// =============================================================================

/// A full poker-table shaped skeleton placeholder with seat circles.
class SkeletonTable extends StatelessWidget {
  final int maxPlayers;

  const SkeletonTable({super.key, this.maxPlayers = 6});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * 0.85;
          final height = width * 0.55;

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Table shape
                _ShimmerBox(
                  width: width,
                  height: height,
                  borderRadius: BorderRadius.circular(height / 2),
                ),

                // Seat placeholders around the table
                ..._buildSeatPlaceholders(constraints, width, height),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSeatPlaceholders(
    BoxConstraints constraints,
    double tableWidth,
    double tableHeight,
  ) {
    final centerX = constraints.maxWidth / 2;
    final centerY = constraints.maxHeight / 2;
    final radiusX = tableWidth / 2 + 30;
    final radiusY = tableHeight / 2 + 30;

    final seats = <Widget>[];

    for (int i = 0; i < maxPlayers; i++) {
      // Distribute seats evenly around the ellipse, starting from bottom.
      final angle =
          (math.pi * 2 * i / maxPlayers) + math.pi / 2; // start from bottom
      final x = centerX + radiusX * math.cos(angle) - 20;
      final y = centerY + radiusY * math.sin(angle) - 20;

      seats.add(
        Positioned(
          left: x,
          top: y,
          child: const SkeletonCircle(size: 40),
        ),
      );
    }

    return seats;
  }
}
