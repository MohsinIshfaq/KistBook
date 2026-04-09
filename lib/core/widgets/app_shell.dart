import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final drawerBackground = isDark ? AppColors.brandSecondary : AppColors.surface;
    final drawerPanelColor = isDark ? const Color(0xFF111827) : AppColors.surfaceMuted;
    final drawerPanelBorder = isDark ? const Color(0xFF1F2937) : AppColors.border;
    final drawerMutedText = isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft;
    final drawerSectionText = isDark ? const Color(0xFF98A2B3) : AppColors.inkMuted;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Manage customers, installments, and reports',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.92),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: Get.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              Get.changeThemeMode(Get.isDarkMode ? ThemeMode.light : ThemeMode.dark);
            },
            icon: Icon(
              Get.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(0x1FFFFFFF),
                    child: Icon(Icons.auto_graph_rounded, color: Colors.white),
                  ),
                  SizedBox(height: 18),
                  Text(
                    AppStrings.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Installment operations for modern micro business teams',
                    style: TextStyle(
                      color: Color(0xFFD0D5DD),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Workspace',
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
              label: 'Dashboard',
              route: AppRoutes.dashboard,
              icon: Icons.dashboard_outlined,
              currentRoute: currentRoute,
            ),
            _NavTile(
              label: 'Customers',
              route: AppRoutes.customers,
              icon: Icons.people_outline,
              currentRoute: currentRoute,
            ),
            _NavTile(
              label: 'Products',
              route: AppRoutes.products,
              icon: Icons.inventory_2_outlined,
              currentRoute: currentRoute,
            ),
            _NavTile(
              label: 'Installments',
              route: AppRoutes.installments,
              icon: Icons.event_note_outlined,
              currentRoute: currentRoute,
            ),
            _NavTile(
              label: 'Payments',
              route: AppRoutes.payments,
              icon: Icons.payments_outlined,
              currentRoute: currentRoute,
            ),
            _NavTile(
              label: 'Reports',
              route: AppRoutes.reports,
              icon: Icons.picture_as_pdf_outlined,
              currentRoute: currentRoute,
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: drawerPanelColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: drawerPanelBorder),
              ),
              child: Text(
                'Keep the app open at midnight to auto-generate the daily due report in offline mode.',
                style: TextStyle(color: drawerMutedText, height: 1.4),
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
