import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/assistant_providers.dart';

/// A compact status chip shown in the chat AppBar.
class ModelStatusBanner extends StatelessWidget {
  const ModelStatusBanner({super.key, required this.status, this.onRetry});

  final ModelLoadStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      ModelLoadStatus.ready => ('Ready', AppColors.chartGreen, Icons.circle),
      ModelLoadStatus.loading => (
        'Loading…',
        AppColors.chartAmber,
        Icons.hourglass_top_rounded,
      ),
      ModelLoadStatus.failed => (
        'Failed',
        AppColors.accent,
        Icons.error_outline_rounded,
      ),
      ModelLoadStatus.notDownloaded => (
        'Not set up',
        AppColors.textLight,
        Icons.info_outline_rounded,
      ),
    };

    return GestureDetector(
      onTap: status == ModelLoadStatus.failed ? onRetry : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
