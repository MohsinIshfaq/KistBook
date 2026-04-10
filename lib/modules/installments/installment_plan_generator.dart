import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/app_dropdown_field.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/product_model.dart';
import 'installment_controller.dart';

class InstallmentPlanGenerator extends StatefulWidget {
  const InstallmentPlanGenerator({super.key});

  @override
  State<InstallmentPlanGenerator> createState() => _InstallmentPlanGeneratorState();
}

class _InstallmentPlanGeneratorState extends State<InstallmentPlanGenerator> {
  final controller = Get.find<InstallmentController>();
  final depositController = TextEditingController(text: '0');
  final installmentController = TextEditingController();
  final frequencyController = TextEditingController(text: '30');
  final notesController = TextEditingController();
  int? selectedCustomerId;
  final Map<int, int> selectedProductQuantities = {};
  final Map<int, _PerProductPlanTerms> perProductTerms = {};
  bool useCommonTerms = true;
  DateTime dueDate = DateTime.now();

  @override
  void dispose() {
    depositController.dispose();
    installmentController.dispose();
    frequencyController.dispose();
    notesController.dispose();
    for (final terms in perProductTerms.values) {
      terms.dispose();
    }
    super.dispose();
  }

  String _customerSearchText(CustomerModel customer) {
    return [
      customer.name,
      customer.phone,
      customer.cnic,
      customer.reference,
      customer.address,
    ].where((value) => value.trim().isNotEmpty).join(' ');
  }

  Widget _buildCustomerSelectionItem(
    BuildContext context,
    CustomerModel customer,
    bool selected,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10)
            : (isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.surfaceMuted),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : (isDark ? Colors.white12 : AppColors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : AppColors.brandAccent.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: selected ? theme.colorScheme.primary : AppColors.brandAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Phone: ${customer.phone.isEmpty ? 'Not provided' : customer.phone}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'CNIC: ${customer.cnic.isEmpty ? 'Not provided' : customer.cnic}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (customer.reference.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Reference: ${customer.reference}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Address: ${customer.address}',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _syncPerProductTerms(List<ProductModel> products) {
    final selectedIds = selectedProductQuantities.keys.toSet();
    final removableIds = perProductTerms.keys.where((id) => !selectedIds.contains(id)).toList();
    for (final id in removableIds) {
      perProductTerms.remove(id)?.dispose();
    }

    for (final product in products) {
      final productId = product.id;
      if (productId == null || !selectedIds.contains(productId)) {
        continue;
      }
      perProductTerms.putIfAbsent(
        productId,
        () => _PerProductPlanTerms(
          deposit: depositController.text.trim().isEmpty ? '0' : depositController.text.trim(),
          installment: installmentController.text.trim(),
          frequencyDays: frequencyController.text.trim().isEmpty
              ? '30'
              : frequencyController.text.trim(),
          dueDate: dueDate,
        ),
      );
    }
  }

  double _productTotal(ProductModel product) {
    final quantity = selectedProductQuantities[product.id] ?? 1;
    return product.salePrice * quantity;
  }

  String _dateLabel(DateTime value) => '${value.day}-${value.month}-${value.year}';

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

  Future<void> _openProductSelector(
    BuildContext context,
    List<ProductModel> products,
  ) async {
    final selected = await Navigator.of(context).push<Map<int, int>>(
      PageRouteBuilder<Map<int, int>>(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) => _ProductMultiSelectPage(
          products: products,
          initialSelectedQuantities: selectedProductQuantities,
          searchTextBuilder: _productSearchText,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenBackground = isDark ? const Color(0xFF0D1320) : AppColors.canvas;
    final fieldTextColor = isDark ? Colors.white : AppColors.inkStrong;
    final fieldBorderColor = isDark ? Colors.white : AppColors.border;
    final tileBackground = isDark ? const Color(0xFF131B2E) : AppColors.surface;

    return Scaffold(
      backgroundColor: screenBackground,
      appBar: AppBar(title: const Text('Create Installment Plan')),
      body: GetBuilder<InstallmentController>(
        builder: (logic) {
          selectedCustomerId ??= logic.customers.isEmpty ? null : logic.customers.first.id;
          CustomerModel? selectedCustomer;
          for (final item in logic.customers) {
            if (item.id == selectedCustomerId) {
              selectedCustomer = item;
              break;
            }
          }
          final selectedProducts = logic.products
              .where(
                (item) =>
                    item.id != null && selectedProductQuantities.containsKey(item.id),
              )
              .toList();
          _syncPerProductTerms(logic.products);
          final selectedProductsLabel = selectedProducts.isEmpty
              ? 'Select one or more products'
              : selectedProducts.length == 1
                  ? '${selectedProducts.first.name} x${selectedProductQuantities[selectedProducts.first.id] ?? 1}'
                  : '${selectedProducts.length} products selected';
          final grandTotal = selectedProducts.fold<double>(
            0,
            (sum, product) => sum + _productTotal(product),
          );
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppDropdownField<CustomerModel>(
                label: 'Customer',
                hint: 'Select customer',
                value: selectedCustomer,
                prefixIcon: Icons.person_outline,
                sheetTitle: 'Select customer',
                searchHint: 'Search by name, phone, CNIC, reference',
                presentation: AppSelectionPresentation.fullScreen,
                items: logic.customers,
                itemLabelBuilder: (customer) => customer.name,
                selectedLabelBuilder: (customer) => customer.name,
                itemSearchTextBuilder: _customerSearchText,
                itemBuilder: _buildCustomerSelectionItem,
                onChanged: (value) => setState(() => selectedCustomerId = value?.id),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
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
                      onTap: () => _openProductSelector(context, logic.products),
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
                                    selectedProductsLabel,
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
                                          .map(
                                            (item) =>
                                                '${item.brandName} ${item.name} x${selectedProductQuantities[item.id] ?? 1}'
                                                    .trim(),
                                          )
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
              ),
              if (selectedProducts.isNotEmpty) ...[
                Row(
                  children: [
                    _summaryTile(
                      context,
                      label: 'Selected products',
                      value: '${selectedProducts.length}',
                    ),
                    const SizedBox(width: 12),
                    _summaryTile(
                      context,
                      label: 'Grand total',
                      value: grandTotal.toStringAsFixed(0),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              SwitchListTile.adaptive(
                value: useCommonTerms,
                contentPadding: EdgeInsets.zero,
                title: const Text('Use same deposit, installment, days and due date'),
                subtitle: Text(
                  useCommonTerms
                      ? 'One setup will apply to every selected product.'
                      : 'Each selected product can have its own financing setup.',
                ),
                onChanged: (value) => setState(() => useCommonTerms = value),
              ),
              if (useCommonTerms) ...[
                AppTextField(
                  label: 'Common deposit',
                  hint: '5000',
                  controller: depositController,
                  prefixIcon: Icons.savings_outlined,
                  keyboardType: TextInputType.number,
                ),
                AppTextField(
                  label: 'Common installment amount',
                  hint: '3000',
                  controller: installmentController,
                  prefixIcon: Icons.receipt_long_outlined,
                  keyboardType: TextInputType.number,
                ),
                AppTextField(
                  label: 'Common frequency in days',
                  hint: '30',
                  controller: frequencyController,
                  prefixIcon: Icons.calendar_month_outlined,
                  keyboardType: TextInputType.number,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 8),
                  child: Text(
                    'Common first due date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
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
                      _dateLabel(dueDate),
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
                        initialDate: dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => dueDate = picked);
                      }
                    },
                  ),
                ),
              ] else ...[
                ...selectedProducts.map((product) {
                  final terms = perProductTerms[product.id]!;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${product.brandName} ${product.name}'.trim(),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Qty ${selectedProductQuantities[product.id] ?? 1} • Unit ${product.salePrice.toStringAsFixed(0)} • Total ${_productTotal(product).toStringAsFixed(0)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Deposit',
                            hint: '5000',
                            controller: terms.depositController,
                            prefixIcon: Icons.savings_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          AppTextField(
                            label: 'Installment amount',
                            hint: '3000',
                            controller: terms.installmentController,
                            prefixIcon: Icons.receipt_long_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          AppTextField(
                            label: 'Frequency in days',
                            hint: '30',
                            controller: terms.frequencyController,
                            prefixIcon: Icons.calendar_month_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 2, bottom: 8),
                            child: Text(
                              'First due date',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: tileBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: fieldBorderColor),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: Icon(
                                Icons.event_outlined,
                                color: fieldTextColor,
                                size: 20,
                              ),
                              title: Text(
                                _dateLabel(terms.dueDate),
                                style: TextStyle(
                                  color: fieldTextColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: fieldTextColor,
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: terms.dueDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => terms.dueDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              AppTextField(
                label: 'Notes',
                hint: 'Optional plan notes',
                controller: notesController,
                prefixIcon: Icons.sticky_note_2_outlined,
                maxLines: 2,
              ),
              FilledButton(
                onPressed: () async {
                        final errors = <String>[];
                        if (selectedCustomer == null) {
                          errors.add('Select a customer.');
                        }
                        if (selectedProducts.isEmpty) {
                          errors.add('Select at least one product.');
                        }
                        if (useCommonTerms &&
                            (double.tryParse(installmentController.text.trim()) ?? 0) <= 0) {
                          errors.add('Enter common installment amount.');
                        }

                        final productInputs = <CreatePlanProductInput>[];
                        for (final product in selectedProducts) {
                          final quantity = selectedProductQuantities[product.id] ?? 1;
                          final totalAmount = _productTotal(product);
                          final terms = perProductTerms[product.id];
                          final depositAmount = double.tryParse(
                                (useCommonTerms
                                        ? depositController.text
                                        : terms?.depositController.text) ??
                                    '0',
                              ) ??
                              0;
                          final installmentAmount = double.tryParse(
                                (useCommonTerms
                                        ? installmentController.text
                                        : terms?.installmentController.text) ??
                                    '0',
                              ) ??
                              0;
                          final frequencyDays = int.tryParse(
                                (useCommonTerms
                                        ? frequencyController.text
                                        : terms?.frequencyController.text) ??
                                    '30',
                              ) ??
                              0;
                          final startDate = useCommonTerms ? dueDate : (terms?.dueDate ?? dueDate);

                          if (depositAmount < 0) {
                            errors.add('${product.name}: deposit cannot be negative.');
                          }
                          if (depositAmount > totalAmount) {
                            errors.add('${product.name}: deposit cannot be greater than total amount.');
                          }
                          if (installmentAmount <= 0) {
                            errors.add('${product.name}: installment amount must be greater than zero.');
                          }
                          if (frequencyDays <= 0) {
                            errors.add('${product.name}: frequency days must be greater than zero.');
                          }

                          productInputs.add(
                            CreatePlanProductInput(
                              product: product,
                              quantity: quantity,
                              itemName: '${product.name} x$quantity',
                              totalAmount: totalAmount,
                              depositAmount: depositAmount,
                              installmentAmount: installmentAmount,
                              frequencyDays: frequencyDays,
                              startDate: startDate,
                            ),
                          );
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

                        final customerId = selectedCustomer!.id!;
                        await logic.createPlan(
                          customerId: customerId,
                          products: productInputs,
                          notes: notesController.text.trim(),
                        );
                        Get.back();
                      },
                child: const Text('Create Plan'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PerProductPlanTerms {
  _PerProductPlanTerms({
    required String deposit,
    required String installment,
    required String frequencyDays,
    required this.dueDate,
  })  : depositController = TextEditingController(text: deposit),
        installmentController = TextEditingController(text: installment),
        frequencyController = TextEditingController(text: frequencyDays);

  final TextEditingController depositController;
  final TextEditingController installmentController;
  final TextEditingController frequencyController;
  DateTime dueDate;

  void dispose() {
    depositController.dispose();
    installmentController.dispose();
    frequencyController.dispose();
  }
}

class _ProductMultiSelectPage extends StatefulWidget {
  const _ProductMultiSelectPage({
    required this.products,
    required this.initialSelectedQuantities,
    required this.searchTextBuilder,
  });

  final List<ProductModel> products;
  final Map<int, int> initialSelectedQuantities;
  final String Function(ProductModel product) searchTextBuilder;

  @override
  State<_ProductMultiSelectPage> createState() => _ProductMultiSelectPageState();
}

class _ProductMultiSelectPageState extends State<_ProductMultiSelectPage> {
  final TextEditingController searchController = TextEditingController();
  late final Map<int, int> selectedQuantities =
      Map<int, int>.from(widget.initialSelectedQuantities);

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
