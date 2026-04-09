import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.caption,
  });

  final String label;
  final String value;
  final Color accent;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 10),
            Text(caption, style: const TextStyle(color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
