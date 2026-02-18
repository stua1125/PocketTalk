import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/datasources/remote/websocket_service.dart';
import '../../game/providers/websocket_provider.dart';

/// A thin bar at the top of the screen that shows the current WebSocket
/// connection state.
///
/// - **Connected** -- green bar that auto-hides after 2 seconds.
/// - **Connecting** -- yellow pulsing bar with animated "Reconnecting..." text.
/// - **Disconnected** -- red bar that persists until the user taps to retry.
///
/// Tap the bar to manually trigger a reconnect attempt.
class ConnectionStatusBar extends ConsumerStatefulWidget {
  const ConnectionStatusBar({super.key});

  @override
  ConsumerState<ConnectionStatusBar> createState() =>
      _ConnectionStatusBarState();
}

class _ConnectionStatusBarState extends ConsumerState<ConnectionStatusBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  /// Whether the bar is visible.
  bool _visible = false;

  /// Timer used to auto-hide the "Connected" state after 2 seconds.
  Timer? _hideTimer;

  /// Tracks the number of animated dots for "Reconnecting...".
  int _dotCount = 0;
  Timer? _dotTimer;

  /// Tracks the previous state so we know when to show "Connected" briefly.
  WebSocketConnectionState? _previousState;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _dotTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onStateChanged(WebSocketConnectionState connectionState) {
    _hideTimer?.cancel();

    switch (connectionState) {
      case WebSocketConnectionState.connected:
        _visible = true;
        _pulseController.stop();
        _hideTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _visible = false;
            });
          }
        });
        break;

      case WebSocketConnectionState.connecting:
        _visible = true;
        _pulseController.repeat(reverse: true);
        break;

      case WebSocketConnectionState.disconnected:
        _visible = true;
        _pulseController.stop();
        break;
    }

    _previousState = connectionState;
  }

  void _retry() {
    ref.read(webSocketConnectionProvider.notifier).reconnect();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(webSocketConnectionProvider);

    // Detect state transitions.
    if (connectionState != _previousState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _onStateChanged(connectionState);
          });
        }
      });
    }

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: connectionState == WebSocketConnectionState.disconnected
              ? _retry
              : null,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                color: _backgroundColor(connectionState).withOpacity(
                  connectionState == WebSocketConnectionState.connecting
                      ? _pulseAnimation.value
                      : 1.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _icon(connectionState),
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _label(connectionState),
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (connectionState ==
                        WebSocketConnectionState.disconnected) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Tap to retry',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _backgroundColor(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return AppColors.success;
      case WebSocketConnectionState.connecting:
        return AppColors.warning;
      case WebSocketConnectionState.disconnected:
        return AppColors.error;
    }
  }

  IconData _icon(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return Icons.check_circle_outline;
      case WebSocketConnectionState.connecting:
        return Icons.sync;
      case WebSocketConnectionState.disconnected:
        return Icons.cloud_off;
    }
  }

  String _label(WebSocketConnectionState state) {
    switch (state) {
      case WebSocketConnectionState.connected:
        return 'Connected';
      case WebSocketConnectionState.connecting:
        final dots = '.' * _dotCount;
        return 'Reconnecting$dots';
      case WebSocketConnectionState.disconnected:
        return 'Disconnected';
    }
  }
}
