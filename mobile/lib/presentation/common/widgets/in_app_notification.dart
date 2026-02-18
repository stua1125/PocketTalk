import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

// =============================================================================
// Overlay wrapper with slide animation + auto-dismiss
// =============================================================================

/// An overlay widget that slides in from the top of the screen, displays a
/// poker-themed notification banner, and auto-dismisses after 5 seconds.
///
/// Supports:
///  - Tap to trigger an action (e.g. navigate to a game room).
///  - Swipe up to dismiss immediately.
///  - Auto-dismiss after [autoDismissDuration].
class InAppNotificationOverlay extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final Duration autoDismissDuration;

  const InAppNotificationOverlay({
    super.key,
    required this.title,
    required this.body,
    this.onTap,
    required this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 5),
  });

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Slide in.
    _controller.forward();

    // Schedule auto-dismiss.
    _autoDismissTimer = Timer(widget.autoDismissDuration, _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _autoDismissTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: () {
              _autoDismissTimer?.cancel();
              widget.onTap?.call();
            },
            onVerticalDragEnd: (details) {
              // Swipe up to dismiss.
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _dismiss();
              }
            },
            child: _NotificationCard(
              title: widget.title,
              body: widget.body,
              topPadding: topPadding,
              hasTapAction: widget.onTap != null,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Visual card
// =============================================================================

class _NotificationCard extends StatelessWidget {
  final String title;
  final String body;
  final double topPadding;
  final bool hasTapAction;

  const _NotificationCard({
    required this.title,
    required this.body,
    required this.topPadding,
    required this.hasTapAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPadding + AppSpacing.sm,
          bottom: AppSpacing.md,
          left: AppSpacing.md,
          right: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xF01E1E1E), // AppColors.surface with high opacity
              Color(0xE01E1E1E),
            ],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poker chip icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.chipGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.chipGold.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.casino_rounded,
                color: AppColors.chipGold,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasTapAction) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tap to open',
                      style: TextStyle(
                        color: AppColors.chipGold.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Close button
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
