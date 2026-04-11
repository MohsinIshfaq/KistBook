import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner_alert.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/product_model.dart';
import '../../data/models/purchase_plan_model.dart';
import 'installment_controller.dart';

class InstallmentPlanEditView extends StatefulWidget {
  const InstallmentPlanEditView({super.key});

  @override
  State<InstallmentPlanEditView> createState() => _InstallmentPlanEditViewState();
}

class _InstallmentPlanEditViewState extends State<InstallmentPlanEditView> {
  late InstallmentPlanSummary summary;
  final controller = Get.find<InstallmentController>();

  late final TextEditingController depositController;
  late final TextEditingController installmentController;
  late final TextEditingController frequencyController;
  late final TextEditingController notesController;
  late DateTime startDate;
  late final Map<int, int> selectedProductQuantities;

  @override
  void initState() {
    super.initState();
    summary = Get.arguments as InstallmentPlanSummary;
    depositController = TextEditingController(
      text: summary.plan.depositAmount == 0
          ? ''
          : summary.plan.depositAmount.toStringAsFixed(0),
    );
    installmentController =
        TextEditingController(text: summary.plan.installmentAmount.toStringAsFixed(0));
    frequencyController =
        TextEditingController(text: summary.plan.frequencyDays.toString());
    notesController = TextEditingController(text: summary.plan.notes);
    startDate = summary.plan.startDate;
    selectedProductQuantities = {
      for (final selection in _initialSelections) selection.productId: selection.quantity,
    };
  }

  @override
  void dispose() {
    depositController.dispose();
    installmentController.dispose();
    frequencyController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenBackground = isDark ? const Color(0xFF0D1320) : AppColors.canvas;
    final selectedProducts = _selectedProducts;

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: AppBar(title: const Text('Edit Installment Plan')),
      body: ListView(
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
                  ? 'Customer linked to this plan'
                  : [
                      if (summary.customer.phone.isNotEmpty) summary.customer.phone,
                      if (summary.customer.cnic.isNotEmpty) summary.customer.cnic,
                      if (summary.customer.reference.isNotEmpty) summary.customer.reference,
                    ].join(' • '),
            ),
          ),
          const SizedBox(height: 16),
          _buildProductSelectorField(context, selectedProducts),
          if (selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionCard(
              context,
              title: 'Selected Products & Plan Setup',
              child: Column(
                children: selectedProducts.map((entry) {
                  final product = entry.$1;
                  final quantity = entry.$2;
                  final lineTotal = entry.$3;
                  final parsedDeposit = double.tryParse(depositController.text.trim()) ?? 0;
                  final parsedInstallment =
                      double.tryParse(installmentController.text.trim()) ?? 0;
                  final parsedFrequency = int.tryParse(frequencyController.text.trim()) ?? 0;
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${product.brandName} ${product.name}'.trim(),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  'Quantity: $quantity',
                                  'Unit: ${CurrencyHelper.pkr.format(product.salePrice)}',
                                  'Total: ${CurrencyHelper.pkr.format(lineTotal)}',
                                ].join(' • '),
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.sku.isEmpty
                                    ? 'SKU: Not provided'
                                    : 'SKU: ${product.sku}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _planInfoChip(
                                    context,
                                    label: 'Deposit',
                                    value: CurrencyHelper.pkr.format(parsedDeposit),
                                  ),
                                  _planInfoChip(
                                    context,
                                    label: 'Installment',
                                    value: CurrencyHelper.pkr.format(parsedInstallment),
                                  ),
                                  _planInfoChip(
                                    context,
                                    label: 'Frequency',
                                    value: parsedFrequency <= 0
                                        ? 'Not set'
                                        : '$parsedFrequency days',
                                  ),
                                  _planInfoChip(
                                    context,
                                    label: 'First due',
                                    value: _dateLabel(startDate),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _openPlanSetupEditor,
                                  icon: const Icon(Icons.tune_rounded),
                                  label: const Text('Update Plan Setup'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          tooltip: 'Remove product',
                          onPressed: () => _confirmRemoveProduct(product),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryTile(
                context,
                label: 'Plan total',
                value: CurrencyHelper.pkr.format(_grandTotal),
              ),
              const SizedBox(width: 12),
              _summaryTile(
                context,
                label: 'Remaining',
                value: CurrencyHelper.pkr.format(summary.remainingAmount),
              ),
            ],
          ),
          FilledButton(
            onPressed: _saveChanges,
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  List<PlanProductSelection> get _initialSelections {
    if (summary.plan.productSelections.isNotEmpty) {
      return summary.plan.productSelections;
    }
    final primaryProductId = summary.plan.primaryProductId;
    if (primaryProductId == null) {
      return const [];
    }
    return [
      PlanProductSelection(
        productId: primaryProductId,
        quantity: summary.plan.quantity.clamp(1, 999999),
      ),
    ];
  }

  List<(ProductModel, int, double)> get _selectedProducts {
    final byId = {
      for (final product in controller.products)
        if (product.id != null) product.id!: product,
    };

    return selectedProductQuantities.entries
        .map((entry) {
          final product = byId[entry.key];
          if (product == null) {
            return null;
          }
          return (
            product,
            entry.value,
            product.salePrice * entry.value,
          );
        })
        .whereType<(ProductModel, int, double)>()
        .toList()
      ..sort((a, b) => a.$1.name.compareTo(b.$1.name));
  }

  double get _grandTotal =>
      _selectedProducts.fold(0, (sum, entry) => sum + entry.$3);

  Widget _buildProductSelectorField(
    BuildContext context,
    List<(ProductModel, int, double)> selectedProducts,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = selectedProducts.isEmpty
        ? 'Select one or more products'
        : selectedProducts.length == 1
            ? '${selectedProducts.first.$1.name} x${selectedProducts.first.$2}'
            : '${selectedProducts.length} products selected';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Products',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.inkStrong,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openProductSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: isDark ? Colors.white : AppColors.inkStrong,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: selectedProducts.isEmpty
                                ? (isDark
                                    ? Colors.white.withValues(alpha: 0.78)
                                    : AppColors.inkMuted)
                                : (isDark ? Colors.white : AppColors.inkStrong),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selectedProducts.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            selectedProducts
                                .map((item) => '${item.$1.brandName} ${item.$1.name} x${item.$2}')
                                .join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : AppColors.inkSoft,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white : AppColors.inkStrong,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _summaryTile(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
      ),
    );
  }

  Widget _planInfoChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.border.withValues(alpha: 0.75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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

  Widget _dateField(
    BuildContext context, {
    required Color tileBackground,
    required Color fieldBorderColor,
    required Color fieldTextColor,
    ValueChanged<DateTime>? onDateChanged,
  }) {
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.inkStrong,
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
                _dateLabel(startDate),
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
                  if (onDateChanged != null) {
                    onDateChanged(picked);
                  } else {
                    setState(() => startDate = picked);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime value) => '${value.day}-${value.month}-${value.year}';

  Future<void> _openPlanSetupEditor() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldTextColor = isDark ? Colors.white : AppColors.inkStrong;
    final fieldBorderColor = isDark ? Colors.white : AppColors.border;
    final tileBackground = isDark ? const Color(0xFF131B2E) : AppColors.surface;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF101828) : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      'Update Plan Setup',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This setup will apply to all selected products in this installment plan.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 18),
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
                    _dateField(
                      context,
                      tileBackground: tileBackground,
                      fieldBorderColor: fieldBorderColor,
                      fieldTextColor: fieldTextColor,
                      onDateChanged: (value) {
                        setState(() => startDate = value);
                        setModalState(() {});
                      },
                    ),
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
                        onPressed: () {
                          setState(() {});
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply Setup'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openProductSelector() async {
    final selected = await Navigator.of(context).push<Map<int, int>>(
      PageRouteBuilder<Map<int, int>>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) => _EditProductMultiSelectPage(
          products: controller.products,
          initialSelectedQuantities: selectedProductQuantities,
          searchTextBuilder: _productSearchText,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      selectedProductQuantities
        ..clear()
        ..addAll(selected);
    });
  }

  String _productSearchText(ProductModel product) {
    return [
      product.brandName,
      product.name,
      product.sku,
      product.notes,
      product.salePrice.toStringAsFixed(0),
    ].where((value) => value.trim().isNotEmpty).join(' ');
  }

  Future<void> _confirmRemoveProduct(ProductModel product) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Product'),
          content: Text(
            'Do you want to remove ${product.brandName} ${product.name} from this installment plan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true || product.id == null) {
      return;
    }

    setState(() {
      selectedProductQuantities.remove(product.id);
    });
  }

  Future<void> _saveChanges() async {
    final deposit = double.tryParse(depositController.text.trim()) ?? 0;
    final installment = double.tryParse(installmentController.text.trim()) ?? 0;
    final frequency = int.tryParse(frequencyController.text.trim()) ?? 0;
    final errors = <String>[];

    if (selectedProductQuantities.isEmpty) {
      errors.add('Select at least one product.');
    }
    if (deposit < 0) {
      errors.add('Deposit cannot be negative.');
    }
    if (deposit > _grandTotal) {
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

    final orderedSelections = selectedProductQuantities.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final productSelections = orderedSelections
        .map(
          (entry) => PlanProductSelection(
            productId: entry.key,
            quantity: entry.value,
          ),
        )
        .toList();
    final totalQuantity = productSelections.fold<int>(0, (sum, item) => sum + item.quantity);
    final primaryProductId = productSelections.first.productId;
    final productIds = productSelections.map((item) => item.productId).toList();
    final itemName = _selectedProducts.length == 1
        ? '${_selectedProducts.first.$1.name} x${_selectedProducts.first.$2}'
        : '${_selectedProducts.length} products';
    final unitPrice = totalQuantity == 0 ? 0.0 : (_grandTotal / totalQuantity);

    final updatedPlan = summary.plan.copyWith(
      productId: primaryProductId,
      quantity: totalQuantity,
      unitPrice: unitPrice,
      productIds: productIds,
      productSelections: productSelections,
      itemName: itemName,
      totalAmount: _grandTotal,
      depositAmount: deposit,
      installmentAmount: installment,
      frequencyDays: frequency,
      startDate: startDate,
      notes: notesController.text.trim(),
    );

    final refreshed = await controller.updatePlan(updatedPlan);
    if (!mounted) {
      return;
    }
    if (refreshed != null) {
      Get.back(result: refreshed);
    } else {
      Get.back();
    }
  }
}

class _EditProductMultiSelectPage extends StatefulWidget {
  const _EditProductMultiSelectPage({
    required this.products,
    required this.initialSelectedQuantities,
    required this.searchTextBuilder,
  });

  final List<ProductModel> products;
  final Map<int, int> initialSelectedQuantities;
  final String Function(ProductModel product) searchTextBuilder;

  @override
  State<_EditProductMultiSelectPage> createState() => _EditProductMultiSelectPageState();
}

class _EditProductMultiSelectPageState extends State<_EditProductMultiSelectPage> {
  final TextEditingController searchController = TextEditingController();
  late final Map<int, int> selectedQuantities =
      Map<int, int>.from(widget.initialSelectedQuantities);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.30);
    final pageBackground = isDark ? const Color(0xFF1A1329) : const Color(0xFFF5F7FC);
    final dividerColor = isDark ? Colors.white12 : AppColors.border;
    final query = searchController.text.trim().toLowerCase();
    final filtered = widget.products.where((product) {
      return widget.searchTextBuilder(product).toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: overlayColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Container(
            decoration: BoxDecoration(
              color: pageBackground,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 0),
                  child: Row(
                    children: [
                      Text(
                        'Select Products',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: dividerColor, height: 20),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.inkStrong,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by brand, product, SKU',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white70 : AppColors.inkSoft,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: dividerColor, height: 20),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No products found',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                Divider(color: dividerColor, height: 1),
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              final quantity =
                                  product.id == null ? 0 : (selectedQuantities[product.id] ?? 0);
                              final isSelected = quantity > 0;
                              return ListTile(
                                onTap: () {
                                  if (product.id == null) {
                                    return;
                                  }
                                  setState(() {
                                    if (isSelected) {
                                      selectedQuantities.remove(product.id);
                                    } else {
                                      selectedQuantities[product.id!] = 1;
                                    }
                                  });
                                },
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 6,
                                ),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(
                                            alpha: isDark ? 0.18 : 0.10,
                                          )
                                        : AppColors.brandAccent.withValues(
                                            alpha: isDark ? 0.18 : 0.10,
                                          ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_rounded
                                        : Icons.inventory_2_outlined,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : AppColors.brandAccent,
                                  ),
                                ),
                                title: Text(
                                  product.name,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (product.brandName.isNotEmpty) product.brandName,
                                    if (product.sku.isNotEmpty) 'SKU: ${product.sku}',
                                    'Price: ${product.salePrice.toStringAsFixed(0)}',
                                    if (isSelected) 'Qty: $quantity',
                                  ].join(' • '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.35,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              if (product.id == null) {
                                                return;
                                              }
                                              setState(() {
                                                final current =
                                                    selectedQuantities[product.id] ?? 1;
                                                if (current <= 1) {
                                                  selectedQuantities.remove(product.id);
                                                } else {
                                                  selectedQuantities[product.id!] =
                                                      current - 1;
                                                }
                                              });
                                            },
                                            icon: const Icon(Icons.remove_circle_outline),
                                          ),
                                          Text(
                                            '$quantity',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              if (product.id == null) {
                                                return;
                                              }
                                              setState(() {
                                                final current =
                                                    selectedQuantities[product.id] ?? 0;
                                                selectedQuantities[product.id!] = current + 1;
                                              });
                                            },
                                            icon: const Icon(Icons.add_circle_outline),
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: dividerColor, height: 20),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedQuantities.isEmpty
                            ? 'No product selected'
                            : '${selectedQuantities.length} product${selectedQuantities.length == 1 ? '' : 's'} selected',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(
                                Map<int, int>.fromEntries(
                                  selectedQuantities.entries.toList()
                                    ..sort((a, b) => a.key.compareTo(b.key)),
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
