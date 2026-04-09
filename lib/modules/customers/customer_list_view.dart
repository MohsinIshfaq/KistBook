import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/app_shell.dart';
import 'customer_controller.dart';

class CustomerListView extends GetView<CustomerController> {
  const CustomerListView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? AppColors.brandSecondary : AppColors.surface;
    final primaryText = isDark ? Colors.white : AppColors.inkStrong;
    final secondaryText = isDark ? const Color(0xFFD0D5DD) : AppColors.inkSoft;
    final mutedText = isDark ? const Color(0xFF98A2B3) : AppColors.inkMuted;
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.border;
    final menuIconColor = isDark ? Colors.white : AppColors.inkStrong;

    return AppShell(
      title: 'Customers',
      currentRoute: AppRoutes.customers,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.customerForm),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Customer'),
      ),
      body: GetBuilder<CustomerController>(
        builder: (logic) {
          if (logic.isLoading && logic.customers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: logic.customers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final customer = logic.customers[index];
              return Card(
                color: cardBackground,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => Get.toNamed(
                    AppRoutes.customerDetail,
                    arguments: customer.id,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  customer.name.isEmpty ? '?' : customer.name[0],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    customer.reference.isEmpty
                                        ? 'Direct Customer'
                                        : customer.reference,
                                    style: const TextStyle(
                                      color: AppColors.brandAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
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
                                  Get.toNamed(AppRoutes.customerForm, arguments: customer);
                                }
                                if (value == 'delete') {
                                  await logic.deleteCustomer(customer.id!);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                                overflow: TextOverflow.ellipsis,
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
                                overflow: TextOverflow.ellipsis,
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
              );
            },
          );
        },
      ),
    );
  }

}
