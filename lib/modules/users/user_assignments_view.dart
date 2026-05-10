import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_enums.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/banner_alert.dart';
import '../../data/models/local_user_model.dart';
import 'user_controller.dart';

class UserAssignmentsView extends StatefulWidget {
  const UserAssignmentsView({super.key});

  @override
  State<UserAssignmentsView> createState() => _UserAssignmentsViewState();
}

class _UserAssignmentsViewState extends State<UserAssignmentsView> {
  final controller = Get.find<UserController>();
  late final LocalUserModel user;

  @override
  void initState() {
    super.initState();
    user = Get.arguments as LocalUserModel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadAssignmentData(user: user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Access'.tr),
      ),
      body: GetBuilder<UserController>(
        builder: (logic) {
          if (logic.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          user.role == UserRole.admin
                              ? Icons.admin_panel_settings_outlined
                              : Icons.storefront_outlined,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${user.role.label} • ${user.phone}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ...[
                ...logic.customers.map((customer) {
                  final customerId = customer.id;
                  final customerPlans = customerId == null
                      ? const []
                      : logic.plansForCustomer(customerId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            customer.phone.isEmpty ? customer.address : customer.phone,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: customerId != null &&
                                      logic.assignedCustomerIds.contains(customerId),
                                  title: Text('Assign customer'.tr),
                                  subtitle: Text(
                                    'This user will see this customer in customer listing.'.tr,
                                  ),
                                  onChanged: customerId == null
                                      ? null
                                      : (_) => logic.toggleCustomer(customerId),
                                ),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: customerId != null &&
                                      logic.isAllPlansAssignedForCustomer(customerId),
                                  title: Text('Assign complete plans'.tr),
                                  subtitle: Text(
                                    'Give access to all plans of this customer.'.tr,
                                  ),
                                  onChanged: customerId == null || customerPlans.isEmpty
                                      ? null
                                      : (_) => logic.toggleAllPlansForCustomer(customerId),
                                ),
                              ],
                            ),
                          ),
                          if (customerPlans.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Specific Plans'.tr,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...customerPlans.map(
                              (plan) => CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: logic.assignedPlanIds.contains(plan.id),
                                title: Text(plan.itemName),
                                subtitle: Text(
                                  'Installment ${plan.installmentAmount.toStringAsFixed(0)} • Every ${plan.frequencyDays} days',
                                ),
                                onChanged: plan.id == null
                                    ? null
                                    : (_) => logic.togglePlan(plan.id!),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (user.role != UserRole.owner &&
                      controller.assignedCustomerIds.isEmpty &&
                      controller.assignedPlanIds.isEmpty) {
                    showBannerAlert(
                      type: BannerStyle.error,
                      title: 'Validation Errors'.tr,
                      messages: ['Assign at least one customer or one plan.'.tr],
                    );
                    return;
                  }
                  await controller.saveAssignmentsForUser(user);
                  if (!mounted) {
                    return;
                  }
                  Get.back();
                },
                child: Text('Save Assignments'.tr),
              ),
            ],
          );
        },
      ),
    );
  }
}
