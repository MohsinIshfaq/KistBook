import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/purchase_plan_model.dart';
import '../../data/repositories/customer_repository.dart';

class CustomerPaymentInsightView extends StatelessWidget {
  const CustomerPaymentInsightView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? const {};
    final customer = args['customer'] as CustomerModel?;
    final insight = args['insight'] as CustomerPaymentInsight?;

    if (customer == null) {
      return const Scaffold(
        body: Center(child: Text('Customer not found')),
      );
    }

    final repository = Get.find<CustomerRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Payment Detail'),
      ),
      body: FutureBuilder<CustomerProfile?>(
        future: repository.fetchCustomerProfile(customer.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                insight?.currentPlanStatus ?? 'No previous plan',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chip(
                          context,
                          label: insight == null || !insight.hasHistory
                              ? 'New customer'
                              : '${insight.onTimePercentageLabel} on-time',
                          color: _ratingColor(insight),
                        ),
                        _chip(
                          context,
                          label: 'Rating ${insight?.ratingLabel ?? 'New'}',
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _metric(context, 'Running plans', '${insight?.activePlans ?? 0}'),
                        const SizedBox(width: 10),
                        _metric(context, 'Completed', '${insight?.completedPlans ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _metric(context, 'Late installments', '${insight?.lateInstallments ?? 0}'),
                        const SizedBox(width: 10),
                        _metric(context, 'Paid on time', '${insight?.onTimeInstallments ?? 0}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Customer Detail',
                child: Column(
                  children: [
                    _detailRow(context, 'Phone', customer.phone.isEmpty ? 'Not provided' : customer.phone),
                    _detailRow(context, 'CNIC', customer.cnic.isEmpty ? 'Not provided' : customer.cnic),
                    _detailRow(context, 'Reference', customer.reference.isEmpty ? 'Not provided' : customer.reference),
                    _detailRow(context, 'Address', customer.address),
                    _detailRow(
                      context,
                      'Last payment',
                      insight?.lastPaymentDate == null
                          ? 'No payment yet'
                          : '${insight!.lastPaymentDate!.day}-${insight.lastPaymentDate!.month}-${insight.lastPaymentDate!.year}',
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Plan Summary',
                child: Column(
                  children: [
                    _detailRow(context, 'Total plans', '${profile?.plans.length ?? 0}'),
                    _detailRow(
                      context,
                      'Total payments',
                      '${profile?.payments.length ?? 0}',
                    ),
                    _detailRow(
                      context,
                      'Collected amount',
                      CurrencyHelper.pkr.format(
                        profile?.payments.fold<double>(0, (sum, item) => sum + item.amount) ?? 0,
                      ),
                    ),
                    _detailRow(
                      context,
                      'Outstanding amount',
                      CurrencyHelper.pkr.format(
                        profile?.installments.fold<double>(
                              0,
                              (sum, item) => sum + item.remainingAmount.clamp(0, double.infinity),
                            ) ??
                            0,
                      ),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              if ((profile?.plans.isNotEmpty ?? false)) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Recent Plans',
                  child: Column(
                    children: [
                      for (var index = 0; index < profile!.plans.length && index < 3; index++)
                        _planTile(
                          context,
                          profile.plans[index],
                          isDark: isDark,
                          isLast: index == (profile.plans.length.clamp(0, 3) - 1),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _chip(BuildContext context, {required String label, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value, {bool isLast = false}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.brightness == Brightness.dark ? Colors.white12 : AppColors.border,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planTile(
    BuildContext context,
    PurchasePlanModel plan, {
    required bool isDark,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : AppColors.border,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.itemName,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Installment ${CurrencyHelper.pkr.format(plan.installmentAmount)} • Every ${plan.frequencyDays} days',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyHelper.pkr.format(plan.totalAmount),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Color _ratingColor(CustomerPaymentInsight? insight) {
    if (insight == null || !insight.hasHistory || insight.maturedInstallments == 0) {
      return AppColors.info;
    }
    if (insight.onTimePercentage >= 90) {
      return AppColors.success;
    }
    if (insight.onTimePercentage >= 75) {
      return AppColors.brandAccent;
    }
    if (insight.onTimePercentage >= 50) {
      return AppColors.warning;
    }
    return AppColors.danger;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.title,
    required this.child,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
