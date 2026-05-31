import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/banner_alert.dart';
import '../../modules/auth/auth_controller.dart';
import '../../services/session_manager.dart';
import 'auth_form_widgets.dart';

class OwnerSignupView extends StatefulWidget {
  const OwnerSignupView({super.key});

  @override
  State<OwnerSignupView> createState() => _OwnerSignupViewState();
}

class _OwnerSignupViewState extends State<OwnerSignupView> {
  final controller = Get.find<AuthController>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AuthPageScaffold(
      showBackButton: true,
      child: GetBuilder<AuthController>(
        builder: (logic) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthBrandHeader(),
              const SizedBox(height: 56),
              Text(
                'Create Owner Account'.tr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark ? Colors.white : AppColors.inkStrong,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create the first owner account. This user will have full access and can assign other users later.'
                    .tr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : AppColors.inkSoft,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                label: 'First Name'.tr,
                hint: 'Enter first name'.tr,
                controller: firstNameController,
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              AuthTextField(
                label: 'Last Name'.tr,
                hint: 'Enter last name'.tr,
                controller: lastNameController,
                prefixIcon: Icons.group_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              AuthTextField(
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
              AuthPasswordField(
                label: 'Password'.tr,
                hint: 'Enter password'.tr,
                controller: passwordController,
                obscureText: obscurePassword,
                onToggleObscure: () {
                  setState(() => obscurePassword = !obscurePassword);
                },
              ),
              AuthPasswordField(
                label: 'Confirm Password'.tr,
                hint: 'Re-enter password'.tr,
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                onToggleObscure: () {
                  setState(
                    () => obscureConfirmPassword = !obscureConfirmPassword,
                  );
                },
              ),
              const SizedBox(height: 22),
              AuthPrimaryButton(
                label: 'Create Owner'.tr,
                icon: Icons.person_add_alt_1_rounded,
                isLoading: logic.isSubmitting,
                onPressed: _submitRegister,
              ),
              const SizedBox(height: 44),
              const AuthLegalCopy(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitRegister() async {
    final firstName = TextHelper.toTitleCase(firstNameController.text);
    final lastName = TextHelper.toTitleCase(lastNameController.text);
    final phone = TextHelper.digitsOnly(phoneController.text);
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
    if (password.isEmpty) {
      errors.add('Password is required.'.tr);
    }
    if (password.length < 6) {
      errors.add('Password should be at least 6 characters.'.tr);
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

    final user = await controller.registerOwner(
      phone: phone,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    if (!mounted) {
      return;
    }
    if (user == null) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Registration Failed'.tr,
        messages: [
          controller.hasOwner
              ? 'Owner account already exists. Please login or ask the owner to add users.'
                    .tr
              : 'This phone number is already in use.'.tr,
        ],
      );
      return;
    }
    Get.offAllNamed(Get.find<SessionManager>().homeRoute);
  }
}
