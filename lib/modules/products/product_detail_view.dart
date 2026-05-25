import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import 'product_controller.dart';
import 'product_image_preview_view.dart';

class ProductDetailView extends StatefulWidget {
  const ProductDetailView({super.key});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final controller = Get.find<ProductController>();
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      controller.loadProduct(Get.arguments as int);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Product Detail'.tr)),
      body: GetBuilder<ProductController>(
        builder: (logic) {
          if (logic.isLoading || logic.product == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final product = logic.product!;
          final imagePaths = _availableImagePaths(product.imagePaths);
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _summaryCard(
                context,
                title: product.name,
                subtitle: 'Product profile and latest pricing details'.tr,
                leadingIcon: Icons.inventory_2_outlined,
                accentColor: AppColors.brandAccent,
                imagePaths: imagePaths,
                children: [
                  _categorySection(context, categories: product.categories),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.business_outlined,
                    label: 'Brand'.tr,
                    value: product.brandName.isEmpty
                        ? 'Not provided'.tr
                        : product.brandName,
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.qr_code_2_outlined,
                    label: 'SKU'.tr,
                    value: product.sku.isEmpty
                        ? 'Not provided'.tr
                        : product.sku,
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.payments_outlined,
                    label: 'Current price'.tr,
                    value: CurrencyHelper.pkr.format(product.salePrice),
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.update_outlined,
                    label: 'Last updated'.tr,
                    value: dateFormat.format(product.updatedAt),
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.edit_note_outlined,
                    label: 'Notes'.tr,
                    value: product.notes.isEmpty
                        ? 'Not provided'.tr
                        : product.notes,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Price History'.tr,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (logic.priceHistory.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No price history found.'.tr,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ...logic.priceHistory.map(
                  (entry) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.brandAccent.withValues(
                                      alpha: 0.16,
                                    )
                                  : AppColors.brandAccent.withValues(
                                      alpha: 0.10,
                                    ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.timeline_rounded,
                              color: AppColors.brandAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormat.format(entry.changedAt),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.previousPrice == null
                                      ? 'Initial price recorded'.tr
                                      : 'Updated from @amount'.trParams({
                                          'amount': CurrencyHelper.pkr.format(
                                            entry.previousPrice!,
                                          ),
                                        }),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            CurrencyHelper.pkr.format(entry.newPrice),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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

  List<String> _availableImagePaths(List<String> imagePaths) {
    return imagePaths
        .map((imagePath) => imagePath.trim())
        .where((imagePath) => imagePath.isNotEmpty)
        .where((imagePath) => File(imagePath).existsSync())
        .toList();
  }

  Widget _categorySection(
    BuildContext context, {
    required List<String> categories,
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
          child: Icon(
            Icons.category_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categories'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map(
                      (category) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.18
                                : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
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
    required List<String> imagePaths,
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
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 18),
              _ProductDetailImageCarousel(imagePaths: imagePaths),
            ],
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

class _ProductDetailImageCarousel extends StatefulWidget {
  const _ProductDetailImageCarousel({required this.imagePaths});

  final List<String> imagePaths;

  @override
  State<_ProductDetailImageCarousel> createState() =>
      _ProductDetailImageCarouselState();
}

class _ProductDetailImageCarouselState
    extends State<_ProductDetailImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _ProductDetailImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex >= widget.imagePaths.length) {
      _currentIndex = 0;
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openPreview(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductImagePreviewView(
          imagePaths: widget.imagePaths,
          initialIndex: index,
        ),
      ),
    );
  }

  void _selectImage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.border;
    final previewBackground = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : AppColors.surfaceMuted;

    return Column(
      children: [
        Container(
          height: 238,
          decoration: BoxDecoration(
            color: previewBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imagePaths.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openPreview(index),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Image.file(
                    File(widget.imagePaths[index]),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.image_not_supported_outlined,
                      color: isDark ? Colors.white70 : AppColors.inkMuted,
                      size: 42,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _CarouselDots(
          count: widget.imagePaths.length,
          currentIndex: _currentIndex,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.imagePaths.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final selected = index == _currentIndex;
              return GestureDetector(
                onTap: () => _selectImage(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 74,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? theme.colorScheme.primary : borderColor,
                      width: selected ? 1.7 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.05,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.file(
                      File(widget.imagePaths[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image_not_supported_outlined,
                        color: isDark ? Colors.white70 : AppColors.inkMuted,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) {
      return const SizedBox(height: 8);
    }

    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 8 : 7,
          height: selected ? 8 : 7,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : AppColors.inkMuted.withValues(alpha: 0.38),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
