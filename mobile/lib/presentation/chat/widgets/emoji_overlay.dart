import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/emoji_provider.dart';
import 'floating_emoji.dart';

/// A transparent overlay positioned over the poker table that renders floating
/// emoji animations.
///
/// Place this as a sibling layer in the same [Stack] as the [PokerTable].
/// It listens to the [emojiProvider] for the given [roomId] and creates a
/// [FloatingEmoji] for every [ActiveEmoji] in the state.
///
/// The overlay is fully transparent to pointer events except where the
/// individual [FloatingEmoji] widgets are rendered (which are themselves
/// wrapped in [IgnorePointer]).
class EmojiOverlay extends ConsumerWidget {
  final String roomId;

  /// Maximum number of players (used to compute seat positions identically
  /// to [PokerTable._getSeatPositions]).
  final int maxPlayers;

  const EmojiOverlay({
    super.key,
    required this.roomId,
    this.maxPlayers = 6,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emojiState = ref.watch(emojiProvider(roomId));

    if (emojiState.activeEmojis.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final seatPositions = _getSeatPositions(maxPlayers, width, height);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final activeEmoji in emojiState.activeEmojis)
              FloatingEmoji(
                key: ValueKey(activeEmoji.id),
                emoji: activeEmoji.emoji,
                senderName: activeEmoji.senderName,
                startPosition: _resolvePosition(
                  activeEmoji.seatNumber,
                  seatPositions,
                  width,
                  height,
                ),
                onComplete: () {
                  ref
                      .read(emojiProvider(roomId).notifier)
                      .removeEmoji(activeEmoji.id);
                },
              ),
          ],
        );
      },
    );
  }

  /// Compute seat positions around the table.
  ///
  /// This replicates the same layout algorithm used by
  /// `PokerTable._getSeatPositions` so emojis appear directly above the
  /// correct player seat.
  List<Offset> _getSeatPositions(int count, double width, double height) {
    final centerX = width / 2;
    final centerY = height / 2;
    final radiusX = width * 0.42;
    final radiusY = height * 0.42;

    final startAngle = math.pi / 2; // bottom centre (my seat)
    final positions = <Offset>[];

    for (int i = 0; i < count; i++) {
      final angle = startAngle + (2 * math.pi * i / count);
      final x = centerX + radiusX * math.cos(angle);
      final y = centerY + radiusY * math.sin(angle);
      positions.add(Offset(x, y));
    }

    return positions;
  }

  /// Map a seat number to a screen position.
  ///
  /// Falls back to the centre of the table when the seat number is out of
  /// range (e.g. the server sent an unexpected value).
  Offset _resolvePosition(
    int seatNumber,
    List<Offset> seatPositions,
    double width,
    double height,
  ) {
    if (seatNumber >= 0 && seatNumber < seatPositions.length) {
      return seatPositions[seatNumber];
    }
    // Fallback: centre of the table.
    return Offset(width / 2, height / 2);
  }
}
