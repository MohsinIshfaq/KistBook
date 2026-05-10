import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/app_shell.dart';
import '../../services/session_manager.dart';
import 'user_controller.dart';

class UserListView extends GetView<UserController> {
  const UserListView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    final isOwner = session.role == UserRole.owner;

    return AppShell(
      title: 'Users'.tr,
      currentRoute: AppRoutes.users,
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.userForm),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text('Add User'.tr),
            )
          : null,
      body: GetBuilder<UserController>(
        builder: (logic) {
          if (logic.isLoading && logic.users.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!isOwner) {
            return Center(
              child: Text('Only owner can manage users.'.tr),
            );
          }
          if (logic.users.isEmpty) {
            return Center(
              child: Text('No users added yet.'.tr),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: logic.users.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = logic.users[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await Get.toNamed(AppRoutes.userAssignments, arguments: user);
                    controller.loadUsers();
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    leading: Container(
                      width: 46,
                      height: 46,
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
                    title: Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    subtitle: Text('${user.role.label} • ${user.phone}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'assign') {
                          await Get.toNamed(AppRoutes.userAssignments, arguments: user);
                          controller.loadUsers();
                        }
                        if (value == 'edit') {
                          await Get.toNamed(AppRoutes.userForm, arguments: user);
                          controller.loadUsers();
                        }
                        if (value == 'delete') {
                          await logic.deleteUser(user.id!);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'assign', child: Text('Assign Access'.tr)),
                        PopupMenuItem(value: 'edit', child: Text('Edit'.tr)),
                        PopupMenuItem(value: 'delete', child: Text('Delete'.tr)),
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
