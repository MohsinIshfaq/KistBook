import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/bindings/installment_binding.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/installment_repository.dart';
import '../installments/installment_controller.dart';
import '../installments/installment_plan_edit_view.dart';
import '../installments/installment_plan_generator.dart';
import 'customer_controller.dart';

class CustomerDetailView extends StatefulWidget {
  const CustomerDetailView({super.key});

  @override
  State<CustomerDetailView> createState() => _CustomerDetailViewState();
}

class _CustomerDetailViewState extends State<CustomerDetailView> {
  final controller = Get.find<CustomerController>();
  final dateFormat = DateFormat('dd MMM yyyy');
  final installmentRepository = Get.find<InstallmentRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      controller.loadProfile(Get.arguments as int);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Customer Detail'.tr)),
      body: GetBuilder<CustomerController>(
        builder: (logic) {
          if (logic.isLoading || logic.profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = logic.profile!;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _summaryCard(
                context,
                title: profile.customer.name,
                subtitle: 'Customer profile and installment activity'.tr,
                leadingIcon: Icons.person_outline_rounded,
                accentColor: AppColors.brandPrimary,
                children: [
                  _detailRow(
                    context,
                    icon: Icons.call_outlined,
                    label: 'Phone'.tr,
                    value: profile.customer.phone.isEmpty
                        ? 'Not provided'.tr
                        : profile.customer.phone,
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.badge_outlined,
                    label: 'CNIC'.tr,
                    value: profile.customer.cnic.isEmpty
                        ? 'Not provided'.tr
                        : profile.customer.cnic,
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.groups_outlined,
                    label: 'Reference'.tr,
                    value: profile.customer.reference.isEmpty
                        ? 'Not provided'.tr
                        : profile.customer.reference,
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.location_on_outlined,
                    label: 'Address'.tr,
                    value: profile.customer.address,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _openPlanFlow(profile),
                    icon: Icon(
                      profile.plans.isEmpty ? Icons.add_card_rounded : Icons.edit_note_rounded,
                    ),
                    label: Text(
                      (profile.plans.isEmpty ? 'Add Installment Plan' : 'Manage Plans').tr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'History'.tr,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...profile.history.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Text('${item.subtitle}\n${dateFormat.format(item.date)}'),
                    isThreeLine: true,
                    trailing: Text(CurrencyHelper.pkr.format(item.amount)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPlanFlow(CustomerProfile profile) async {
    if (!Get.isRegistered<InstallmentController>()) {
      InstallmentBinding().dependencies();
    }

    if (profile.plans.isEmpty) {
      await Get.to(
        () => const InstallmentPlanGenerator(),
        arguments: {'customerId': profile.customer.id},
      );
    } else {
      final latestPlan = profile.plans.first;
      final planId = latestPlan.id;
      if (planId == null) {
        return;
      }
      final summary = await installmentRepository.fetchPlanSummary(planId);
      if (summary == null) {
        return;
      }
      await Get.to(
        () => const InstallmentPlanEditView(),
        arguments: summary,
      );
    }

    if (!mounted) {
      return;
    }
    await controller.loadProfile(Get.arguments as int);
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData leadingIcon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? accentColor.withValues(alpha: 0.18)
                        : accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(leadingIcon, color: accentColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}
