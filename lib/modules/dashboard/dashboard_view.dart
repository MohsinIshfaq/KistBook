import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/status_badge.dart';
import 'dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppShell(
      title: 'Dashboard',
      currentRoute: AppRoutes.dashboard,
      actions: [
        IconButton(
          onPressed: controller.loadDashboard,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: GetBuilder<DashboardController>(
        builder: (logic) {
          if (logic.isLoading && logic.snapshot == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final snapshot = logic.snapshot;
          if (snapshot == null) {
            return const Center(child: Text('No dashboard data available.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF1E3A8A), Color(0xFF0F172A)]
                        : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Business Overview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Monitor collections, pending dues, and customer activity in one place.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _heroChip('Outstanding', snapshot.totalOutstandingLabel),
                        _heroChip('Collected', snapshot.totalCollectedLabel),
                        _heroChip('Pending Today', '${snapshot.dueToday.length} items'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  MetricCard(
                    label: 'Customers',
                    value: '${snapshot.customers.length}',
                    accent: AppColors.info,
                    caption: 'Registered profiles',
                  ),
                  MetricCard(
                    label: 'Due Today',
                    value: '${snapshot.dueToday.length}',
                    accent: AppColors.warning,
                    caption: 'Installments due today',
                  ),
                  MetricCard(
                    label: 'Overdue',
                    value: '${snapshot.overdue.length}',
                    accent: AppColors.danger,
                    caption: 'Missed or delayed entries',
                  ),
                  MetricCard(
                    label: 'Collected',
                    value: snapshot.totalCollectedLabel,
                    accent: AppColors.success,
                    caption: 'Tracked receipts only',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Today Alerts',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.surfaceTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('${snapshot.dueToday.length} active'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.dueToday.isEmpty)
                        const Text('No installments due today.')
                      else
                        ...snapshot.dueToday.map(
                          (detail) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.schedule_outlined,
                                    color: AppColors.warning,
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
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(detail.product?.name ?? detail.plan.itemName),
                                    ],
                                  ),
                                ),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    StatusBadge(
                                      status: InstallmentVisualStatus.pending,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => Get.toNamed(
                                    AppRoutes.paymentForm,
                                    arguments: detail,
                                  ),
                                  icon: const Icon(Icons.arrow_forward_ios_rounded),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Daily PDF Report',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () async {
                              await logic.generateTodayReport();
                              if (logic.reportPath != null) {
                                showBannerAlert(
                                  title: 'Report Generated',
                                  messages: [logic.reportPath!],
                                );
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Generate'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        logic.reportPath == null
                            ? 'A PDF of today\'s due installments can be generated from here.'
                            : 'Latest file: ${logic.reportPath}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
