import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/localization/app_translations.dart';

class SettingsController extends GetxController {
  SettingsController(this._preferences);

  static const _themeModeKey = 'theme_mode';
  static const _languageCodeKey = 'language_code';

  final SharedPreferences _preferences;

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = AppTranslations.locales.first;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  String get themeLabel => switch (_themeMode) {
        ThemeMode.system => 'System'.tr,
        ThemeMode.light => 'Light'.tr,
        ThemeMode.dark => 'Dark'.tr,
      };

  String get languageLabel => _locale.languageCode == 'ur'
      ? AppTranslations.urdu
      : AppTranslations.english;

  void load() {
    final storedTheme = _preferences.getString(_themeModeKey);
    final storedLanguageCode = _preferences.getString(_languageCodeKey);

    _themeMode = switch (storedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    _locale = AppTranslations.locales.firstWhere(
      (locale) => locale.languageCode == (storedLanguageCode ?? 'en'),
      orElse: () => AppTranslations.locales.first,
    );
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    update();
    await _preferences.setString(
      _themeModeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  Future<void> updateLocale(Locale locale) async {
    if (_locale == locale) {
      return;
    }
    _locale = locale;
    Get.updateLocale(locale);
    update();
    await _preferences.setString(_languageCodeKey, locale.languageCode);
  }
}
