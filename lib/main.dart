import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/bindings/initial_binding.dart';
import 'app/localization/app_translations.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'data/database/db_helper.dart';
import 'modules/settings/settings_controller.dart';
import 'services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  Get.put(SettingsController(preferences), permanent: true);
  final binding = InitialBinding();
  binding.dependencies();
  await Get.find<DbHelper>().initialize();
  await Get.find<BackgroundService>().start();
  runApp(const KistBookApp());
}

class KistBookApp extends StatelessWidget {
  const KistBookApp({super.key});
  // Homage eSmart Crystal 1.5 Ton Inverter AC HES-1812E
  @override
  Widget build(BuildContext context) {
    return GetBuilder<SettingsController>(
      builder: (settings) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppStrings.appName,
          locale: settings.locale,
          fallbackLocale: const Locale('en', 'US'),
          supportedLocales: AppTranslations.locales,
          translations: AppTranslations(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final overlayStyle = brightness == Brightness.dark
                ? const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark,
                    systemNavigationBarColor: Color(0xFF0D1320),
                    systemNavigationBarIconBrightness: Brightness.light,
                  )
                : const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                    systemNavigationBarColor: Color(0xFFF4F7FB),
                    systemNavigationBarIconBrightness: Brightness.dark,
                  );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: child ?? const SizedBox.shrink(),
            );
          },
          initialRoute: AppRoutes.dashboard,
          getPages: AppPages.routes,
        );
      },
    );
  }
}
