import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';

// =============================================================================
// Connectivity check (no external packages)
// =============================================================================

/// Lightweight connectivity monitor that uses a periodic DNS lookup to
/// determine whether the device can reach the internet.
///
/// Emits `true` when online and `false` when offline. Checks every 10 seconds.
class ConnectivityMonitor {
  final _controller = StreamController<bool>.broadcast();
  Timer? _timer;
  bool _lastKnownState = true;

  /// Stream of connectivity changes.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// The last known connectivity state.
  bool get isOnline => _lastKnownState;

  /// Start periodic checks.
  void start() {
    // Check immediately, then every 10 seconds.
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (online != _lastKnownState) {
        _lastKnownState = online;
        _controller.add(online);
      }
    } on SocketException catch (_) {
      if (_lastKnownState) {
        _lastKnownState = false;
        _controller.add(false);
      }
    } on TimeoutException catch (_) {
      if (_lastKnownState) {
        _lastKnownState = false;
        _controller.add(false);
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

// =============================================================================
// Riverpod providers
// =============================================================================

/// Singleton [ConnectivityMonitor].
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor()..start();
  ref.onDispose(() => monitor.dispose());
  return monitor;
});

/// Stream of connectivity changes (true = online).
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  // Start with the current known state, then listen for changes.
  return monitor.onConnectivityChanged;
});

/// Simple boolean: `true` when offline.
final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.when(
    data: (online) => !online,
    loading: () => false,
    error: (_, __) => false,
  );
});

// =============================================================================
// Widget
// =============================================================================

/// A persistent banner displayed when the device has no internet connectivity.
///
/// Sits below the safe area / app bar and slides in from the top when offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);

    return AnimatedSlide(
      offset: offline ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: offline ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
          color: AppColors.warning.withOpacity(0.9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  "You're offline. Some features may not work.",
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
