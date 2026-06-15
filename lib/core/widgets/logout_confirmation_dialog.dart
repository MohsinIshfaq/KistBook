import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../modules/auth/auth_controller.dart';
import 'app_loading_overlay.dart';

Future<void> showLogoutConfirmationDialog(BuildContext context) async {
  final authController = Get.find<AuthController>();
  if (authController.isLogoutLoading.value) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final danger = theme.colorScheme.error;
      final mutedText = theme.textTheme.bodyMedium?.color;

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: danger.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout_rounded, color: danger, size: 34),
                ),
                const SizedBox(height: 22),
                Text(
                  'Log out'.tr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to log out of your account?'.tr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: mutedText,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 26),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceContainer,
                          foregroundColor: theme.colorScheme.onSurface,
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text('Cancel'.tr),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: danger,
                          foregroundColor: theme.colorScheme.onError,
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text('Log out'.tr),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (confirmed != true) {
    return;
  }

  await AppLoadingOverlay.runFromGet(
    message: 'Signing out...'.tr,
    task: authController.logout,
  );
}
