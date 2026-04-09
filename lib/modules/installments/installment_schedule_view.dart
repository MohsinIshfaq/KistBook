import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/status_badge.dart';
import 'installment_plan_generator.dart';
import 'installment_controller.dart';

class InstallmentScheduleView extends GetView<InstallmentController> {
  const InstallmentScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? AppColors.brandSecondary : AppColors.surface;
    final primaryText = isDark ? Colors.white : AppColors.inkStrong;
    final secondaryText = isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft;
    final mutedText = isDark ? const Color(0xFF98A2B3) : AppColors.inkMuted;
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.border;

    return AppShell(
      title: 'Installments',
      currentRoute: AppRoutes.installments,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const InstallmentPlanGenerator()),
        icon: const Icon(Icons.add_chart_outlined),
        label: const Text('New Plan'),
      ),
      body: GetBuilder<InstallmentController>(
        builder: (logic) {
          if (logic.isLoading && logic.installments.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: logic.installments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final detail = logic.installments[index];
              final status = detail.installment.visualStatus(DateTime.now());
              return Card(
                color: cardBackground,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: switch (status) {
                                  InstallmentVisualStatus.paid => AppColors.success,
                                  InstallmentVisualStatus.overdue => AppColors.danger,
                                  InstallmentVisualStatus.pending => AppColors.warning,
                                },
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detail.customer.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    detail.product?.name ?? detail.plan.itemName,
                                    style: const TextStyle(
                                      color: AppColors.brandAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusBadge(status: status),
                                const SizedBox(height: 8),
                                Text(
                                  CurrencyHelper.pkr.format(
                                    detail.installment.remainingAmount,
                                  ),
                                  style: TextStyle(
                                    color: primaryText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: dividerColor, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Due: ${detail.installment.currentDueDate.toLocal().toString().split(' ').first}',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'Installment #${detail.installment.sequenceNumber}',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (detail.installment.wasMissed) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Missed installment carried forward without changing the remaining schedule.',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFFCA5A5) : AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
