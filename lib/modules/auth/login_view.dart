import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/text_helper.dart';
import '../../core/widgets/app_loading_overlay.dart';
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
  void initState() {
    super.initState();
    final session = Get.find<SessionManager>();
    rememberMe = session.rememberLogin;
    if (rememberMe) {
      phoneController.text = session.rememberedLogin;
    }
  }

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
                'Sign in with your email address or mobile number to continue to KistBook.'
                    .tr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : AppColors.inkSoft,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 36),
              AuthTextField(
                label: 'Email or Mobile Number'.tr,
                hint: 'owner@example.com or 03001234567',
                controller: phoneController,
                prefixIcon: Icons.account_circle_outlined,
                keyboardType: TextInputType.emailAddress,
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
    final login = phoneController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    final errors = <String>[];

    if (login.isEmpty) {
      errors.add('Email or mobile number is required.'.tr);
    } else if (RegExp(r'^\d+$').hasMatch(login)) {
      if (TextHelper.digitsOnly(login).length != 11) {
        errors.add('Mobile number must be 11 digits.'.tr);
      }
    } else if (!GetUtils.isEmail(login)) {
      errors.add('Enter a valid email address or mobile number.'.tr);
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

    final user = await AppLoadingOverlay.run(
      context,
      message: 'Logging in...',
      task: () => controller.login(
        login: login,
        password: password,
        rememberMe: rememberMe,
      ),
    );
    if (!mounted) {
      return;
    }
    if (user == null) {
      final message = controller.errorMessage.value.trim();
      showBannerAlert(
        type: BannerStyle.error,
        title: 'Login Failed'.tr,
        messages: message.isEmpty
            ? ['Invalid email, mobile number, or password.'.tr]
            : message.split('\n'),
      );
    }
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
