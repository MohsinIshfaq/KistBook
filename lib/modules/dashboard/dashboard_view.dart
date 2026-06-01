import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../services/session_manager.dart';
import '../auth/auth_controller.dart';
import 'dashboard_controller.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    final authController = Get.find<AuthController>();
    final isOwner = session.role == UserRole.owner;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppShell(
      title: 'Dashboard'.tr,
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
            return Center(child: Text('No dashboard data available.'.tr));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Obx(() => _profileSummary(context, session, authController)),
              const SizedBox(height: 16),
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
                              Text(
                                (isOwner
                                        ? 'Business Overview'
                                        : 'Assigned Collection Overview')
                                    .tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                (isOwner
                                        ? 'Monitor collections, pending dues, and customer activity in one place.'
                                        : 'Monitor only the customers and plans assigned to your account.')
                                    .tr,
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
                        _heroChip(
                          'Outstanding'.tr,
                          snapshot.totalOutstandingLabel,
                        ),
                        _heroChip('Collected'.tr, snapshot.totalCollectedLabel),
                        _heroChip(
                          'Pending Today'.tr,
                          '@count items'.trParams({
                            'count': '${snapshot.dueToday.length}',
                          }),
                        ),
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
                    label: 'Customers'.tr,
                    value: '${snapshot.customers.length}',
                    accent: AppColors.info,
                    caption: 'Registered profiles'.tr,
                  ),
                  MetricCard(
                    label: 'Pending Today'.tr,
                    value: '${snapshot.dueToday.length}',
                    accent: AppColors.warning,
                    caption: 'Installments due today'.tr,
                  ),
                  MetricCard(
                    label: 'Overdue'.tr,
                    value: '${snapshot.overdue.length}',
                    accent: AppColors.danger,
                    caption: 'Missed or delayed entries'.tr,
                  ),
                  MetricCard(
                    label: 'Collected'.tr,
                    value: snapshot.totalCollectedLabel,
                    accent: AppColors.success,
                    caption:
                        (isOwner
                                ? 'Tracked receipts only'
                                : 'Your tracked receipts')
                            .tr,
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
                          Expanded(
                            child: Text(
                              'Today Alerts'.tr,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.surfaceTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '@count active'.trParams({
                                'count': '${snapshot.dueToday.length}',
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.dueToday.isEmpty)
                        Text('No installments due today.'.tr)
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
                                    color: AppColors.warning.withValues(
                                      alpha: 0.15,
                                    ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detail.customer.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        detail.product?.name ??
                                            detail.plan.itemName,
                                      ),
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
                                  icon: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                  ),
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
                          Expanded(
                            child: Text(
                              'Daily PDF Report'.tr,
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
                                  title: 'Report Generated'.tr,
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

  Widget _profileSummary(
    BuildContext context,
    SessionManager session,
    AuthController authController,
  ) {
    final profile = authController.currentUser.value;
    final name = profile?.fullName ?? session.fullName;
    final contact = [
      profile?.phone ?? session.phone,
      profile?.email ?? session.email,
    ].where((value) => value.isNotEmpty).join(' • ');
    final role = profile?.role ?? session.role;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (authController.isProfileLoading.value)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Signed-in user'.tr : name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (contact.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(contact),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    role.label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
