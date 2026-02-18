import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

/// Supported locales for the application.
const supportedLocales = [
  Locale('en'),
  Locale('ko'),
];

/// Provider that manages the current app locale.
///
/// Reads the saved preference from [SharedPreferences] on startup and falls
/// back to the platform locale when no preference has been stored yet.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_defaultLocale()) {
    _loadSavedLocale();
  }

  /// Determines the default locale based on the platform language.
  /// Falls back to English if the platform locale is not supported.
  static Locale _defaultLocale() {
    try {
      final String langCode;
      if (kIsWeb) {
        langCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      } else {
        langCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      }
      final platformLocale = Locale(langCode);
      final isSupported = supportedLocales.any(
        (l) => l.languageCode == platformLocale.languageCode,
      );
      return isSupported ? platformLocale : const Locale('en');
    } catch (_) {
      return const Locale('en');
    }
  }

  /// Loads the previously saved locale preference from SharedPreferences.
  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null) {
      final locale = Locale(saved);
      final isSupported = supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );
      if (isSupported) {
        state = locale;
      }
    }
  }

  /// Sets the locale and persists the choice to SharedPreferences.
  Future<void> setLocale(Locale locale) async {
    final isSupported = supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
    if (!isSupported) return;

    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  /// Toggles between English and Korean.
  Future<void> toggleLocale() async {
    final next = state.languageCode == 'en'
        ? const Locale('ko')
        : const Locale('en');
    await setLocale(next);
  }
}
