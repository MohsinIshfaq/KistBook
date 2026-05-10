import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_enums.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/banner_alert.dart';
import '../../data/models/local_user_model.dart';
import 'user_controller.dart';

class UserFormView extends StatefulWidget {
  const UserFormView({super.key});

  @override
  State<UserFormView> createState() => _UserFormViewState();
}

class _UserFormViewState extends State<UserFormView> {
  final controller = Get.find<UserController>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  UserRole selectedRole = UserRole.salesMan;
  bool obscurePassword = true;
  LocalUserModel? existing;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is LocalUserModel) {
      existing = arg;
      firstNameController.text = arg.firstName;
      lastNameController.text = arg.lastName;
      phoneController.text = arg.phone;
      passwordController.text = arg.password;
      selectedRole = arg.role;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadFormData(user: existing);
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((existing == null ? 'Add User' : 'Edit User').tr),
      ),
      body: GetBuilder<UserController>(
        builder: (logic) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppTextField(
                label: 'First Name'.tr,
                hint: 'Enter first name'.tr,
                controller: firstNameController,
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              AppTextField(
                label: 'Last Name'.tr,
                hint: 'Enter last name'.tr,
                controller: lastNameController,
                prefixIcon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              AppTextField(
                label: 'Phone Number'.tr,
                hint: '03001234567',
                controller: phoneController,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: Text(
                        'Password'.tr,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF14213D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Enter password'.tr,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: Text(
                        'Role'.tr,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF14213D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _roleChip(UserRole.admin),
                        _roleChip(UserRole.salesMan),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: logic.isLoading ? null : _submit,
                child: Text('Save User'.tr),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _roleChip(UserRole role) {
    final selected = selectedRole == role;
    return ChoiceChip(
      label: Text(role.label),
      selected: selected,
      onSelected: (_) {
        setState(() => selectedRole = role);
      },
    );
  }

  Future<void> _submit() async {
    final firstName = TextHelper.toTitleCase(firstNameController.text);
    final lastName = TextHelper.toTitleCase(lastNameController.text);
    final phone = TextHelper.digitsOnly(phoneController.text);
    final password = passwordController.text.trim();
    final errors = <String>[];

    if (firstName.isEmpty) {
      errors.add('First name is required.'.tr);
    }
    if (lastName.isEmpty) {
      errors.add('Last name is required.'.tr);
    }
    if (phone.length != 11) {
      errors.add('Phone number must be 11 digits.'.tr);
    }
    if (password.length < 6) {
      errors.add('Password should be at least 6 characters.'.tr);
    }

    if (errors.isNotEmpty) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Validation Errors'.tr,
        messages: errors,
      );
      return;
    }

    try {
      await controller.saveUser(
        existing: existing,
        phone: phone,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: selectedRole,
      );
    } on StateError {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Validation Errors'.tr,
        messages: ['Phone number already exists.'.tr],
      );
      return;
    }
    if (!mounted) {
      return;
    }
    Get.back();
  }
}
