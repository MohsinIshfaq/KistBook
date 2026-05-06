import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import 'product_controller.dart';

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
                children: [
                  _detailRow(
                    context,
                    icon: Icons.business_outlined,
                    label: 'Brand'.tr,
                    value: product.brandName.isEmpty ? 'Not provided'.tr : product.brandName,
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    context,
                    icon: Icons.qr_code_2_outlined,
                    label: 'SKU'.tr,
                    value: product.sku.isEmpty ? 'Not provided'.tr : product.sku,
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
                    value: product.notes.isEmpty ? 'Not provided'.tr : product.notes,
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
                                  ? AppColors.brandAccent.withValues(alpha: 0.16)
                                  : AppColors.brandAccent.withValues(alpha: 0.10),
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
                                          'amount': CurrencyHelper.pkr
                                              .format(entry.previousPrice!),
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
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.92),
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
