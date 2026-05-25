import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/models/product_model.dart';
import '../../services/product_image_storage.dart';
import 'product_controller.dart';
import 'product_image_preview_view.dart';
import 'product_image_remove_dialog.dart';

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
  final ImagePicker imagePicker = ImagePicker();
  final List<String> selectedCategories = [];
  final List<String> productImagePaths = [];
  final Set<String> sessionAddedImagePaths = {};
  ProductModel? existing;
  bool didSave = false;

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
      productImagePaths
        ..clear()
        ..addAll(arg.imagePaths);
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

  Future<void> _openImageSourcePicker() async {
    final source = await showModalBottomSheet<_ProductImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Product Images'.tr,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _ImageSourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery'.tr,
                  subtitle: 'Select multiple product images'.tr,
                  onTap: () =>
                      Navigator.of(context).pop(_ProductImageSource.gallery),
                ),
                const SizedBox(height: 10),
                _ImageSourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take Photo'.tr,
                  subtitle: 'Capture a product image'.tr,
                  onTap: () =>
                      Navigator.of(context).pop(_ProductImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || source == null) {
      return;
    }

    try {
      if (source == _ProductImageSource.gallery) {
        final images = await imagePicker.pickMultiImage(
          imageQuality: 88,
          maxWidth: 2200,
          maxHeight: 2200,
        );
        await _savePickedImages(images);
        return;
      }

      final image = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      if (image != null) {
        await _savePickedImages([image]);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Product image selection failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) {
        return;
      }
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Image Selection Failed'.tr,
        messages: ['Unable to add product images. Please try again.'.tr],
        duration: 4,
      );
    }
  }

  Future<void> _savePickedImages(List<XFile> images) async {
    if (images.isEmpty) {
      return;
    }

    final savedPaths = <String>[];
    try {
      for (final image in images) {
        savedPaths.add(await ProductImageStorage.savePickedImage(image));
      }
    } catch (_) {
      for (final imagePath in savedPaths) {
        await ProductImageStorage.deleteImage(imagePath);
      }
      rethrow;
    }

    if (!mounted) {
      for (final imagePath in savedPaths) {
        await ProductImageStorage.deleteImage(imagePath);
      }
      return;
    }

    setState(() {
      productImagePaths.addAll(savedPaths);
      sessionAddedImagePaths.addAll(savedPaths);
    });
  }

  Future<void> _removeImageAt(int index) async {
    final confirmed = await confirmRemoveProductImage(context);
    if (!confirmed || !mounted) {
      return;
    }
    _removeImagePath(productImagePaths[index]);
  }

  void _removeImagePath(String imagePath) {
    if (!mounted) {
      return;
    }
    setState(() => productImagePaths.remove(imagePath));
    _deleteUnsavedImageIfNeeded(imagePath);
  }

  void _deleteUnsavedImageIfNeeded(String imagePath) {
    if (!sessionAddedImagePaths.remove(imagePath)) {
      return;
    }
    ProductImageStorage.deleteImage(imagePath);
  }

  void _reorderImage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final imagePath = productImagePaths.removeAt(oldIndex);
      productImagePaths.insert(newIndex, imagePath);
    });
  }

  void _openImagePreview(int initialIndex) {
    if (productImagePaths.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductImagePreviewView(
          imagePaths: List<String>.from(productImagePaths),
          initialIndex: initialIndex,
          onDelete: _removeImagePath,
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!didSave) {
      for (final imagePath in sessionAddedImagePaths) {
        ProductImageStorage.deleteImage(imagePath);
      }
    }
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
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            size: 20,
                          ),
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
          _ProductImageSection(
            imagePaths: productImagePaths,
            onAdd: _openImageSourcePicker,
            onRemove: _removeImageAt,
            onPreview: _openImagePreview,
            onReorder: _reorderImage,
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
              final salePrice =
                  double.tryParse(priceController.text.trim()) ?? 0;
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
                errors.add(
                  'SKU/code should be at least 3 characters if provided.'.tr,
                );
              }
              if (salePrice > 999999999) {
                errors.add(
                  'Price looks too high. Please recheck the amount.'.tr,
                );
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
                  imagePaths: List<String>.from(productImagePaths),
                  createdAt: existing?.createdAt ?? DateTime.now(),
                  updatedAt: existing?.updatedAt ?? DateTime.now(),
                ),
              );
              didSave = true;
              Get.back();
            },
            child: Text('Save Product'.tr),
          ),
        ],
      ),
    );
  }
}

enum _ProductImageSource { gallery, camera }

class _ProductImageSection extends StatelessWidget {
  const _ProductImageSection({
    required this.imagePaths,
    required this.onAdd,
    required this.onRemove,
    required this.onPreview,
    required this.onReorder,
  });

  final List<String> imagePaths;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPreview;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : AppColors.inkStrong;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product Images'.tr,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _AddImageButton(onPressed: onAdd),
            ],
          ),
          if (imagePaths.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 124,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                proxyDecorator: (child, index, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Transform.scale(
                    scale: 1 + (animation.value * 0.04),
                    child: Material(color: Colors.transparent, child: child),
                  ),
                  child: child,
                ),
                itemCount: imagePaths.length,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  return Padding(
                    key: ValueKey(imagePaths[index]),
                    padding: EdgeInsets.only(
                      right: index == imagePaths.length - 1 ? 0 : 12,
                    ),
                    child: ReorderableDelayedDragStartListener(
                      index: index,
                      child: _ProductImageThumbnail(
                        imagePath: imagePaths[index],
                        onTap: () => onPreview(index),
                        onRemove: () => onRemove(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddImageButton extends StatelessWidget {
  const _AddImageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.26)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.surface,
        ),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class _ProductImageThumbnail extends StatelessWidget {
  const _ProductImageThumbnail({
    required this.imagePath,
    required this.onTap,
    required this.onRemove,
  });

  final String imagePath;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brandSecondary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.24 : 0.08,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: isDark ? Colors.white70 : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 7,
            right: 7,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.88),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.20 : 0.10,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white70 : AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
