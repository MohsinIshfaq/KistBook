import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/bindings/installment_binding.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/installment_repository.dart';
import '../../services/session_manager.dart';
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
  CustomerHistoryFilter selectedFilter = CustomerHistoryFilter.all;
  int? selectedProductId;

  int get _customerId => Get.arguments as int;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadCustomerProfile();
    });
  }

  Future<void> _loadCustomerProfile() async {
    await controller.loadProfile(_customerId, refreshRemote: false);
    if (!mounted || controller.profile == null) {
      return;
    }
    await _refreshCustomerPlansWithOverlay();
  }

  Future<void> _refreshCustomerPlansWithOverlay() {
    return AppLoadingOverlay.run(
      context,
      message: 'Loading customer plan details...',
      task: () => controller.refreshProfilePlans(_customerId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    final canManagePlans = session.role == UserRole.owner;
    return Scaffold(
      appBar: AppBar(title: Text('Customer Detail'.tr)),
      body: GetBuilder<CustomerController>(
        builder: (logic) {
          if (logic.isLoading || logic.profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = logic.profile!;
          final theme = Theme.of(context);
          final productOptions = _productOptions(profile);
          final activeProductId =
              productOptions.any((item) => item.id == selectedProductId)
              ? selectedProductId
              : null;
          final filteredHistory = profile.history.where((item) {
            if (activeProductId != null &&
                !item.productIds.contains(activeProductId)) {
              return false;
            }
            switch (selectedFilter) {
              case CustomerHistoryFilter.all:
                return true;
              case CustomerHistoryFilter.paid:
                return item.status == CustomerHistoryStatus.paid;
              case CustomerHistoryFilter.pending:
                return item.status == CustomerHistoryStatus.pending;
            }
          }).toList();
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
                    icon: Icons.credit_card_outlined,
                    label: 'Card / Reference Number'.tr,
                    value: profile.customer.cardNumber.isEmpty
                        ? 'Not provided'.tr
                        : profile.customer.cardNumber,
                  ),
                  const SizedBox(height: 14),
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
                  if (canManagePlans)
                    FilledButton.icon(
                      onPressed: () => _openPlanFlow(profile),
                      icon: Icon(
                        profile.plans.isEmpty
                            ? Icons.add_card_rounded
                            : Icons.edit_note_rounded,
                      ),
                      label: Text(
                        (profile.plans.isEmpty
                                ? 'Add Installment Plan'
                                : 'Manage Plans')
                            .tr,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (logic.isRefreshingProfile) ...[
                _refreshInfoBanner(context),
                const SizedBox(height: 12),
              ],
              if (logic.profileRefreshError != null) ...[
                _refreshErrorBanner(context, logic.profileRefreshError!),
                const SizedBox(height: 12),
              ],
              Text(
                'Plans & History'.tr,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _filterToolbar(
                context,
                productOptions: productOptions,
                activeProductId: activeProductId,
              ),
              const SizedBox(height: 12),
              if (profile.plans.isEmpty)
                _emptyStateCard(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'No plans found for this customer.'.tr,
                )
              else if (filteredHistory.isEmpty)
                _emptyStateCard(
                  context,
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No plan history found for selected filters.'.tr,
                )
              else
                ...filteredHistory.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.subtitle}\n${dateFormat.format(item.date)}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyHelper.pkr.format(item.amount)),
                          const SizedBox(height: 6),
                          _historyStatusBadge(item.status),
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

  List<_ProductFilterOption> _productOptions(CustomerProfile profile) {
    final productsById = {
      for (final product in profile.products)
        if (product.id != null) product.id!: product,
    };
    final seen = <int>{};
    final options = <_ProductFilterOption>[];
    for (final plan in profile.plans) {
      for (final productId in plan.productIds) {
        if (!seen.add(productId)) {
          continue;
        }
        final product = productsById[productId];
        final label = product == null || product.name.trim().isEmpty
            ? (plan.itemName.trim().isEmpty
                  ? 'Product #$productId'
                  : plan.itemName)
            : product.name;
        options.add(_ProductFilterOption(id: productId, label: label));
      }
    }
    options.sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  Widget _filterToolbar(
    BuildContext context, {
    required List<_ProductFilterOption> productOptions,
    required int? activeProductId,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int?>(
            key: ValueKey(activeProductId ?? -1),
            initialValue: activeProductId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Product'.tr,
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('All Products'.tr),
              ),
              ...productOptions.map(
                (item) => DropdownMenuItem<int?>(
                  value: item.id,
                  child: Text(item.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => selectedProductId = value);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _filterChip(CustomerHistoryFilter.all, 'All'.tr),
              _filterChip(CustomerHistoryFilter.paid, 'Paid'.tr),
              _filterChip(CustomerHistoryFilter.pending, 'Pending'.tr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _refreshInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Refreshing plan details from server...'.tr,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _refreshErrorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _refreshCustomerPlansWithOverlay,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('Retry'.tr),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(CustomerHistoryFilter filter, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedFilter == filter,
      onSelected: (_) {
        setState(() => selectedFilter = filter);
      },
    );
  }

  Widget _historyStatusBadge(CustomerHistoryStatus status) {
    final isPaid = status == CustomerHistoryStatus.paid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isPaid ? AppColors.success : AppColors.warning).withValues(
          alpha: 0.14,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        (isPaid ? 'Paid' : 'Pending').tr,
        style: TextStyle(
          color: isPaid ? AppColors.success : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
      await Get.to(() => const InstallmentPlanEditView(), arguments: summary);
    }

    if (!mounted) {
      return;
    }
    await controller.loadProfile(_customerId, refreshRemote: false);
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
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.92,
                          ),
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

class _ProductFilterOption {
  const _ProductFilterOption({required this.id, required this.label});

  final int id;
  final String label;
}

enum CustomerHistoryFilter { all, paid, pending }
