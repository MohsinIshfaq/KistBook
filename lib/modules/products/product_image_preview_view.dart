import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import 'product_image_remove_dialog.dart';

class ProductImagePreviewView extends StatefulWidget {
  const ProductImagePreviewView({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
    this.onDelete,
  });

  final List<String> imagePaths;
  final int initialIndex;
  final ValueChanged<String>? onDelete;

  @override
  State<ProductImagePreviewView> createState() =>
      _ProductImagePreviewViewState();
}

class _ProductImagePreviewViewState extends State<ProductImagePreviewView> {
  late final PageController _pageController;
  late final List<String> _imagePaths;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _imagePaths = List<String>.from(widget.imagePaths);
    _currentIndex = _imagePaths.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _imagePaths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _deleteCurrentImage() async {
    if (_imagePaths.isEmpty) {
      return;
    }

    final confirmed = await confirmRemoveProductImage(context);
    if (!confirmed || !mounted) {
      return;
    }

    final removedPath = _imagePaths.removeAt(_currentIndex);
    widget.onDelete?.call(removedPath);

    if (_imagePaths.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    if (_currentIndex >= _imagePaths.length) {
      _currentIndex = _imagePaths.length - 1;
    }
    setState(() {});
    _pageController.jumpToPage(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_imagePaths.isEmpty)
              Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.white.withValues(alpha: 0.72),
                  size: 48,
                ),
              )
            else
              PageView.builder(
                controller: _pageController,
                itemCount: _imagePaths.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) => _ZoomableProductImage(
                  key: ValueKey(_imagePaths[index]),
                  imagePath: _imagePaths[index],
                ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: _PreviewIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close'.tr,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.onDelete != null)
              Positioned(
                right: 12,
                top: 12,
                child: _PreviewIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete'.tr,
                  color: AppColors.danger,
                  onPressed: _deleteCurrentImage,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewIconButton extends StatelessWidget {
  const _PreviewIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        foregroundColor: color ?? Colors.white,
        fixedSize: const Size(44, 44),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _ZoomableProductImage extends StatefulWidget {
  const _ZoomableProductImage({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<_ZoomableProductImage> createState() => _ZoomableProductImageState();
}

class _ZoomableProductImageState extends State<_ZoomableProductImage> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.01) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    const targetScale = 2.5;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (targetScale - 1),
        -position.dy * (targetScale - 1),
        0,
        1,
      )
      ..scaleByDouble(targetScale, targetScale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.broken_image_outlined,
              color: Colors.white.withValues(alpha: 0.7),
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
