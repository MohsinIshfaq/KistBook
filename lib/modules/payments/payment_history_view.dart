import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_shell.dart';
import 'payment_controller.dart';

class PaymentHistoryView extends GetView<PaymentController> {
  const PaymentHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppShell(
      title: 'Payments'.tr,
      currentRoute: AppRoutes.payments,
      body: GetBuilder<PaymentController>(
        builder: (logic) {
          if (logic.isLoading && logic.payments.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF122033), Color(0xFF0F172A)]
                          : const [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.surface,
                        child: const Icon(Icons.info_outline, color: AppColors.brandPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tracking Only'.tr,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.inkStrong,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.paymentsTrackingOnly.tr,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.78)
                                    : AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (logic.dueInstallments.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending Collection'.tr,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...logic.dueInstallments.take(5).map(
                              (detail) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            detail.customer.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(detail.product?.name ?? detail.plan.itemName),
                                        ],
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () => Get.toNamed(
                                        AppRoutes.paymentForm,
                                        arguments: detail,
                                      ),
                                      child: Text('Record'.tr),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ...logic.payments.map(
                (payment) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.south_west, color: AppColors.success),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                CurrencyHelper.pkr.format(payment.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(payment.note.isEmpty ? 'Manual entry'.tr : payment.note),
                            ],
                          ),
                        ),
                        Text(payment.paidOn.toLocal().toString().split(' ').first),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
