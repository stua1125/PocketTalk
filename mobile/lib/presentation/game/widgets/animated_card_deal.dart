import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/card.dart';
import '../../common/poker_card_widget.dart';

/// Animates a single card being dealt from the center of the table to a
/// player's seat position.
///
/// The card slides from [tableCenter] to [targetPosition] with an optional
/// [delay] for stagger effects. It starts face-down and, when [showFace] is
/// true, flips to reveal the card face once the slide completes.
///
/// Typical usage:
/// ```dart
/// AnimatedCardDeal(
///   card: PokerCard.fromCode('Ah'),
///   tableCenter: Offset(200, 150),
///   targetPosition: Offset(50, 300),
///   delay: Duration(milliseconds: 100),
///   showFace: true,
///   onComplete: () { /* card is in place */ },
/// )
/// ```
class AnimatedCardDeal extends StatefulWidget {
  /// The poker card to display once revealed. If null, stays face-down.
  final PokerCard? card;

  /// The center of the table where the card originates (in local coordinates
  /// of the surrounding [Stack]).
  final Offset tableCenter;

  /// The target position where the card should land.
  final Offset targetPosition;

  /// Stagger delay before this card begins animating.
  final Duration delay;

  /// Whether to flip the card face-up after sliding into position.
  final bool showFace;

  /// Card dimensions.
  final double cardWidth;
  final double cardHeight;

  /// Called when the full animation (slide + optional flip) completes.
  final VoidCallback? onComplete;

  const AnimatedCardDeal({
    super.key,
    this.card,
    required this.tableCenter,
    required this.targetPosition,
    this.delay = Duration.zero,
    this.showFace = false,
    this.cardWidth = 54,
    this.cardHeight = 76,
    this.onComplete,
  });

  @override
  State<AnimatedCardDeal> createState() => _AnimatedCardDealState();
}

class _AnimatedCardDealState extends State<AnimatedCardDeal>
    with TickerProviderStateMixin {
  /// Controls the slide from table center to the target seat.
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  /// Controls the 3D flip from face-down to face-up.
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  bool _started = false;

  /// Timer for the stagger delay -- kept as a reference so it can be
  /// cancelled in [dispose] if the widget is removed before the delay fires.
  Timer? _delayTimer;

  // Slide duration per card.
  static const _slideDuration = Duration(milliseconds: 500);
  // Flip duration.
  static const _flipDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();

    // -- Slide animation --
    _slideController = AnimationController(
      vsync: this,
      duration: _slideDuration,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.tableCenter,
      end: widget.targetPosition,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // -- Flip animation (0 -> pi, where 0 is face-down and pi is face-up) --
    _flipController = AnimationController(
      vsync: this,
      duration: _flipDuration,
    );

    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi,
    ).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    ));

    _slideController.addStatusListener(_onSlideStatus);
    _flipController.addStatusListener(_onFlipStatus);

    // Kick off the animation after the stagger delay.
    _scheduleStart();
  }

  void _scheduleStart() {
    if (widget.delay == Duration.zero) {
      _start();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _start();
      });
    }
  }

  void _start() {
    setState(() => _started = true);
    _slideController.forward();
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (widget.showFace && widget.card != null) {
        _flipController.forward();
      } else {
        widget.onComplete?.call();
      }
    }
  }

  void _onFlipStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _slideController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      // Before the delay elapses, render the card at the table center.
      return Positioned(
        left: widget.tableCenter.dx - widget.cardWidth / 2,
        top: widget.tableCenter.dy - widget.cardHeight / 2,
        child: Opacity(
          opacity: 0.0,
          child: PokerCardWidget(
            faceDown: true,
            width: widget.cardWidth,
            height: widget.cardHeight,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _flipAnimation]),
      builder: (context, child) {
        final pos = _slideAnimation.value;
        final flipAngle = _flipAnimation.value;

        // When flipAngle > pi/2 the back is no longer visible; show the face.
        final showingFace = flipAngle > math.pi / 2;

        return Positioned(
          left: pos.dx - widget.cardWidth / 2,
          top: pos.dy - widget.cardHeight / 2,
          child: RepaintBoundary(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(flipAngle),
              child: showingFace
                  ? Transform(
                      // Mirror so the face text isn't backwards.
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: PokerCardWidget(
                        card: widget.card,
                        faceDown: false,
                        width: widget.cardWidth,
                        height: widget.cardHeight,
                      ),
                    )
                  : PokerCardWidget(
                      faceDown: true,
                      width: widget.cardWidth,
                      height: widget.cardHeight,
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper widget that deals multiple cards with staggered timing.
///
/// Wraps a collection of [AnimatedCardDeal] widgets, each with a 100ms
/// stagger offset so cards arrive one after another.
class AnimatedCardDealGroup extends StatelessWidget {
  /// Data for each card to deal: target position + optional card value.
  final List<CardDealTarget> targets;

  /// The origin point (center of the table) in local stack coordinates.
  final Offset tableCenter;

  /// Called when all cards have finished dealing.
  final VoidCallback? onAllComplete;

  /// Per-card stagger delay.
  final Duration staggerDelay;

  const AnimatedCardDealGroup({
    super.key,
    required this.targets,
    required this.tableCenter,
    this.onAllComplete,
    this.staggerDelay = const Duration(milliseconds: 100),
  });

  @override
  Widget build(BuildContext context) {
    int completedCount = 0;

    return Stack(
      children: [
        for (int i = 0; i < targets.length; i++)
          AnimatedCardDeal(
            card: targets[i].card,
            tableCenter: tableCenter,
            targetPosition: targets[i].position,
            delay: staggerDelay * i,
            showFace: targets[i].showFace,
            cardWidth: targets[i].cardWidth,
            cardHeight: targets[i].cardHeight,
            onComplete: () {
              completedCount++;
              if (completedCount >= targets.length) {
                onAllComplete?.call();
              }
            },
          ),
      ],
    );
  }
}

/// Describes where a single dealt card should go and what it shows.
class CardDealTarget {
  final Offset position;
  final PokerCard? card;
  final bool showFace;
  final double cardWidth;
  final double cardHeight;

  const CardDealTarget({
    required this.position,
    this.card,
    this.showFace = false,
    this.cardWidth = 54,
    this.cardHeight = 76,
  });
}
