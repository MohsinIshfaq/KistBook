import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/localization/app_translations.dart';
import '../../app/routes/app_routes.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/logout_confirmation_dialog.dart';
import '../../services/session_manager.dart';
import '../auth/auth_controller.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    final authController = Get.find<AuthController>();
    final theme = Theme.of(context);

    return AppShell(
      title: 'Settings'.tr,
      currentRoute: AppRoutes.settings,
      centerTitle: true,
      showSubtitle: false,
      showSettingsAction: false,
      actions: [
        Obx(() {
          final isLoading = authController.isLogoutLoading.value;
          return TextButton.icon(
            onPressed: isLoading
                ? null
                : () => showLogoutConfirmationDialog(context),
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.error,
                    ),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(isLoading ? 'Logging out...'.tr : 'Log out'.tr),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }),
      ],
      body: GetBuilder<SettingsController>(
        builder: (logic) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            children: [
              _AccessBadge(role: session.role),
              const SizedBox(height: 34),
              Text(
                'Preferences'.tr,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceCard(
                children: [
                  _PreferenceTile(
                    icon: Icons.language_rounded,
                    title: 'Language'.tr,
                    value: logic.languageLabel,
                    onTap: () => Get.to(
                      () => const _LanguageSettingsView(),
                      routeName: AppRoutes.settingsLanguage,
                    ),
                  ),
                  const _PreferenceDivider(),
                  _PreferenceTile(
                    icon: Icons.palette_rounded,
                    title: 'Appearance'.tr,
                    value: logic.themeLabel,
                    onTap: () => Get.to(
                      () => const _AppearanceSettingsView(),
                      routeName: AppRoutes.settingsAppearance,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LanguageSettingsView extends GetView<SettingsController> {
  const _LanguageSettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('Language'.tr)),
      body: GetBuilder<SettingsController>(
        builder: (logic) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            children: [
              _SelectionCard(
                children: [
                  _SelectionTile(
                    title: AppTranslations.english,
                    subtitle: 'English language'.tr,
                    selected: logic.locale.languageCode == 'en',
                    onTap: () => logic.updateLocale(const Locale('en', 'US')),
                  ),
                  const _PreferenceDivider(),
                  _SelectionTile(
                    title: AppTranslations.urdu,
                    subtitle: 'Urdu language'.tr,
                    selected: logic.locale.languageCode == 'ur',
                    onTap: () => logic.updateLocale(const Locale('ur', 'PK')),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppearanceSettingsView extends GetView<SettingsController> {
  const _AppearanceSettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('Appearance'.tr)),
      body: GetBuilder<SettingsController>(
        builder: (logic) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            children: [
              _SelectionCard(
                children: [
                  _SelectionTile(
                    title: 'System'.tr,
                    subtitle: 'Use device setting'.tr,
                    selected: logic.themeMode == ThemeMode.system,
                    onTap: () => logic.updateThemeMode(ThemeMode.system),
                  ),
                  const _PreferenceDivider(),
                  _SelectionTile(
                    title: 'Light'.tr,
                    subtitle: 'Always use the light theme'.tr,
                    selected: logic.themeMode == ThemeMode.light,
                    onTap: () => logic.updateThemeMode(ThemeMode.light),
                  ),
                  const _PreferenceDivider(),
                  _SelectionTile(
                    title: 'Dark'.tr,
                    subtitle: 'Always use the dark theme'.tr,
                    selected: logic.themeMode == ThemeMode.dark,
                    onTap: () => logic.updateThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final hasFullAccess = role == UserRole.owner;
    final accessText = hasFullAccess ? 'Full Access'.tr : 'Limited Access'.tr;
    final surfaceColor = primary.withValues(alpha: isDark ? 0.16 : 0.08);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.20 : 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.shield_rounded, color: primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              role.label.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                accessText,
                style: TextStyle(
                  color: primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _PreferenceCard(children: children);
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.textTheme.bodyMedium?.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              _TileIcon(icon: icon),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: secondaryTextColor?.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color;
    final borderColor = selected
        ? primary
        : (secondaryTextColor ?? theme.dividerColor).withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 3 : 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: primary, size: 22),
    );
  }
}

class _PreferenceDivider extends StatelessWidget {
  const _PreferenceDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 80, right: 20),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}
