import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/models/product_model.dart';
import 'product_controller.dart';

class ProductFormView extends StatefulWidget {
  const ProductFormView({super.key});

  @override
  State<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<ProductFormView> {
  final controller = Get.find<ProductController>();
  final categoryController = TextEditingController();
  final brandController = TextEditingController();
  final nameController = TextEditingController();
  final skuController = TextEditingController();
  final priceController = TextEditingController();
  final notesController = TextEditingController();
  final List<String> selectedCategories = [];
  ProductModel? existing;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is ProductModel) {
      existing = arg;
      selectedCategories
        ..clear()
        ..addAll(arg.categories);
      brandController.text = arg.brandName;
      nameController.text = arg.name;
      skuController.text = arg.sku;
      priceController.text = arg.salePrice.toStringAsFixed(0);
      notesController.text = arg.notes;
    }
  }

  void _addCategory() {
    final normalized = TextHelper.toTitleCase(categoryController.text);
    if (normalized.isEmpty) {
      return;
    }
    if (selectedCategories.contains(normalized)) {
      categoryController.clear();
      return;
    }
    setState(() {
      selectedCategories.add(normalized);
      categoryController.clear();
    });
  }

  @override
  void dispose() {
    categoryController.dispose();
    brandController.dispose();
    nameController.dispose();
    skuController.dispose();
    priceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((existing == null ? 'Add Product' : 'Edit Product').tr),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categories'.tr,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppColors.inkStrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: categoryController,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _addCategory(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppColors.inkStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter category and add'.tr,
                          prefixIcon: const Icon(Icons.category_outlined, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: FilledButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add_rounded),
                        label: Text('Add'.tr),
                      ),
                    ),
                  ],
                ),
                if (selectedCategories.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedCategories.map((category) {
                      return Chip(
                        label: Text(category),
                        onDeleted: () {
                          setState(() => selectedCategories.remove(category));
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          AppTextField(
            label: 'Brand name'.tr,
            hint: 'Enter brand name'.tr,
            controller: brandController,
            prefixIcon: Icons.business_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          AppTextField(
            label: 'Product name'.tr,
            hint: 'Enter product title'.tr,
            controller: nameController,
            prefixIcon: Icons.inventory_2_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          AppTextField(
            label: 'SKU / code'.tr,
            hint: 'PRD-1001',
            controller: skuController,
            prefixIcon: Icons.qr_code_2_outlined,
          ),
          AppTextField(
            label: 'Sale price'.tr,
            hint: '15000',
            controller: priceController,
            prefixIcon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
          AppTextField(
            label: 'Notes'.tr,
            hint: 'Optional product notes'.tr,
            controller: notesController,
            prefixIcon: Icons.edit_note_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              _addCategory();
              final brandName = TextHelper.toTitleCase(brandController.text);
              final productName = TextHelper.toTitleCase(nameController.text);
              final sku = skuController.text.trim();
              final salePrice = double.tryParse(priceController.text.trim()) ?? 0;
              final notes = notesController.text.trim();
              final errors = <String>[];

              if (brandName.isEmpty) {
                errors.add('Brand name is required.'.tr);
              }
              if (selectedCategories.isEmpty) {
                errors.add('At least one category is required.'.tr);
              }
              if (selectedCategories.any((item) => item.trim().length < 2)) {
                errors.add('Each category should be at least 2 characters.'.tr);
              }
              if (productName.isEmpty) {
                errors.add('Product name is required.'.tr);
              }
              if (salePrice <= 0) {
                errors.add('Price must be greater than zero.'.tr);
              }
              if (productName.length < 2) {
                errors.add('Product name should be at least 2 characters.'.tr);
              }
              if (brandName.length < 2) {
                errors.add('Brand name should be at least 2 characters.'.tr);
              }
              if (sku.isNotEmpty && sku.length < 3) {
                errors.add('SKU/code should be at least 3 characters if provided.'.tr);
              }
              if (salePrice > 999999999) {
                errors.add('Price looks too high. Please recheck the amount.'.tr);
              }
              if (notes.length > 250) {
                errors.add('Notes should be 250 characters or less.'.tr);
              }

              if (errors.isNotEmpty) {
                showBannerAlert(
                  type: BannerStyle.error,
                  title: 'Validation Errors'.tr,
                  messages: errors,
                  duration: 4,
                );
                return;
              }

              await controller.saveProduct(
                ProductModel(
                  id: existing?.id,
                  categories: List<String>.from(selectedCategories),
                  brandName: brandName,
                  name: productName,
                  sku: sku,
                  salePrice: salePrice,
                  notes: notes,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                  updatedAt: existing?.updatedAt ?? DateTime.now(),
                ),
              );
              Get.back();
            },
            child: Text('Save Product'.tr),
          ),
        ],
      ),
    );
  }
}
