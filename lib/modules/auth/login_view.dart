import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/banner_alert.dart';
import '../../modules/auth/auth_controller.dart';
import '../../services/session_manager.dart';
import 'auth_form_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final controller = Get.find<AuthController>();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool rememberMe = true;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AuthPageScaffold(
      child: GetBuilder<AuthController>(
        builder: (logic) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthBrandHeader(),
              const SizedBox(height: 58),
              Text(
                'Welcome Back'.tr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark ? Colors.white : AppColors.inkStrong,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in with your phone number and password to continue to KistBook.'
                    .tr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : AppColors.inkSoft,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
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
              const SizedBox(height: 2),
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: rememberMe,
                      activeColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (value) {
                        setState(() => rememberMe = value ?? true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remember me'.tr,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showBannerAlert(
                        type: BannerStyle.warning,
                        title: 'Forgot Password?'.tr,
                        messages: [
                          'Please contact the owner to reset your password.'.tr,
                        ],
                      );
                    },
                    child: Text('Forgot Password?'.tr),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              AuthPrimaryButton(
                label: 'Login'.tr,
                icon: Icons.login_rounded,
                isLoading: logic.isSubmitting,
                onPressed: _submitLogin,
              ),
              const SizedBox(height: 30),
              _DividerLabel(label: 'or'.tr),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: logic.isSubmitting
                      ? null
                      : () => Get.toNamed(AppRoutes.ownerSignup),
                  icon: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Text(
                      'Create Owner Account'.tr,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 44),
              const AuthLegalCopy(),
            ],
          );
        },
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
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white24 : AppColors.border;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
