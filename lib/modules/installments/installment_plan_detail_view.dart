import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/product_model.dart';
import '../../data/models/purchase_plan_model.dart';
import '../../data/repositories/customer_repository.dart';
import 'installment_controller.dart';
import 'installment_plan_edit_view.dart';

class InstallmentPlanDetailView extends StatefulWidget {
  const InstallmentPlanDetailView({super.key});

  @override
  State<InstallmentPlanDetailView> createState() =>
      _InstallmentPlanDetailViewState();
}

class _InstallmentPlanDetailViewState extends State<InstallmentPlanDetailView> {
  late InstallmentPlanSummary summary;
  final controller = Get.find<InstallmentController>();
  final customerRepository = Get.find<CustomerRepository>();

  CustomerProfile? profile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    summary = Get.arguments as InstallmentPlanSummary;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final customerId = summary.customer.id;
    if (customerId == null) {
      setState(() => isLoading = false);
      return;
    }
    setState(() => isLoading = true);
    final loaded = await customerRepository.fetchCustomerProfile(customerId);
    if (!mounted) {
      return;
    }
    setState(() {
      profile = loaded;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final plans = profile?.plans ?? const <PurchasePlanModel>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Detail'),
        actions: [
          IconButton(
            tooltip: 'Edit plans',
            onPressed: _openEditView,
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
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
                                color: AppColors.brandPrimary.withValues(
                                  alpha: isDark ? 0.18 : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.brandPrimary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    summary.customer.name,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plans.isEmpty
                                        ? (summary.product?.name ??
                                              summary.plan.itemName)
                                        : '${plans.length} product plans linked',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.brandAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: summary.status),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Divider(color: theme.dividerColor),
                        const SizedBox(height: 18),
                        _detailRow(context, 'Phone', summary.customer.phone),
                        _detailRow(context, 'CNIC', summary.customer.cnic),
                        _detailRow(
                          context,
                          'Reference',
                          summary.customer.reference,
                        ),
                        _detailRow(
                          context,
                          'Address',
                          summary.customer.address,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Product Plans',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (plans.isEmpty)
                          Text(
                            'No plans found for this customer.',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          ...plans.map((plan) {
                            final product = _findProduct(plan);
                            final installments =
                                profile?.installments
                                    .where((item) => item.planId == plan.id)
                                    .toList() ??
                                const [];
                            final remainingAmount = installments.fold<double>(
                              0,
                              (sum, item) =>
                                  sum +
                                  item.remainingAmount.clamp(
                                    0,
                                    double.infinity,
                                  ),
                            );
                            final nextInstallment = installments.isEmpty
                                ? null
                                : installments.first;
                            final visualStatus = nextInstallment == null
                                ? InstallmentVisualStatus.paid
                                : nextInstallment.visualStatus(DateTime.now());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product == null
                                                  ? plan.itemName
                                                  : '${product.brandName} ${product.name}'
                                                        .trim(),
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              product == null
                                                  ? 'SKU: Not provided'
                                                  : product.sku.isEmpty
                                                  ? 'SKU: Not provided'
                                                  : 'SKU: ${product.sku}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      StatusBadge(status: visualStatus),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _metricChip(
                                        context,
                                        'Quantity',
                                        '${plan.quantity}',
                                      ),
                                      _metricChip(
                                        context,
                                        'Total',
                                        CurrencyHelper.pkr.format(
                                          plan.totalAmount,
                                        ),
                                      ),
                                      _metricChip(
                                        context,
                                        'Deposit',
                                        CurrencyHelper.pkr.format(
                                          plan.depositAmount,
                                        ),
                                      ),
                                      _metricChip(
                                        context,
                                        'Installment',
                                        CurrencyHelper.pkr.format(
                                          plan.installmentAmount,
                                        ),
                                      ),
                                      _metricChip(
                                        context,
                                        'Remaining',
                                        CurrencyHelper.pkr.format(
                                          remainingAmount,
                                        ),
                                      ),
                                      _metricChip(
                                        context,
                                        'Next due',
                                        nextInstallment == null
                                            ? 'N/A'
                                            : _dateLabel(
                                                nextInstallment.currentDueDate,
                                              ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _detailRow(
                                    context,
                                    'Frequency',
                                    '${plan.frequencyDays} days',
                                  ),
                                  _detailRow(
                                    context,
                                    'Start date',
                                    _dateLabel(plan.startDate),
                                  ),
                                  _detailRow(
                                    context,
                                    'Notes',
                                    plan.notes.isEmpty
                                        ? 'Not provided'
                                        : plan.notes,
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Current Plan Schedule',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...summary.installments.map((installment) {
                  final status = installment.visualStatus(DateTime.now());
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: switch (status) {
                            InstallmentVisualStatus.paid => AppColors.success,
                            InstallmentVisualStatus.partial => AppColors.info,
                            InstallmentVisualStatus.overdue => AppColors.danger,
                            InstallmentVisualStatus.rescheduled =>
                              AppColors.brandPrimary,
                            InstallmentVisualStatus.pending =>
                              AppColors.warning,
                          },
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        'Installment #${installment.sequenceNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Due: ${_dateLabel(installment.currentDueDate)}\nAmount: ${CurrencyHelper.pkr.format(installment.amount)} • Remaining: ${CurrencyHelper.pkr.format(installment.remainingAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                      isThreeLine: true,
                      trailing: StatusBadge(status: status),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Future<void> _openEditView() async {
    final refreshed = await Get.to<InstallmentPlanSummary>(
      () => const InstallmentPlanEditView(),
      arguments: summary,
    );
    if (refreshed != null && mounted) {
      setState(() => summary = refreshed);
      await _loadProfile();
      if (!mounted) {
        return;
      }
      showBannerAlert(
        title: 'Plan Updated',
        messages: ['Plan details have been refreshed.'],
      );
    }
  }

  ProductModel? _findProduct(PurchasePlanModel plan) {
    final primaryProductId = plan.primaryProductId;
    if (primaryProductId == null) {
      return null;
    }
    for (final product in controller.products) {
      if (product.id == primaryProductId) {
        return product;
      }
    }
    return null;
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 6),
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

  static String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';
}
