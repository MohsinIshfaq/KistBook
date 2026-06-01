import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/api_services.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/app_loading_overlay.dart';
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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
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
      emailController.text = arg.email;
      passwordController.text = arg.password;
      confirmPasswordController.text = arg.password;
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
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
                label: 'Email Address'.tr,
                hint: 'salesman@example.com',
                controller: emailController,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
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
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                        ),
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
                        'Confirm Password'.tr,
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
                      controller: confirmPasswordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Re-enter password'.tr,
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
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
                    const Chip(label: Text('Salesman')),
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

  Future<void> _submit() async {
    final firstName = TextHelper.toTitleCase(firstNameController.text);
    final lastName = TextHelper.toTitleCase(lastNameController.text);
    final phone = TextHelper.digitsOnly(phoneController.text);
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
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
    if (!GetUtils.isEmail(email)) {
      errors.add('Enter a valid email address.'.tr);
    }
    if (password.length < 8) {
      errors.add('Password should be at least 8 characters.'.tr);
    }
    if (password != confirmPassword) {
      errors.add('Password and confirm password must match.'.tr);
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
      await AppLoadingOverlay.run(
        context,
        message: existing == null ? 'Creating salesman...' : 'Saving user...',
        task: () => controller.saveUser(
          existing: existing,
          phone: phone,
          email: email,
          password: password,
          passwordConfirmation: confirmPassword,
          firstName: firstName,
          lastName: lastName,
        ),
      );
    } on StateError catch (error) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Validation Errors'.tr,
        messages: [error.message.tr],
      );
      return;
    } on ApiException catch (error) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Unable to Save User'.tr,
        messages: error.displayMessages,
      );
      return;
    }
    if (!mounted) {
      return;
    }
    Get.back();
  }
}
