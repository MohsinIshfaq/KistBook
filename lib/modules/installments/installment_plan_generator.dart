import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
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
  final totalController = TextEditingController();
  final depositController = TextEditingController(text: '0');
  final installmentController = TextEditingController();
  final frequencyController = TextEditingController(text: '30');
  final notesController = TextEditingController();
  int? selectedCustomerId;
  int? selectedProductId;
  DateTime dueDate = DateTime.now();

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
          selectedProductId ??= logic.products.isEmpty ? null : logic.products.first.id;
          CustomerModel? selectedCustomer;
          for (final item in logic.customers) {
            if (item.id == selectedCustomerId) {
              selectedCustomer = item;
              break;
            }
          }
          ProductModel? selectedProduct;
          for (final item in logic.products) {
            if (item.id == selectedProductId) {
              selectedProduct = item;
              break;
            }
          }
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
              AppDropdownField<int?>(
                label: 'Product',
                hint: 'Select product',
                value: selectedProductId,
                prefixIcon: Icons.inventory_2_outlined,
                sheetTitle: 'Select product',
                searchHint: 'Search product',
                items: logic.products.map((item) => item.id).toList(),
                itemLabelBuilder: (id) {
                  for (final item in logic.products) {
                    if (item.id == id) {
                      return item.name;
                    }
                  }
                  return '';
                },
                onChanged: (value) => setState(() => selectedProductId = value),
              ),
              AppTextField(
                label: 'Total amount',
                hint: '25000',
                controller: totalController,
                prefixIcon: Icons.account_balance_wallet_outlined,
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                label: 'Deposit',
                hint: '5000',
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
              AppTextField(
                label: 'Notes',
                hint: 'Optional plan notes',
                controller: notesController,
                prefixIcon: Icons.sticky_note_2_outlined,
                maxLines: 2,
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
                    '${dueDate.day}-${dueDate.month}-${dueDate.year}',
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
              FilledButton(
                onPressed: selectedCustomer == null
                    ? null
                    : () async {
                        final customerId = selectedCustomer!.id!;
                        await logic.createPlan(
                          customerId: customerId,
                          product: selectedProduct,
                          itemName: selectedProduct?.name ?? 'Custom item',
                          totalAmount: double.tryParse(totalController.text.trim()) ?? 0,
                          depositAmount: double.tryParse(depositController.text.trim()) ?? 0,
                          installmentAmount:
                              double.tryParse(installmentController.text.trim()) ?? 0,
                          frequencyDays: int.tryParse(frequencyController.text.trim()) ?? 30,
                          startDate: dueDate,
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
