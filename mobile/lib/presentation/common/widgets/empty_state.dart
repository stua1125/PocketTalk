import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

/// A reusable, centered empty-state widget with icon, title, subtitle, and an
/// optional action button.
///
/// Use the named factory constructors for common scenarios:
///
/// ```dart
/// EmptyState.noRooms(onAction: () => context.go('/create-room'))
/// EmptyState.noHistory()
/// EmptyState.noMessages()
/// EmptyState.noTransactions()
/// ```
class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  factory EmptyState.noRooms({Key? key, VoidCallback? onAction}) {
    return EmptyState(
      key: key,
      icon: Icons.style_outlined,
      title: 'No rooms yet',
      subtitle: 'Create a room or join one with an invite code!',
      actionLabel: onAction != null ? 'Create Room' : null,
      onAction: onAction,
    );
  }

  factory EmptyState.noHistory({Key? key}) {
    return EmptyState(
      key: key,
      icon: Icons.history_outlined,
      title: 'No hand history',
      subtitle: 'Completed hands will appear here.',
    );
  }

  factory EmptyState.noMessages({Key? key}) {
    return EmptyState(
      key: key,
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      subtitle: 'Start the conversation!',
    );
  }

  factory EmptyState.noTransactions({Key? key}) {
    return EmptyState(
      key: key,
      icon: Icons.receipt_long_outlined,
      title: 'No transactions',
      subtitle: 'Your transaction history will show up here.',
    );
  }

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: 80,
                  color: AppColors.textSecondary.withOpacity(0.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.title,
                  style: AppTypography.headline2.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.body1.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: widget.onAction,
                    icon: const Icon(Icons.add),
                    label: Text(widget.actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
