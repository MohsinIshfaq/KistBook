import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/banner_alert.dart';
import '../../core/widgets/app_text_field.dart';
import '../../modules/auth/auth_controller.dart';
import '../../services/session_manager.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1320) : AppColors.canvas,
      body: SafeArea(
        child: GetBuilder<AuthController>(
          builder: (logic) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF0F172A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.lock_open_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            logic.hasUsers ? 'Welcome Back'.tr : 'Create Owner Account'.tr,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            logic.hasUsers
                                ? 'Sign in with your phone number and password to continue to KistBook.'
                                    .tr
                                : 'Create the first owner account. This user will have full access and can assign other users later.'
                                    .tr,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                          const SizedBox(height: 22),
                          if (!logic.hasUsers) ...[
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
                          ],
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
                                      color: isDark ? Colors.white : AppColors.inkStrong,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextField(
                                  controller: passwordController,
                                  obscureText: obscurePassword,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.inkStrong,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                          if (!logic.hasUsers)
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
                                        color: isDark ? Colors.white : AppColors.inkStrong,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextField(
                                    controller: confirmPasswordController,
                                    obscureText: obscureConfirmPassword,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppColors.inkStrong,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Re-enter password'.tr,
                                      prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            obscureConfirmPassword = !obscureConfirmPassword;
                                          });
                                        },
                                        icon: Icon(
                                          obscureConfirmPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          FilledButton(
                            onPressed: logic.isSubmitting
                                ? null
                                : (logic.hasUsers ? _submitLogin : _submitRegister),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: logic.isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text((logic.hasUsers ? 'Login' : 'Create Owner').tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    final phone = TextHelper.digitsOnly(phoneController.text);
    final password = passwordController.text.trim();
    final errors = <String>[];

    if (phone.isEmpty) {
      errors.add('Phone number is required.'.tr);
    }
    if (phone.length != 11) {
      errors.add('Phone number must be 11 digits.'.tr);
    }
    if (password.isEmpty) {
      errors.add('Password is required.'.tr);
    }

    if (errors.isNotEmpty) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Validation Errors'.tr,
        messages: errors,
      );
      return;
    }

    final user = await controller.login(phone: phone, password: password);
    if (!mounted) {
      return;
    }
    if (user == null) {
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Login Failed'.tr,
        messages: ['Invalid phone number or password.'.tr],
      );
      return;
    }
    Get.offAllNamed(Get.find<SessionManager>().homeRoute);
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
        messages: ['This phone number is already in use.'.tr],
      );
      return;
    }
    Get.offAllNamed(Get.find<SessionManager>().homeRoute);
  }
}
