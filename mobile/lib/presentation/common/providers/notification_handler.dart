import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../widgets/in_app_notification.dart';
import 'notification_provider.dart';

// =============================================================================
// Notification handler
// =============================================================================

/// Bridges push / WebSocket notifications with in-app UI and deep linking.
///
/// Responsibilities:
///  - Show in-app notification banners when the app is in the foreground.
///  - Navigate to the correct screen when the user taps a notification.
///
/// This handler works **independently of Firebase**.  It can be driven by:
///  1. Push notifications (once Firebase is configured).
///  2. WebSocket turn-notification events (works right now).
class NotificationHandler {
  final GoRouter router;
  final NotificationService notificationService;

  /// Currently displayed overlay entry (if any).
  OverlayEntry? _currentOverlay;

  NotificationHandler({
    required this.router,
    required this.notificationService,
  }) {
    // Wire up FCM callbacks so the handler is invoked when pushes arrive.
    notificationService.onForegroundMessage = _handleForegroundMessage;
    notificationService.onNotificationTap = handleDeepLink;
  }

  // ---------------------------------------------------------------------------
  // In-app notification display
  // ---------------------------------------------------------------------------

  /// Show an in-app notification banner at the top of the screen.
  ///
  /// The banner auto-dismisses after [duration] and can be swiped up or
  /// tapped.  Tapping navigates to `/game/{roomId}` when a [roomId] is
  /// provided.
  void showInAppNotification(
    BuildContext context, {
    required String title,
    required String body,
    String? roomId,
  }) {
    // Dismiss any existing notification first.
    dismissCurrentNotification();

    final overlay = Overlay.of(context);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => InAppNotificationOverlay(
        title: title,
        body: body,
        onTap: roomId != null
            ? () {
                dismissCurrentNotification();
                router.go('/game/$roomId');
              }
            : null,
        onDismiss: () => dismissCurrentNotification(),
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);
  }

  /// Remove the currently-displayed in-app notification, if any.
  void dismissCurrentNotification() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  // ---------------------------------------------------------------------------
  // Deep link handling
  // ---------------------------------------------------------------------------

  /// Navigate to the appropriate screen based on the notification payload.
  ///
  /// Currently supports:
  ///  - `roomId` -> `/game/{roomId}`
  ///
  /// Extend this method as new notification types are introduced.
  void handleDeepLink(Map<String, dynamic> data) {
    final roomId = data['roomId'] as String?;
    if (roomId != null && roomId.isNotEmpty) {
      router.go('/game/$roomId');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Handle a push notification that arrived while the app is in the
  /// foreground.
  ///
  /// Delegates to [showInAppNotification] -- but since we don't have a
  /// [BuildContext] from the push handler, we use a
  /// [navigatorKey]-based lookup.
  void _handleForegroundMessage(Map<String, dynamic> data) {
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;

    final title = (data['title'] as String?) ?? 'PocketTalk';
    final body = (data['body'] as String?) ?? '';
    final roomId = data['roomId'] as String?;

    showInAppNotification(
      context,
      title: title,
      body: body,
      roomId: roomId,
    );
  }
}

// =============================================================================
// Riverpod provider
// =============================================================================

/// Provides a singleton [NotificationHandler] scoped to the app.
///
/// Requires `appRouter` (from core/router) and `notificationServiceProvider`.
final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler(
    router: ref.watch(appRouterProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});
