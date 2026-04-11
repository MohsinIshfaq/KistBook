import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/dashboard_models.dart';
import 'installment_plan_detail_view.dart';
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
          final grouped = <int, List<DueInstallmentDetail>>{};
          for (final item in logic.installments) {
            grouped.putIfAbsent(item.plan.id ?? 0, () => []).add(item);
          }
          final summaries = grouped.values.map((items) {
            items.sort(
              (a, b) => a.installment.currentDueDate.compareTo(b.installment.currentDueDate),
            );
            final first = items.first;
            return InstallmentPlanSummary(
              customer: first.customer,
              plan: first.plan,
              product: first.product,
              installments: items.map((item) => item.installment).toList(),
            );
          }).toList()
            ..sort((a, b) {
              final firstDate = a.nextDueDate ?? DateTime(2100);
              final secondDate = b.nextDueDate ?? DateTime(2100);
              return firstDate.compareTo(secondDate);
            });

          if (summaries.isEmpty) {
            return const Center(child: Text('No installment plans available.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: summaries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final summary = summaries[index];
              final status = summary.status;
              return Card(
                color: cardBackground,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Get.to(
                    () => const InstallmentPlanDetailView(),
                    arguments: summary,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
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
                                    summary.customer.name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    summary.product?.name ?? summary.plan.itemName,
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
                                    summary.remainingAmount,
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
                                'Next due: ${summary.nextDueDate == null ? 'N/A' : summary.nextDueDate!.toLocal().toString().split(' ').first}',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${summary.remainingInstallments} remaining',
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _infoChip(
                              context,
                              label: 'Total',
                              value: CurrencyHelper.pkr.format(summary.plan.totalAmount),
                            ),
                            _infoChip(
                              context,
                              label: 'Collected',
                              value: CurrencyHelper.pkr.format(summary.collectedAmount),
                            ),
                            _infoChip(
                              context,
                              label: 'Installment',
                              value: CurrencyHelper.pkr.format(summary.plan.installmentAmount),
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
        },
      ),
    );
  }

  Widget _infoChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
