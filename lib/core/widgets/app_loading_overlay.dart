import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';

class AppLoadingOverlay {
  AppLoadingOverlay._();

  static final ValueNotifier<String> _messageNotifier = ValueNotifier('');
  static final Set<Object> _activeRunTokens = <Object>{};
  static OverlayEntry? _overlayEntry;

  static bool get isVisible => _overlayEntry != null;

  static void show(BuildContext context, {String message = 'Please wait...'}) {
    _messageNotifier.value = message;
    if (isVisible) {
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (_) => _AppLoadingOverlayView(messageNotifier: _messageNotifier),
    );
    overlay.insert(_overlayEntry!);
  }

  static void hide() {
    _activeRunTokens.clear();
    _removeOverlay();
  }

  static Future<T> run<T>(
    BuildContext context, {
    required Future<T> Function() task,
    String message = 'Please wait...',
  }) async {
    final token = Object();
    _activeRunTokens.add(token);
    show(context, message: message);
    try {
      return await task();
    } finally {
      _activeRunTokens.remove(token);
      if (_activeRunTokens.isEmpty) {
        _removeOverlay();
      }
    }
  }

  static void showFromGet({String message = 'Please wait...'}) {
    final context = Get.overlayContext ?? Get.context;
    if (context != null) {
      show(context, message: message);
    }
  }

  static Future<T> runFromGet<T>({
    required Future<T> Function() task,
    String message = 'Please wait...',
  }) {
    final context = Get.overlayContext ?? Get.context;
    if (context == null) {
      return task();
    }
    return run(context, task: task, message: message);
  }

  static void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _messageNotifier.value = '';
  }
}

class _AppLoadingOverlayView extends StatelessWidget {
  const _AppLoadingOverlayView({required this.messageNotifier});

  final ValueListenable<String> messageNotifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark ? const Color(0xFF131B2E) : AppColors.surface;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.border;
    final textColor = isDark ? Colors.white : AppColors.inkStrong;

    return Stack(
      children: [
        ModalBarrier(
          key: const ValueKey('app-loading-overlay-barrier'),
          dismissible: false,
          color: Colors.black.withValues(alpha: 0.48),
        ),
        SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.34 : 0.20,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _KistBookLogoProgressIndicator(),
                      ValueListenableBuilder<String>(
                        valueListenable: messageNotifier,
                        builder: (context, message, _) {
                          final normalizedMessage = message.trim();
                          if (normalizedMessage.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              normalizedMessage.tr,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KistBookLogoProgressIndicator extends StatefulWidget {
  const _KistBookLogoProgressIndicator();

  @override
  State<_KistBookLogoProgressIndicator> createState() =>
      _KistBookLogoProgressIndicatorState();
}

class _KistBookLogoProgressIndicatorState
    extends State<_KistBookLogoProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: primary,
              backgroundColor: primary.withValues(alpha: 0.14),
            ),
          ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, AppColors.brandPrimary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.24),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2.4),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'K',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
