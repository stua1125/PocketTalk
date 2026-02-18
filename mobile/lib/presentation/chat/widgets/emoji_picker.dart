import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// A compact emoji selection panel displayed as an overlay on the game screen.
///
/// Presents a grid of common poker/game emojis. Tapping an emoji fires
/// [onEmojiSelected] with the emoji character and auto-closes the panel.
class EmojiPicker extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onClose;

  const EmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
  });

  /// The curated set of poker/game-themed emojis.
  static const List<String> _emojis = [
    '\u{1F44D}', // 👍
    '\u{1F44E}', // 👎
    '\u{1F602}', // 😂
    '\u{1F62D}', // 😭
    '\u{1F621}', // 😡
    '\u{1F389}', // 🎉
    '\u{1F0CF}', // 🃏
    '\u{1F4B0}', // 💰
    '\u{1F525}', // 🔥
    '\u{2764}\u{FE0F}', // ❤️
    '\u{1F914}', // 🤔
    '\u{1F60E}', // 😎
    '\u{1F64F}', // 🙏
    '\u{1F4AA}', // 💪
    '\u{1F44F}', // 👏
    '\u{1F631}', // 😱
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Prevent taps from falling through to the game table.
      onTap: () {},
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with title and close button.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'React',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Emoji grid (4 columns).
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _emojis.length,
              itemBuilder: (context, index) {
                final emoji = _emojis[index];
                return _EmojiButton(
                  emoji: emoji,
                  onTap: () {
                    onEmojiSelected(emoji);
                    onClose();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A single tappable emoji cell with a ripple effect.
class _EmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}
