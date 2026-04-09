import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_strings.dart';

enum BannerStyle { success, warning, error }

void showBannerAlert({
  BannerStyle type = BannerStyle.success,
  String? title,
  required List<String> messages,
  int duration = 3,
  VoidCallback? onTap,
  bool useBulletPoints = true,
  Color? backgroundColor,
  bool messageSemibold = false,
}) {
  if (messages.isEmpty) {
    return;
  }

  if (Get.isSnackbarOpen) {
    Get.closeCurrentSnackbar();
  }

  final context = Get.context;
  final theme = context == null ? ThemeData.fallback() : Theme.of(context);
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  final alertTitle = title ?? AppStrings.appName;
  final accentColor = backgroundColor ??
      switch (type) {
        BannerStyle.success => AppColors.success,
        BannerStyle.warning => AppColors.warning,
        BannerStyle.error => scheme.error,
      };
  final panelColor = isDark
      ? Color.alphaBlend(accentColor.withValues(alpha: 0.18), scheme.surface)
      : Color.alphaBlend(accentColor.withValues(alpha: 0.10), scheme.surface);
  final borderColor = accentColor.withValues(alpha: isDark ? 0.34 : 0.18);
  final titleColor = scheme.onSurface;
  final bodyColor = isDark ? Colors.white.withValues(alpha: 0.90) : AppColors.inkSoft;
  final iconPanelColor = accentColor.withValues(alpha: isDark ? 0.18 : 0.12);
  final indicatorColor = accentColor.withValues(alpha: isDark ? 0.92 : 1);

  Get.snackbar(
    '',
    '',
    snackPosition: SnackPosition.TOP,
    margin: const EdgeInsets.all(16),
    padding: EdgeInsets.zero,
    borderRadius: 22,
    backgroundColor: panelColor,
    colorText: bodyColor,
    borderColor: borderColor,
    borderWidth: 1,
    boxShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
        blurRadius: 28,
        offset: const Offset(0, 14),
      ),
    ],
    duration: Duration(seconds: duration),
    onTap: onTap == null ? null : (_) => onTap(),
    titleText: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconPanelColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              switch (type) {
                BannerStyle.success => Icons.check_circle_outline_rounded,
                BannerStyle.warning => Icons.warning_amber_rounded,
                BannerStyle.error => Icons.error_outline_rounded,
              },
              color: indicatorColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alertTitle,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  messages.length == 1
                      ? 'Please review the detail below.'
                      : 'Please review the following ${messages.length} items.',
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    messageText: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages
            .map(
              (message) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (useBulletPoints) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 8),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight:
                              messageSemibold ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}
