import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/chat_message.dart';

/// Individual chat message widget.
///
/// - My messages: right-aligned, primary color background
/// - Others: left-aligned, surface color background
/// - Avatar + nickname above message (for others)
/// - Time stamp below message
/// - System messages: centered, italic, muted color
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return _buildSystemMessage();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.xs,
                      bottom: 2,
                    ),
                    child: Text(
                      message.nickname,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary.withOpacity(0.85)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 14),
                    ),
                  ),
                  child: message.isEmoji
                      ? Text(
                          message.content,
                          style: const TextStyle(fontSize: 28),
                        )
                      : Text(
                          message.content,
                          style: AppTypography.body2.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 2,
                    left: AppSpacing.xs,
                    right: AppSpacing.xs,
                  ),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // System message
  // ---------------------------------------------------------------------------

  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Avatar
  // ---------------------------------------------------------------------------

  Widget _buildAvatar() {
    if (message.avatarUrl != null && message.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(message.avatarUrl!),
        backgroundColor: AppColors.surfaceLight,
      );
    }

    // Fallback: first letter of nickname
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.primaryLight.withOpacity(0.4),
      child: Text(
        message.nickname.isNotEmpty ? message.nickname[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Time formatting
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (messageDay == today) {
      return time;
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $time';
    } else {
      return '${dateTime.month}/${dateTime.day} $time';
    }
  }
}
