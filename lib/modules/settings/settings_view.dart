import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/localization/app_translations.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/app_shell.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppShell(
      title: 'Settings'.tr,
      currentRoute: AppRoutes.settings,
      body: GetBuilder<SettingsController>(
        builder: (logic) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF1F3B63), Color(0xFF0F172A)]
                        : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white12 : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings'.tr,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Customize how KistBook looks and which language the app uses.'.tr,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _summaryChip(
                          context,
                          icon: Icons.palette_outlined,
                          label: 'Application theme'.tr,
                          value: logic.themeLabel,
                        ),
                        _summaryChip(
                          context,
                          icon: Icons.translate_rounded,
                          label: 'App language'.tr,
                          value: logic.languageLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionCard(
                context,
                title: 'Appearance'.tr,
                subtitle: 'Choose the theme that feels best for your team.'.tr,
                children: [
                  _optionTile(
                    context,
                    title: 'System'.tr,
                    subtitle: 'Use device setting'.tr,
                    icon: Icons.settings_suggest_outlined,
                    selected: logic.themeMode == ThemeMode.system,
                    onTap: () => logic.updateThemeMode(ThemeMode.system),
                  ),
                  _optionTile(
                    context,
                    title: 'Light'.tr,
                    subtitle: 'Always use the light theme'.tr,
                    icon: Icons.light_mode_rounded,
                    selected: logic.themeMode == ThemeMode.light,
                    onTap: () => logic.updateThemeMode(ThemeMode.light),
                  ),
                  _optionTile(
                    context,
                    title: 'Dark'.tr,
                    subtitle: 'Always use the dark theme'.tr,
                    icon: Icons.dark_mode_rounded,
                    selected: logic.themeMode == ThemeMode.dark,
                    onTap: () => logic.updateThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionCard(
                context,
                title: 'Language'.tr,
                subtitle: 'Pick the language for the full application experience.'.tr,
                children: [
                  _optionTile(
                    context,
                    title: AppTranslations.english,
                    subtitle: 'Current selection'.tr,
                    icon: Icons.language_outlined,
                    selected: logic.locale.languageCode == 'en',
                    onTap: () => logic.updateLocale(const Locale('en', 'US')),
                  ),
                  _optionTile(
                    context,
                    title: AppTranslations.urdu,
                    subtitle: 'Current selection'.tr,
                    icon: Icons.translate_rounded,
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

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.surfaceTint;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? theme.colorScheme.primary : theme.dividerColor,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: 2,
            ),
            color: selected ? theme.colorScheme.primary : Colors.transparent,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }

  Widget _summaryChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
