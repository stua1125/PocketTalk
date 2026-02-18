import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

/// REST client for push-notification token management.
///
/// The backend stores the device token so it can fan-out push notifications
/// (e.g. "Your turn!" or "New hand started") via FCM / APNs.
class NotificationApi {
  final Dio _dio;

  NotificationApi(this._dio);

  /// Register (or refresh) the device push token.
  ///
  /// [token]    – the FCM registration token obtained from Firebase Messaging.
  /// [platform] – `"IOS"` or `"ANDROID"`.
  Future<void> registerToken(String token, String platform) async {
    await _dio.post(
      ApiConstants.notificationToken,
      data: {
        'token': token,
        'platform': platform,
      },
    );
  }

  /// Unregister a previously-registered push token (e.g. on logout).
  Future<void> unregisterToken(String token) async {
    await _dio.delete(ApiConstants.notificationTokenDelete(token));
  }
}
