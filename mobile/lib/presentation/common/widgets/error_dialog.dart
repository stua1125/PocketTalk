import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

// =============================================================================
// Error categories
// =============================================================================

/// The category of an error, used to select the appropriate message, icon, and
/// primary action.
enum ErrorCategory {
  network,
  auth,
  game,
  generic,
}

/// Attempt to classify an error from its string representation.
ErrorCategory categoriseError(dynamic error) {
  final message = error.toString().toLowerCase();

  if (message.contains('socket') ||
      message.contains('connection') ||
      message.contains('timeout') ||
      message.contains('network') ||
      message.contains('unreachable') ||
      message.contains('no internet')) {
    return ErrorCategory.network;
  }

  if (message.contains('401') ||
      message.contains('unauthori') ||
      message.contains('token') ||
      message.contains('session') ||
      message.contains('auth') ||
      message.contains('expired')) {
    return ErrorCategory.auth;
  }

  if (message.contains('game') ||
      message.contains('hand') ||
      message.contains('room') ||
      message.contains('action') ||
      message.contains('bet') ||
      message.contains('fold')) {
    return ErrorCategory.game;
  }

  return ErrorCategory.generic;
}

// =============================================================================
// Show helper
// =============================================================================

/// Shows a Material bottom sheet with an error icon, a categorised message, and
/// an action button (retry, logout, refresh, or dismiss depending on category).
///
/// [error] is the raw error object -- it will be categorised automatically.
/// [onRetry] is called when the user taps the primary action button for
/// retriable categories (network, game, generic).
/// [onLogout] is called for auth errors.
void showErrorDialog(
  BuildContext context, {
  required dynamic error,
  VoidCallback? onRetry,
  VoidCallback? onLogout,
}) {
  final category = categoriseError(error);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ErrorBottomSheet(
      category: category,
      rawError: error.toString(),
      onRetry: onRetry,
      onLogout: onLogout,
    ),
  );
}

// =============================================================================
// Bottom sheet widget
// =============================================================================

class _ErrorBottomSheet extends StatelessWidget {
  final ErrorCategory category;
  final String rawError;
  final VoidCallback? onRetry;
  final VoidCallback? onLogout;

  const _ErrorBottomSheet({
    required this.category,
    required this.rawError,
    this.onRetry,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: _iconColor, size: 32),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            _title,
            style: AppTypography.headline3.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Description
          Text(
            _description,
            style: AppTypography.body2.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _primaryAction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _actionButtonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _actionLabel,
                style: AppTypography.button.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Dismiss link
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Dismiss',
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Computed properties per category
  // ---------------------------------------------------------------------------

  IconData get _icon {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off_rounded;
      case ErrorCategory.auth:
        return Icons.lock_outline_rounded;
      case ErrorCategory.game:
        return Icons.casino_outlined;
      case ErrorCategory.generic:
        return Icons.error_outline_rounded;
    }
  }

  Color get _iconColor {
    switch (category) {
      case ErrorCategory.network:
        return AppColors.warning;
      case ErrorCategory.auth:
        return AppColors.error;
      case ErrorCategory.game:
        return AppColors.chipGold;
      case ErrorCategory.generic:
        return AppColors.error;
    }
  }

  String get _title {
    switch (category) {
      case ErrorCategory.network:
        return 'Connection Lost';
      case ErrorCategory.auth:
        return 'Session Expired';
      case ErrorCategory.game:
        return 'Game Error';
      case ErrorCategory.generic:
        return 'Something Went Wrong';
    }
  }

  String get _description {
    switch (category) {
      case ErrorCategory.network:
        return 'Connection lost. Check your internet and try again.';
      case ErrorCategory.auth:
        return 'Session expired. Please login again.';
      case ErrorCategory.game:
        return 'Something went wrong in the game. Try refreshing.';
      case ErrorCategory.generic:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  String get _actionLabel {
    switch (category) {
      case ErrorCategory.network:
        return 'Retry';
      case ErrorCategory.auth:
        return 'Login Again';
      case ErrorCategory.game:
        return 'Refresh';
      case ErrorCategory.generic:
        return 'Retry';
    }
  }

  Color get _actionButtonColor {
    switch (category) {
      case ErrorCategory.network:
        return AppColors.primary;
      case ErrorCategory.auth:
        return AppColors.error;
      case ErrorCategory.game:
        return AppColors.primary;
      case ErrorCategory.generic:
        return AppColors.primary;
    }
  }

  void _primaryAction() {
    switch (category) {
      case ErrorCategory.auth:
        onLogout?.call();
        break;
      case ErrorCategory.network:
      case ErrorCategory.game:
      case ErrorCategory.generic:
        onRetry?.call();
        break;
    }
  }
}
