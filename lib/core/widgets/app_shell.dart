import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../modules/auth/auth_controller.dart';
import '../../services/session_manager.dart';
import '../constants/app_strings.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  final String title;
  final String currentRoute;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    final authController = Get.find<AuthController>();
    final isRestrictedUser = session.role != UserRole.owner;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final drawerBackground = isDark
        ? AppColors.brandSecondary
        : AppColors.surface;
    final drawerPanelColor = isDark
        ? const Color(0xFF111827)
        : AppColors.surfaceMuted;
    final drawerPanelBorder = isDark
        ? const Color(0xFF1F2937)
        : AppColors.border;
    final drawerMutedText = isDark
        ? const Color(0xFFD0D5DD)
        : AppColors.inkSoft;
    final drawerSectionText = isDark
        ? const Color(0xFF98A2B3)
        : AppColors.inkMuted;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Manage customers, installments, and reports'.tr,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.92,
                ),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings'.tr,
            onPressed: () {
              if (currentRoute != AppRoutes.settings) {
                Get.toNamed(AppRoutes.settings);
              }
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          if (actions != null) ...actions!,
          const SizedBox(width: 12),
        ],
      ),
      drawer: Drawer(
        backgroundColor: drawerBackground,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0x1FFFFFFF),
                    child: Icon(Icons.auto_graph_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    AppStrings.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Installment operations for modern micro business teams'.tr,
                    style: TextStyle(color: Color(0xFFD0D5DD), height: 1.4),
                  ),
                  Obx(() {
                    final profile = authController.currentUser.value;
                    final name = profile?.fullName ?? session.fullName;
                    final contact =
                        profile?.phone ?? profile?.email ?? session.phone;
                    final role = profile?.role ?? session.role;
                    if (name.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${role.label} • $contact',
                          style: const TextStyle(color: Color(0xFFD0D5DD)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Workspace'.tr,
                style: TextStyle(
                  color: drawerSectionText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _NavTile(
              label: 'Dashboard'.tr,
              route: AppRoutes.dashboard,
              icon: Icons.dashboard_outlined,
              currentRoute: currentRoute,
            ),
            if (!isRestrictedUser)
              _NavTile(
                label: 'Users'.tr,
                route: AppRoutes.users,
                icon: Icons.manage_accounts_outlined,
                currentRoute: currentRoute,
              ),
            _NavTile(
              label: 'Customers'.tr,
              route: AppRoutes.customers,
              icon: Icons.people_outline,
              currentRoute: currentRoute,
            ),
            if (!isRestrictedUser)
              _NavTile(
                label: 'Products'.tr,
                route: AppRoutes.products,
                icon: Icons.inventory_2_outlined,
                currentRoute: currentRoute,
              ),
            if (!isRestrictedUser)
              _NavTile(
                label: 'Installments'.tr,
                route: AppRoutes.installments,
                icon: Icons.event_note_outlined,
                currentRoute: currentRoute,
              ),
            _NavTile(
              label: 'Daily Collection'.tr,
              route: AppRoutes.dailyInstallments,
              icon: Icons.today_outlined,
              currentRoute: currentRoute,
            ),
            if (!isRestrictedUser)
              _NavTile(
                label: 'Payments'.tr,
                route: AppRoutes.payments,
                icon: Icons.payments_outlined,
                currentRoute: currentRoute,
              ),
            if (!isRestrictedUser)
              _NavTile(
                label: 'Reports'.tr,
                route: AppRoutes.reports,
                icon: Icons.picture_as_pdf_outlined,
                currentRoute: currentRoute,
              ),
            if (!isRestrictedUser)
              _NavTile(
                label: 'Settings'.tr,
                route: AppRoutes.settings,
                icon: Icons.settings_outlined,
                currentRoute: currentRoute,
              ),
            if (!isRestrictedUser) const SizedBox(height: 12),
            if (!isRestrictedUser)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: drawerPanelColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: drawerPanelBorder),
                ),
                child: Text(
                  'Keep the app open at midnight to auto-generate the daily due report in offline mode.'
                      .tr,
                  style: TextStyle(color: drawerMutedText, height: 1.4),
                ),
              ),
            const SizedBox(height: 12),
            Obx(
              () => ListTile(
                onTap: authController.isLogoutLoading.value
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await AppLoadingOverlay.runFromGet(
                          message: 'Signing out...',
                          task: authController.logout,
                        );
                      },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: authController.isLogoutLoading.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded, color: AppColors.danger),
                title: Text(
                  authController.isLogoutLoading.value
                      ? 'Logging out...'.tr
                      : 'Logout'.tr,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: body),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.route,
    required this.icon,
    required this.currentRoute,
  });

  final String label;
  final String route;
  final IconData icon;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = currentRoute == route;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? (isDark
                  ? const Color(0x1AFFFFFF)
                  : AppColors.brandPrimary.withValues(alpha: 0.10))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected
              ? (isDark ? Colors.white : AppColors.brandPrimary)
              : (isDark ? const Color(0xFF98A2B3) : AppColors.inkMuted),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (isDark ? Colors.white : AppColors.inkStrong)
                : (isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft),
          ),
        ),
        selected: selected,
        onTap: () {
          Navigator.of(context).pop();
          if (!selected) {
            Get.offNamed(route);
          }
        },
      ),
    );
  }
}
