import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/currency_helper.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/sticky_search_header.dart';
import 'product_controller.dart';

class ProductListView extends StatefulWidget {
  const ProductListView({super.key});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark
        ? AppColors.brandSecondary
        : AppColors.surface;
    final primaryText = isDark ? Colors.white : AppColors.inkStrong;
    final secondaryText = isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft;
    final mutedText = isDark ? const Color(0xFF98A2B3) : AppColors.inkMuted;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.border;
    final menuIconColor = isDark ? Colors.white : AppColors.inkStrong;

    return AppShell(
      title: 'Products'.tr,
      currentRoute: AppRoutes.products,
      centerTitle: true,
      showSubtitle: false,
      showSettingsAction: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.productForm),
        icon: const Icon(Icons.add_box_outlined),
        label: Text('Add Product'.tr),
      ),
      body: GetBuilder<ProductController>(
        builder: (logic) {
          final filteredProducts = logic.filteredProducts;
          if (searchController.text != logic.searchQuery) {
            searchController.value = searchController.value.copyWith(
              text: logic.searchQuery,
              selection: TextSelection.collapsed(
                offset: logic.searchQuery.length,
              ),
              composing: TextRange.empty,
            );
          }

          return Column(
            children: [
              StickySearchHeader(
                controller: searchController,
                hintText: 'Search by name, brand or SKU'.tr,
                onChanged: logic.setSearchQuery,
                showClear: logic.searchQuery.isNotEmpty,
                onClear: () {
                  searchController.clear();
                  logic.clearSearch();
                },
              ),
              Expanded(
                child: logic.isLoading && logic.products.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                        children: [
                          if (filteredProducts.isEmpty)
                            _EmptyProductState(
                              cardBackground: cardBackground,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                            )
                          else
                            ...List.generate(filteredProducts.length, (index) {
                              final product = filteredProducts[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == filteredProducts.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: Card(
                                  color: cardBackground,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(28),
                                    onTap: () => Get.toNamed(
                                      AppRoutes.productDetail,
                                      arguments: product.id,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: AppColors.info,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                                child: const Icon(
                                                  Icons.inventory_2_outlined,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.name,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: primaryText,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      product.brandName.isEmpty
                                                          ? product.sku
                                                          : product.brandName,
                                                      style: const TextStyle(
                                                        color: AppColors
                                                            .brandAccent,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                color: AppColors.surface,
                                                iconColor: menuIconColor,
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    Get.toNamed(
                                                      AppRoutes.productForm,
                                                      arguments: product,
                                                    );
                                                  }
                                                  if (value == 'delete') {
                                                    await logic.deleteProduct(
                                                      product.id!,
                                                    );
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('Edit'.tr),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete'.tr),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              ...product.categories.map(
                                                (category) => _metaChip(
                                                  label: category,
                                                  textColor: AppColors.info,
                                                  backgroundColor: AppColors
                                                      .info
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.18
                                                            : 0.10,
                                                      ),
                                                ),
                                              ),
                                              if (product.sku.isNotEmpty)
                                                _metaChip(
                                                  label: 'SKU: ${product.sku}',
                                                  textColor: secondaryText,
                                                  backgroundColor: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.06,
                                                        )
                                                      : AppColors.surfaceMuted,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Divider(
                                            color: dividerColor,
                                            height: 1,
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  CurrencyHelper.pkr.format(
                                                    product.salePrice,
                                                  ),
                                                  style: TextStyle(
                                                    color: secondaryText,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (product.notes.isNotEmpty)
                                                Expanded(
                                                  child: Text(
                                                    product.notes,
                                                    style: TextStyle(
                                                      color: mutedText,
                                                      fontSize: 12,
                                                    ),
                                                    textAlign: TextAlign.end,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metaChip({
    required String label,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyProductState extends StatelessWidget {
  const _EmptyProductState({
    required this.cardBackground,
    required this.primaryText,
    required this.secondaryText,
  });

  final Color cardBackground;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: secondaryText, size: 32),
            const SizedBox(height: 12),
            Text(
              'No products found'.tr,
              style: TextStyle(
                color: primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another product search term.'.tr,
              style: TextStyle(color: secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
