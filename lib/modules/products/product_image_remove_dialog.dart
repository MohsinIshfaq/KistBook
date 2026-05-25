import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';

Future<bool> confirmRemoveProductImage(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Remove Image?'.tr),
      content: Text('Are you sure you want to remove this product image?'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel'.tr),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Remove'.tr),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
