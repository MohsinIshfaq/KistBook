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
import 'core/widgets/app_bottom_navigation.dart';
import 'data/database/db_helper.dart';
import 'modules/settings/settings_controller.dart';
import 'services/background_service.dart';
import 'services/session_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  Get.put(SettingsController(preferences), permanent: true);
  final sessionManager = SessionManager(preferences);
  Get.put(sessionManager, permanent: true);
  final binding = InitialBinding();
  binding.dependencies();
  Get.put(AppNavigationController(), permanent: true);
  await Get.find<DbHelper>().initialize();
  await sessionManager.loadAuthData();
  if (sessionManager.canRestoreSession) {
    await Get.find<BackgroundService>().start();
  }
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
          routingCallback: (routing) {
            Get.find<AppNavigationController>().setCurrentRoute(
              routing?.current,
            );
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          builder: (context, child) {
            final theme = Theme.of(context);
            final brightness = theme.brightness;
            final systemNavigationBarColor = theme.scaffoldBackgroundColor;
            final overlayStyle = brightness == Brightness.dark
                ? SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                    statusBarBrightness: Brightness.dark,
                    systemNavigationBarColor: systemNavigationBarColor,
                    systemNavigationBarIconBrightness: Brightness.light,
                  )
                : SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                    statusBarBrightness: Brightness.light,
                    systemNavigationBarColor: systemNavigationBarColor,
                    systemNavigationBarIconBrightness: Brightness.dark,
                  );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlayStyle,
              child: AppNavigationFrame(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          initialRoute: Get.find<SessionManager>().canRestoreSession
              ? Get.find<SessionManager>().homeRoute
              : AppRoutes.login,
          getPages: AppPages.routes,
        );
      },
    );
  }
}
