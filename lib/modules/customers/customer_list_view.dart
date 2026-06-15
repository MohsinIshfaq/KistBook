import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/sticky_search_header.dart';
import '../../services/session_manager.dart';
import 'customer_controller.dart';

class CustomerListView extends StatefulWidget {
  const CustomerListView({super.key});

  @override
  State<CustomerListView> createState() => _CustomerListViewState();
}

class _CustomerListViewState extends State<CustomerListView> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    final canManageCustomers = session.role == UserRole.owner;
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
      title: 'Customers'.tr,
      currentRoute: AppRoutes.customers,
      centerTitle: true,
      showSubtitle: false,
      showSettingsAction: false,
      floatingActionButton: canManageCustomers
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.customerForm),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Add Customer'.tr),
            )
          : null,
      body: GetBuilder<CustomerController>(
        builder: (logic) {
          final filteredCustomers = logic.filteredCustomers;
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
                hintText: 'Search by card number or customer name'.tr,
                onChanged: logic.setSearchQuery,
                showClear: logic.searchQuery.isNotEmpty,
                onClear: () {
                  searchController.clear();
                  logic.clearSearch();
                },
              ),
              Expanded(
                child: logic.isLoading && logic.customers.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                        children: [
                          if (filteredCustomers.isEmpty)
                            _EmptyCustomerState(
                              cardBackground: cardBackground,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                            )
                          else
                            ...List.generate(filteredCustomers.length, (index) {
                              final customer = filteredCustomers[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == filteredCustomers.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: Card(
                                  color: cardBackground,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(28),
                                    onTap: canManageCustomers
                                        ? () => Get.toNamed(
                                            AppRoutes.customerDetail,
                                            arguments: customer.id,
                                          )
                                        : null,
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
                                                  color: AppColors.success,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    customer.name.isEmpty
                                                        ? '?'
                                                        : customer.name[0],
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (customer
                                                        .cardNumber
                                                        .isNotEmpty) ...[
                                                      Text(
                                                        customer.cardNumber,
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .brandAccent,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                    ],
                                                    Text(
                                                      customer.name,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: primaryText,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      customer.reference.isEmpty
                                                          ? 'Direct Customer'.tr
                                                          : customer.reference,
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
                                              if (canManageCustomers)
                                                PopupMenuButton<String>(
                                                  color: AppColors.surface,
                                                  iconColor: menuIconColor,
                                                  onSelected: (value) async {
                                                    if (value == 'edit') {
                                                      Get.toNamed(
                                                        AppRoutes.customerForm,
                                                        arguments: customer,
                                                      );
                                                    }
                                                    if (value == 'delete') {
                                                      await logic
                                                          .deleteCustomer(
                                                            customer.id!,
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
                                          Divider(
                                            color: dividerColor,
                                            height: 1,
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  customer.phone,
                                                  style: TextStyle(
                                                    color: secondaryText,
                                                    fontSize: 13,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  customer.cnic,
                                                  style: TextStyle(
                                                    color: secondaryText,
                                                    fontSize: 13,
                                                  ),
                                                  textAlign: TextAlign.end,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (customer.address.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              customer.address,
                                              style: TextStyle(
                                                color: mutedText,
                                                fontSize: 12,
                                                height: 1.35,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
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
}

class _EmptyCustomerState extends StatelessWidget {
  const _EmptyCustomerState({
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
              'No customers found'.tr,
              style: TextStyle(
                color: primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another card number or customer name.'.tr,
              style: TextStyle(color: secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
