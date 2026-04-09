import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'data/database/db_helper.dart';
import 'services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final binding = InitialBinding();
  binding.dependencies();
  await Get.find<DbHelper>().initialize();
  await Get.find<BackgroundService>().start();
  runApp(const KistBookApp());
}

class KistBookApp extends StatelessWidget {
  const KistBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      initialRoute: AppRoutes.dashboard,
      getPages: AppPages.routes,
    );
  }
}
