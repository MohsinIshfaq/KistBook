import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/banner_alert.dart';
import 'auth_controller.dart';
import 'auth_form_widgets.dart';

class OwnerSignupView extends StatefulWidget {
  const OwnerSignupView({super.key});

  @override
  State<OwnerSignupView> createState() => _OwnerSignupViewState();
}

class _OwnerSignupViewState extends State<OwnerSignupView> {
  final controller = Get.find<AuthController>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final companyNameController = TextEditingController();
  final companyPhoneController = TextEditingController();
  final companyAddressController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    companyNameController.dispose();
    companyPhoneController.dispose();
    companyAddressController.dispose();
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
              const SizedBox(height: 48),
              Text(
                'Create Owner Account'.tr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark ? Colors.white : AppColors.inkStrong,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create your company and its owner account. You can add salesmen from inside the app after signup.'
                    .tr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : AppColors.inkSoft,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                label: 'Owner Name'.tr,
                hint: 'Enter full name'.tr,
                controller: nameController,
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              AuthTextField(
                label: 'Email Address'.tr,
                hint: 'owner@example.com',
                controller: emailController,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              AuthTextField(
                label: 'Mobile Number'.tr,
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
              const SizedBox(height: 10),
              Text(
                'Company Details'.tr,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white : AppColors.inkStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Company Name'.tr,
                hint: 'Enter company name'.tr,
                controller: companyNameController,
                prefixIcon: Icons.business_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              AuthTextField(
                label: 'Company Phone (Optional)'.tr,
                hint: '03001234567',
                controller: companyPhoneController,
                prefixIcon: Icons.phone_in_talk_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ),
              AuthTextField(
                label: 'Company Address (Optional)'.tr,
                hint: 'Enter company address'.tr,
                controller: companyAddressController,
                prefixIcon: Icons.location_on_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 22),
              AuthPrimaryButton(
                label: 'Create Company Account'.tr,
                icon: Icons.person_add_alt_1_rounded,
                isLoading: logic.isSignupLoading.value,
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
    final name = TextHelper.toTitleCase(nameController.text);
    final email = emailController.text.trim().toLowerCase();
    final phone = TextHelper.digitsOnly(phoneController.text);
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final companyName = TextHelper.toTitleCase(companyNameController.text);
    final companyPhone = TextHelper.digitsOnly(companyPhoneController.text);
    final companyAddress = companyAddressController.text.trim();
    final errors = <String>[];

    if (name.isEmpty) errors.add('Owner name is required.'.tr);
    if (email.isEmpty) {
      errors.add('Email address is required.'.tr);
    } else if (!GetUtils.isEmail(email)) {
      errors.add('Enter a valid email address.'.tr);
    }
    if (phone.length != 11) {
      errors.add('Mobile number must be 11 digits.'.tr);
    }
    if (password.length < 8) {
      errors.add('Password should be at least 8 characters.'.tr);
    }
    if (password != confirmPassword) {
      errors.add('Password and confirm password must match.'.tr);
    }
    if (companyName.isEmpty) errors.add('Company name is required.'.tr);
    if (companyPhone.isNotEmpty && companyPhone.length != 11) {
      errors.add('Company phone must be 11 digits when provided.'.tr);
    }

    if (errors.isNotEmpty) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Validation Errors'.tr,
        messages: errors,
      );
      return;
    }

    final user = await AppLoadingOverlay.run(
      context,
      message: 'Creating company account...',
      task: () => controller.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: confirmPassword,
        companyName: companyName,
        companyPhone: companyPhone.isEmpty ? null : companyPhone,
        companyAddress: companyAddress.isEmpty ? null : companyAddress,
      ),
    );
    if (!mounted || user != null) return;

    final message = controller.errorMessage.value.trim();
    showBannerAlert(
      type: BannerStyle.error,
      title: 'Registration Failed'.tr,
      messages: message.isEmpty
          ? ['Unable to create your account. Please try again.'.tr]
          : message.split('\n'),
    );
  }
}
