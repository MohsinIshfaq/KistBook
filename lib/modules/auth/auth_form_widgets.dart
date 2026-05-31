import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.child,
    this.showBackButton = false,
  });

  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0D1320) : AppColors.canvas;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  showBackButton ? 76 : 32,
                  24,
                  24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: child,
                ),
              ),
            ),
            if (showBackButton)
              Positioned(
                left: 18,
                top: 16,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.surface,
                    foregroundColor: isDark
                        ? Colors.white
                        : AppColors.inkStrong,
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: Get.back,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F86F7), AppColors.brandPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'K',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'KistBook',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : AppColors.inkStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return _AuthFieldFrame(
      label: label,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: _fieldTextStyle(context),
        decoration: _inputDecoration(
          context,
        ).copyWith(hintText: hint, prefixIcon: Icon(prefixIcon, size: 21)),
      ),
    );
  }
}

class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return _AuthFieldFrame(
      label: label,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: _fieldTextStyle(context),
        decoration: _inputDecoration(context).copyWith(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 21),
          suffixIcon: IconButton(
            onPressed: onToggleObscure,
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: isLoading
            ? const SizedBox.shrink()
            : Icon(icon, size: 21, color: Colors.white),
        label: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class AuthLegalCopy extends StatelessWidget {
  const AuthLegalCopy({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 15,
          color: isDark ? Colors.white70 : AppColors.inkMuted,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: 'By continuing, you agree to our '.tr,
              children: [
                TextSpan(
                  text: 'Terms of Service'.tr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: ' and '.tr),
                TextSpan(
                  text: 'Privacy Policy'.tr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.inkSoft,
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthFieldFrame extends StatelessWidget {
  const _AuthFieldFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 1, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.inkStrong,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    filled: true,
    fillColor: isDark
        ? Colors.white.withValues(alpha: 0.04)
        : AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    prefixIconConstraints: const BoxConstraints(minWidth: 48),
    hintStyle: TextStyle(
      color: isDark ? Colors.white.withValues(alpha: 0.64) : AppColors.inkMuted,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.4,
      ),
    ),
  );
}

TextStyle _fieldTextStyle(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return TextStyle(
    color: isDark ? Colors.white : AppColors.inkStrong,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );
}
