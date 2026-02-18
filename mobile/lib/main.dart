import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/locale_provider.dart';
import 'presentation/common/providers/notification_provider.dart';
import 'presentation/common/providers/notification_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(push): Once Firebase is configured, add:
  // await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: PocketTalkApp(),
    ),
  );
}

class PocketTalkApp extends ConsumerStatefulWidget {
  const PocketTalkApp({super.key});

  @override
  ConsumerState<PocketTalkApp> createState() => _PocketTalkAppState();
}

class _PocketTalkAppState extends ConsumerState<PocketTalkApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize the notification service (safe even without Firebase).
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.initialize();

    // Eagerly create the handler so it wires up its callbacks.
    ref.read(notificationHandlerProvider);

    // Auth check is handled by SplashScreen directly.
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'PocketTalk',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
    );
  }
}
