import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/bindings/installment_binding.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner_alert.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/product_model.dart';
import '../../data/models/purchase_plan_model.dart';
import '../../data/repositories/customer_repository.dart';
import 'installment_controller.dart';
import 'installment_plan_generator.dart';

class InstallmentPlanEditView extends StatefulWidget {
  const InstallmentPlanEditView({super.key});

  @override
  State<InstallmentPlanEditView> createState() => _InstallmentPlanEditViewState();
}

class _InstallmentPlanEditViewState extends State<InstallmentPlanEditView> {
  final controller = Get.find<InstallmentController>();
  final customerRepository = Get.find<CustomerRepository>();

  late InstallmentPlanSummary summary;
  CustomerProfile? profile;
  bool isLoading = true;
  InstallmentPlanSummary? latestSummaryResult;

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
    final screenBackground = isDark ? const Color(0xFF0D1320) : AppColors.canvas;
    final plans = profile?.plans ?? const <PurchasePlanModel>[];

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(result: latestSummaryResult),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Edit Installment Plan'),
        actions: [
          TextButton.icon(
            onPressed: _openAddPlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Plan'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _sectionCard(
                  context,
                  title: 'Customer',
                  child: _summaryIdentity(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: summary.customer.name,
                    subtitle: [
                      if (summary.customer.phone.isNotEmpty) summary.customer.phone,
                      if (summary.customer.cnic.isNotEmpty) summary.customer.cnic,
                      if (summary.customer.reference.isNotEmpty) summary.customer.reference,
                    ].join(' • ').trim().isEmpty
                        ? 'Customer linked to installment plans'
                        : [
                            if (summary.customer.phone.isNotEmpty) summary.customer.phone,
                            if (summary.customer.cnic.isNotEmpty) summary.customer.cnic,
                            if (summary.customer.reference.isNotEmpty) summary.customer.reference,
                          ].join(' • '),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Product Plans',
                  child: plans.isEmpty
                      ? Text(
                          'No product plans found for this customer.',
                          style: theme.textTheme.bodyMedium,
                        )
                      : Column(
                          children: plans.map((plan) {
                            final product = _findProduct(plan);
                            final installments = profile?.installments
                                    .where((item) => item.planId == plan.id)
                                    .toList() ??
                                const [];
                            final remainingAmount = installments.fold<double>(
                              0,
                              (sum, item) =>
                                  sum + item.remainingAmount.clamp(0, double.infinity),
                            );
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product == null
                                                  ? plan.itemName
                                                  : '${product.brandName} ${product.name}'.trim(),
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              product == null
                                                  ? 'Product details unavailable'
                                                  : product.sku.isEmpty
                                                      ? 'SKU: Not provided'
                                                      : 'SKU: ${product.sku}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton.tonalIcon(
                                        onPressed: () => _editPlanCard(plan, product),
                                        icon: const Icon(Icons.edit_outlined),
                                        label: const Text('Edit'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
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
                                        CurrencyHelper.pkr.format(plan.totalAmount),
                                      ),
                                      _metricChip(
                                        context,
                                        'Deposit',
                                        CurrencyHelper.pkr.format(plan.depositAmount),
                                      ),
                                      _metricChip(
                                        context,
                                        'Installment',
                                        CurrencyHelper.pkr.format(plan.installmentAmount),
                                      ),
                                      _metricChip(
                                        context,
                                        'Frequency',
                                        '${plan.frequencyDays} days',
                                      ),
                                      _metricChip(
                                        context,
                                        'Start date',
                                        _dateLabel(plan.startDate),
                                      ),
                                      _metricChip(
                                        context,
                                        'Remaining',
                                        CurrencyHelper.pkr.format(remainingAmount),
                                      ),
                                    ],
                                  ),
                                  if (plan.notes.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'Notes: ${plan.notes}',
                                      style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
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

  Future<void> _openAddPlan() async {
    if (!Get.isRegistered<InstallmentController>()) {
      InstallmentBinding().dependencies();
    }
    await Get.to(
      () => const InstallmentPlanGenerator(),
      arguments: {'customerId': summary.customer.id},
    );
    if (!mounted) {
      return;
    }
    await _loadProfile();
  }

  Future<void> _editPlanCard(PurchasePlanModel plan, ProductModel? product) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF101828)
          : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _PlanCardEditorSheet(
        plan: plan,
        product: product,
        controller: controller,
      ),
    );

    if (saved == true && mounted) {
      await _loadProfile();
      setState(() {});
    }
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _summaryIdentity(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.brandPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.surface,
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

  static String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';
}

class _PlanCardEditorSheet extends StatefulWidget {
  const _PlanCardEditorSheet({
    required this.plan,
    required this.product,
    required this.controller,
  });

  final PurchasePlanModel plan;
  final ProductModel? product;
  final InstallmentController controller;

  @override
  State<_PlanCardEditorSheet> createState() => _PlanCardEditorSheetState();
}

class _PlanCardEditorSheetState extends State<_PlanCardEditorSheet> {
  late final TextEditingController quantityController;
  late final TextEditingController depositController;
  late final TextEditingController installmentController;
  late final TextEditingController frequencyController;
  late final TextEditingController notesController;
  late DateTime startDate;

  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController(text: widget.plan.quantity.toString());
    depositController = TextEditingController(
      text: widget.plan.depositAmount == 0
          ? ''
          : widget.plan.depositAmount.toStringAsFixed(0),
    );
    installmentController =
        TextEditingController(text: widget.plan.installmentAmount.toStringAsFixed(0));
    frequencyController =
        TextEditingController(text: widget.plan.frequencyDays.toString());
    notesController = TextEditingController(text: widget.plan.notes);
    startDate = widget.plan.startDate;
  }

  @override
  void dispose() {
    quantityController.dispose();
    depositController.dispose();
    installmentController.dispose();
    frequencyController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product == null
                  ? 'Edit Product Plan'
                  : '${widget.product!.brandName} ${widget.product!.name}'.trim(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Quantity',
              hint: '1',
              controller: quantityController,
              prefixIcon: Icons.numbers_outlined,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: 'Deposit',
              hint: 'Optional',
              controller: depositController,
              prefixIcon: Icons.savings_outlined,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: 'Installment amount',
              hint: '3000',
              controller: installmentController,
              prefixIcon: Icons.receipt_long_outlined,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: 'Frequency in days',
              hint: '30',
              controller: frequencyController,
              prefixIcon: Icons.calendar_month_outlined,
              keyboardType: TextInputType.number,
            ),
            _modalDateField(context),
            AppTextField(
              label: 'Notes',
              hint: 'Optional plan notes',
              controller: notesController,
              prefixIcon: Icons.sticky_note_2_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveChanges,
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalDateField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileBackground = isDark ? const Color(0xFF131B2E) : AppColors.surface;
    final fieldBorderColor = isDark ? Colors.white : AppColors.border;
    final fieldTextColor = isDark ? Colors.white : AppColors.inkStrong;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'First due date',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.inkStrong,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: tileBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: fieldBorderColor),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Icon(
                Icons.event_outlined,
                color: fieldTextColor,
                size: 20,
              ),
              title: Text(
                _InstallmentPlanEditViewState._dateLabel(startDate),
                style: TextStyle(
                  color: fieldTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(Icons.arrow_drop_down_rounded, color: fieldTextColor),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => startDate = picked);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    final deposit = double.tryParse(depositController.text.trim()) ?? 0;
    final installment = double.tryParse(installmentController.text.trim()) ?? 0;
    final frequency = int.tryParse(frequencyController.text.trim()) ?? 0;
    final unitPrice = widget.product?.salePrice ?? widget.plan.unitPrice;
    final totalAmount = unitPrice * quantity;
    final errors = <String>[];

    if (quantity <= 0) {
      errors.add('Quantity must be greater than zero.');
    }
    if (deposit < 0) {
      errors.add('Deposit cannot be negative.');
    }
    if (deposit > totalAmount) {
      errors.add('Deposit cannot be greater than total amount.');
    }
    if (installment <= 0) {
      errors.add('Installment amount must be greater than zero.');
    }
    if (frequency <= 0) {
      errors.add('Frequency days must be greater than zero.');
    }

    if (errors.isNotEmpty) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Validation Errors',
        messages: errors,
        duration: 5,
      );
      return;
    }

    final productId = widget.plan.primaryProductId;
    final updatedPlan = widget.plan.copyWith(
      quantity: quantity,
      unitPrice: unitPrice,
      productIds: productId == null ? widget.plan.productIds : [productId],
      productSelections: productId == null
          ? widget.plan.productSelections
          : [PlanProductSelection(productId: productId, quantity: quantity)],
      itemName: widget.product == null
          ? widget.plan.itemName
          : '${widget.product!.name} x$quantity',
      totalAmount: totalAmount,
      depositAmount: deposit,
      installmentAmount: installment,
      frequencyDays: frequency,
      startDate: startDate,
      notes: notesController.text.trim(),
    );

    await widget.controller.updatePlan(updatedPlan);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
    showBannerAlert(
      title: 'Plan Updated',
      messages: [
        '${widget.product == null ? widget.plan.itemName : widget.product!.name} ka plan update kar diya gaya hai.',
      ],
    );
  }
}
