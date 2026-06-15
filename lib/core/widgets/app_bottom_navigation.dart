import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/constants/app_enums.dart';
import '../../services/session_manager.dart';

const double _bottomNavigationContentHeight = 82;

class AppNavigationFrame extends StatelessWidget {
  const AppNavigationFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppNavigationController>();
    final session = Get.find<SessionManager>();

    return Obx(() {
      final currentRoute = controller.currentRoute.value;
      final showNavigation = _shouldShowBottomNavigation(
        session: session,
        currentRoute: currentRoute,
      );
      final bottomNavigationHeight = showNavigation
          ? AppBottomNavigation.reservedHeight(context)
          : 0.0;
      final routeContent = showNavigation
          ? MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: child,
            )
          : child;
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            Positioned.fill(
              bottom: bottomNavigationHeight,
              child: routeContent,
            ),
            if (showNavigation)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNavigation(
                  currentRoute: currentRoute,
                  isRestrictedUser: session.role != UserRole.owner,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class AppNavigationController extends GetxController {
  final RxString currentRoute = AppRoutes.dashboard.obs;

  void setCurrentRoute(String? route) {
    if (route == null || route.isEmpty) {
      return;
    }
    if (currentRoute.value == route) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || currentRoute.value == route) {
        return;
      }
      currentRoute.value = route;
    });
  }
}

class AppNavDestination {
  const AppNavDestination({
    required this.drawerLabel,
    required this.bottomLabel,
    required this.route,
    required this.drawerIcon,
    required this.bottomIcon,
  });

  final String drawerLabel;
  final String bottomLabel;
  final String route;
  final IconData drawerIcon;
  final IconData bottomIcon;
}

List<AppNavDestination> appDrawerDestinations(bool isRestrictedUser) {
  return [
    const AppNavDestination(
      drawerLabel: 'Dashboard',
      bottomLabel: 'Dashboard',
      route: AppRoutes.dashboard,
      drawerIcon: Icons.dashboard_outlined,
      bottomIcon: Icons.insert_chart_rounded,
    ),
    if (!isRestrictedUser)
      const AppNavDestination(
        drawerLabel: 'Users',
        bottomLabel: 'Users',
        route: AppRoutes.users,
        drawerIcon: Icons.manage_accounts_outlined,
        bottomIcon: Icons.manage_accounts_rounded,
      ),
    const AppNavDestination(
      drawerLabel: 'Customers',
      bottomLabel: 'Customer',
      route: AppRoutes.customers,
      drawerIcon: Icons.people_outline,
      bottomIcon: Icons.groups_2_rounded,
    ),
    if (!isRestrictedUser)
      const AppNavDestination(
        drawerLabel: 'Products',
        bottomLabel: 'Product',
        route: AppRoutes.products,
        drawerIcon: Icons.inventory_2_outlined,
        bottomIcon: Icons.inventory_2_rounded,
      ),
    if (!isRestrictedUser)
      const AppNavDestination(
        drawerLabel: 'Installments',
        bottomLabel: 'Installment Plan',
        route: AppRoutes.installments,
        drawerIcon: Icons.event_note_outlined,
        bottomIcon: Icons.event_available_rounded,
      ),
    const AppNavDestination(
      drawerLabel: 'Daily Collection',
      bottomLabel: 'Daily Collection',
      route: AppRoutes.dailyInstallments,
      drawerIcon: Icons.today_outlined,
      bottomIcon: Icons.event_available_rounded,
    ),
    if (!isRestrictedUser && kDebugMode)
      const AppNavDestination(
        drawerLabel: 'Payments',
        bottomLabel: 'Payments',
        route: AppRoutes.payments,
        drawerIcon: Icons.payments_outlined,
        bottomIcon: Icons.payments_rounded,
      ),
    if (!isRestrictedUser && kDebugMode)
      const AppNavDestination(
        drawerLabel: 'Reports',
        bottomLabel: 'Reports',
        route: AppRoutes.reports,
        drawerIcon: Icons.picture_as_pdf_outlined,
        bottomIcon: Icons.picture_as_pdf_rounded,
      ),
    if (!isRestrictedUser)
      const AppNavDestination(
        drawerLabel: 'Settings',
        bottomLabel: 'Settings',
        route: AppRoutes.settings,
        drawerIcon: Icons.settings_outlined,
        bottomIcon: Icons.settings_rounded,
      ),
  ];
}

List<AppNavDestination> appBottomDestinations(bool isRestrictedUser) {
  final destinations = appDrawerDestinations(isRestrictedUser);
  if (isRestrictedUser) {
    return destinations.where((destination) {
      return destination.route == AppRoutes.dashboard ||
          destination.route == AppRoutes.customers ||
          destination.route == AppRoutes.dailyInstallments;
    }).toList();
  }

  return destinations.where((destination) {
    return destination.route == AppRoutes.dashboard ||
        destination.route == AppRoutes.customers ||
        destination.route == AppRoutes.products ||
        destination.route == AppRoutes.installments ||
        destination.route == AppRoutes.settings;
  }).toList();
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentRoute,
    required this.isRestrictedUser,
  });

  final String currentRoute;
  final bool isRestrictedUser;

  static double reservedHeight(BuildContext context) {
    return _bottomNavigationContentHeight +
        MediaQuery.viewPaddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final destinations = appBottomDestinations(isRestrictedUser);
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeRoute = _activeBottomRoute(currentRoute, isRestrictedUser);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = math.min(screenWidth, 760.0);
    final horizontalPadding = screenWidth >= 720 ? 32.0 : 14.0;

    final backgroundColor = theme.cardColor.withValues(
      alpha: isDark ? 0.92 : 0.96,
    );
    final borderColor = theme.dividerColor.withValues(
      alpha: isDark ? 0.72 : 0.92,
    );
    final shadowColor = theme.shadowColor.withValues(
      alpha: isDark ? 0.36 : 0.12,
    );

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(top: BorderSide(color: borderColor)),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 28,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              minimum: EdgeInsets.zero,
              child: SizedBox(
                height: _bottomNavigationContentHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Row(
                        children: [
                          for (final destination in destinations)
                            Expanded(
                              child: _BottomNavItem(
                                destination: destination,
                                selected: activeRoute == destination.route,
                                currentRoute: currentRoute,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.currentRoute,
  });

  final AppNavDestination destination;
  final bool selected;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor =
        theme.textTheme.bodyMedium?.color?.withValues(
          alpha: isDark ? 0.92 : 1,
        ) ??
        theme.colorScheme.onSurfaceVariant;
    final activeSurface = activeColor.withValues(alpha: isDark ? 0.16 : 0.10);
    final label = destination.bottomLabel.tr;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(selected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 68,
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 6),
            decoration: BoxDecoration(
              color: selected ? activeSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  scale: selected ? 1.06 : 1,
                  child: Icon(
                    destination.bottomIcon,
                    color: selected ? activeColor : inactiveColor,
                    size: selected ? 25 : 24,
                  ),
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? activeColor : inactiveColor,
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent,
                      fontSize: 10.8,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: selected ? 22 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: selected ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(bool selected) {
    if (selected && currentRoute == destination.route) {
      return;
    }
    Get.offNamed(destination.route);
  }
}

bool _shouldShowBottomNavigation({
  required SessionManager session,
  required String currentRoute,
}) {
  if (!session.isLoggedIn) {
    return false;
  }
  return appBottomDestinations(
    session.role != UserRole.owner,
  ).any((destination) => destination.route == currentRoute);
}

String? _activeBottomRoute(String currentRoute, bool isRestrictedUser) {
  if (currentRoute == AppRoutes.dashboard) {
    return AppRoutes.dashboard;
  }
  if (currentRoute.startsWith('/customers')) {
    return AppRoutes.customers;
  }
  if (currentRoute.startsWith('/products')) {
    return isRestrictedUser ? null : AppRoutes.products;
  }
  if (currentRoute == AppRoutes.dailyInstallments) {
    return isRestrictedUser
        ? AppRoutes.dailyInstallments
        : AppRoutes.installments;
  }
  if (currentRoute.startsWith('/installments')) {
    return isRestrictedUser
        ? AppRoutes.dailyInstallments
        : AppRoutes.installments;
  }
  if (currentRoute.startsWith('/settings')) {
    return isRestrictedUser ? null : AppRoutes.settings;
  }
  return null;
}
