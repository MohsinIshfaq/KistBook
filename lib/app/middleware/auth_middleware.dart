import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../services/session_manager.dart';

class AuthMiddleware extends GetMiddleware {
  AuthMiddleware({this.publicOnly = false});

  final bool publicOnly;

  @override
  RouteSettings? redirect(String? route) {
    final sessionManager = Get.find<SessionManager>();
    if (publicOnly) {
      if (sessionManager.isLoggedIn) {
        return const RouteSettings(name: AppRoutes.dashboard);
      }
      return null;
    }

    if (!sessionManager.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
