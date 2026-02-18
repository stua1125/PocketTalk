import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/notification_api.dart';
import '../../auth/providers/auth_provider.dart';

// =============================================================================
// Notification API provider
// =============================================================================

/// Provides the REST client used for push-token CRUD operations.
final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(ref.watch(dioProvider));
});

// =============================================================================
// Notification service
// =============================================================================

/// Orchestrates push-notification registration, permission requests,
/// and message handling.
///
/// **Current status (MVP):**
/// Firebase is listed as a dependency but is *not* configured yet (there is no
/// `google-services.json` / `GoogleService-Info.plist`).  All Firebase calls
/// are guarded behind try-catch so the app launches normally without them.
///
/// Once Firebase is configured:
/// 1. Uncomment the Firebase imports below.
/// 2. Call `await Firebase.initializeApp()` in `main.dart` before `runApp`.
/// 3. Remove the stubbed implementations inside `initialize()`.
class NotificationService {
  final NotificationApi _notificationApi;

  /// The most recently registered FCM token (if any).
  String? _currentToken;

  NotificationService(this._notificationApi);

  /// The currently registered FCM token, if one exists.
  String? get currentToken => _currentToken;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Bootstrap push-notification infrastructure.
  ///
  /// Safe to call even when Firebase is not configured -- every Firebase
  /// interaction is wrapped in a try-catch and failures are logged rather
  /// than propagated.
  Future<void> initialize() async {
    // TODO(push): Uncomment once Firebase project is configured.
    //
    // try {
    //   // 1. Request notification permission (especially needed on iOS).
    //   final messaging = FirebaseMessaging.instance;
    //   final settings = await messaging.requestPermission(
    //     alert: true,
    //     badge: true,
    //     sound: true,
    //   );
    //
    //   if (settings.authorizationStatus == AuthorizationStatus.denied) {
    //     print('[NotificationService] User denied notification permission.');
    //     return;
    //   }
    //
    //   // 2. Obtain the FCM registration token.
    //   final token = await messaging.getToken();
    //   if (token != null) {
    //     await registerToken(token);
    //   }
    //
    //   // 3. Listen for token refreshes (e.g. after app reinstall).
    //   messaging.onTokenRefresh.listen((newToken) async {
    //     await registerToken(newToken);
    //   });
    //
    //   // 4. Foreground message handler.
    //   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    //     // Delegate to NotificationHandler to show in-app banner.
    //     _onForegroundMessage?.call(message.data);
    //   });
    //
    //   // 5. Handle notification tap when app was in background.
    //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    //     _onNotificationTap?.call(message.data);
    //   });
    //
    //   // 6. Check if the app was opened from a terminated state via a
    //   //    notification tap.
    //   final initialMessage = await messaging.getInitialMessage();
    //   if (initialMessage != null) {
    //     _onNotificationTap?.call(initialMessage.data);
    //   }
    //
    // } catch (e) {
    //   // Firebase not configured -- this is expected during MVP.
    //   print('[NotificationService] Firebase init skipped: $e');
    // }

    // ignore: avoid_print
    print('[NotificationService] Initialized (Firebase stub -- no-op).');
  }

  // ---------------------------------------------------------------------------
  // Callbacks (set by NotificationHandler)
  // ---------------------------------------------------------------------------

  /// Called when a push notification arrives while the app is in the
  /// foreground.  Set by [NotificationHandler] so it can display an in-app
  /// banner.
  void Function(Map<String, dynamic> data)? onForegroundMessage;

  /// Called when the user taps a push notification (background or terminated
  /// state).  Set by [NotificationHandler] so it can deep-link to the
  /// appropriate screen.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // ---------------------------------------------------------------------------
  // Token management
  // ---------------------------------------------------------------------------

  /// Register (or refresh) the device push token with the backend.
  Future<void> registerToken(String fcmToken) async {
    try {
      final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
      await _notificationApi.registerToken(fcmToken, platform);
      _currentToken = fcmToken;
    } catch (e) {
      // Non-fatal -- the user just won't receive pushes until the next
      // successful registration.
      // ignore: avoid_print
      print('[NotificationService] Failed to register token: $e');
    }
  }

  /// Unregister the current device token (e.g. on logout).
  Future<void> unregisterCurrentToken() async {
    if (_currentToken == null) return;
    try {
      await _notificationApi.unregisterToken(_currentToken!);
      _currentToken = null;
    } catch (e) {
      // ignore: avoid_print
      print('[NotificationService] Failed to unregister token: $e');
    }
  }
}

// =============================================================================
// Riverpod providers
// =============================================================================

/// Singleton [NotificationService] scoped to the app lifetime.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref.watch(notificationApiProvider));

  // Automatically unregister the push token when the user logs out.
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.status == AuthStatus.unauthenticated &&
        previous?.status == AuthStatus.authenticated) {
      service.unregisterCurrentToken();
    }
  });

  return service;
});
