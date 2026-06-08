import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_enums.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final InstallmentVisualStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      InstallmentVisualStatus.paid => AppColors.success,
      InstallmentVisualStatus.partial => const Color(0xFFF97316),
      InstallmentVisualStatus.overdue => AppColors.danger,
      InstallmentVisualStatus.rescheduled => AppColors.brandPrimary,
      InstallmentVisualStatus.pending => const Color(0xFFEAB308),
    };
    final text =
        label ??
        switch (status) {
          InstallmentVisualStatus.paid => 'Collected'.tr,
          InstallmentVisualStatus.partial => 'Partial'.tr,
          InstallmentVisualStatus.overdue => 'Overdue'.tr,
          InstallmentVisualStatus.rescheduled => 'Rescheduled'.tr,
          InstallmentVisualStatus.pending => 'Pending'.tr,
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
