import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/product_model.dart';
import 'installment_controller.dart';
import 'installment_plan_edit_view.dart';

class InstallmentPlanDetailView extends StatefulWidget {
  const InstallmentPlanDetailView({super.key});

  @override
  State<InstallmentPlanDetailView> createState() => _InstallmentPlanDetailViewState();
}

class _InstallmentPlanDetailViewState extends State<InstallmentPlanDetailView> {
  late InstallmentPlanSummary summary;
  final controller = Get.find<InstallmentController>();

  @override
  void initState() {
    super.initState();
    summary = Get.arguments as InstallmentPlanSummary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final linkedProducts = _linkedProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Detail'),
        actions: [
          IconButton(
            tooltip: 'Edit plan',
            onPressed: _openEditView,
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
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
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              linkedProducts.length <= 1
                                  ? (summary.product?.name ?? summary.plan.itemName)
                                  : '${linkedProducts.length} products linked',
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
                  _detailRow(context, 'Reference', summary.customer.reference),
                  _detailRow(context, 'Address', summary.customer.address),
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
                    'Product Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (linkedProducts.isEmpty)
                    _detailRow(
                      context,
                      'Product',
                      summary.product?.name ?? summary.plan.itemName,
                    )
                  else
                    ...linkedProducts.map((entry) {
                      final product = entry.$1;
                      final quantity = entry.$2;
                      final lineTotal = entry.$3;
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
                            Text(
                              '${product.brandName} ${product.name}'.trim(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SKU: ${product.sku.isEmpty ? 'Not provided' : product.sku}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quantity: $quantity • Unit: ${CurrencyHelper.pkr.format(product.salePrice)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Line total: ${CurrencyHelper.pkr.format(lineTotal)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Notes: ${product.notes.isEmpty ? 'Not provided' : product.notes}',
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Summary',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _metricChip(context, 'Total', CurrencyHelper.pkr.format(summary.plan.totalAmount)),
                      _metricChip(context, 'Collected', CurrencyHelper.pkr.format(summary.collectedAmount)),
                      _metricChip(context, 'Remaining', CurrencyHelper.pkr.format(summary.remainingAmount)),
                      _metricChip(context, 'Pending installments', '${summary.remainingInstallments}'),
                      _metricChip(
                        context,
                        'Next due',
                        summary.nextDueDate == null
                            ? 'N/A'
                            : summary.nextDueDate!.toLocal().toString().split(' ').first,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    'Deposit',
                    CurrencyHelper.pkr.format(summary.plan.depositAmount),
                  ),
                  _detailRow(
                    context,
                    'Installment amount',
                    CurrencyHelper.pkr.format(summary.plan.installmentAmount),
                  ),
                  _detailRow(context, 'Frequency', '${summary.plan.frequencyDays} days'),
                  _detailRow(
                    context,
                    'Start date',
                    summary.plan.startDate.toLocal().toString().split(' ').first,
                  ),
                  _detailRow(
                    context,
                    'Notes',
                    summary.plan.notes.isEmpty ? 'Not provided' : summary.plan.notes,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Installment Schedule',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...summary.installments.map(
            (installment) {
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
                        InstallmentVisualStatus.overdue => AppColors.danger,
                        InstallmentVisualStatus.pending => AppColors.warning,
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
                      'Due: ${installment.currentDueDate.toLocal().toString().split(' ').first}\nAmount: ${CurrencyHelper.pkr.format(installment.amount)} • Remaining: ${CurrencyHelper.pkr.format(installment.remainingAmount)}',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: StatusBadge(status: status),
                ),
              );
            },
          ),
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
      showBannerAlert(
        title: 'Plan Updated',
        messages: ['Plan details have been refreshed.'],
      );
    }
  }

  List<(ProductModel, int, double)> get _linkedProducts {
    final byId = {
      for (final product in controller.products)
        if (product.id != null) product.id!: product,
    };

    if (summary.plan.productSelections.isNotEmpty) {
      return summary.plan.productSelections
          .map((selection) {
            final product = byId[selection.productId];
            if (product == null) {
              return null;
            }
            return (
              product,
              selection.quantity,
              product.salePrice * selection.quantity,
            );
          })
          .whereType<(ProductModel, int, double)>()
          .toList();
    }

    if (summary.product != null) {
      return [
        (
          summary.product!,
          summary.plan.quantity,
          summary.plan.unitPrice * summary.plan.quantity,
        ),
      ];
    }

    return const [];
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
            : AppColors.surfaceMuted,
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
}
