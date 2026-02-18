import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/auth/providers/auth_provider.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/auth/screens/register_screen.dart';
import '../../presentation/auth/screens/splash_screen.dart';
import '../../presentation/lobby/screens/lobby_screen.dart';
import '../../presentation/lobby/screens/create_room_screen.dart';
import '../../presentation/game/screens/game_screen.dart';
import '../../presentation/hand_history/screens/hand_history_screen.dart';
import '../../presentation/wallet/screens/wallet_screen.dart';

/// Routes that do not require authentication.
const _publicRoutes = {'/login', '/register', '/splash'};

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshNotifier(authNotifier.stream),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      final isPublicRoute = _publicRoutes.contains(location);

      // Still checking auth — stay on or go to splash.
      if (authState.status == AuthStatus.initial) {
        return isPublicRoute ? null : '/splash';
      }

      // Not logged in — force to login unless already on a public route.
      if (authState.status == AuthStatus.unauthenticated) {
        return isPublicRoute ? null : '/login';
      }

      // Logged in — redirect away from auth/splash screens to lobby.
      if (authState.status == AuthStatus.authenticated) {
        if (location == '/login' ||
            location == '/register' ||
            location == '/splash') {
          return '/lobby';
        }
      }

      return null; // No redirect needed.
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/lobby',
        builder: (context, state) => const LobbyScreen(),
      ),
      GoRoute(
        path: '/create-room',
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: '/game/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return GameScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/room/:roomId/history',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId']!;
          return HandHistoryScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
    ],
  );
});

/// Converts a [Stream] into a [ChangeNotifier] so GoRouter can listen for
/// state changes and re-evaluate its redirect callback.
class GoRouterRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
