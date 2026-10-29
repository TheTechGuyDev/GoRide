import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, outline, danger }

/// Pill-shaped button used across GoRide.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = AppColors.primary;
        fg = Colors.white;
      case AppButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurface : AppColors.primaryLight;
        fg = AppColors.primary;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? Colors.white : AppColors.textPrimary;
        side = BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        );
      case AppButtonVariant.danger:
        bg = Colors.transparent;
        fg = AppColors.error;
        side = const BorderSide(color: AppColors.error);
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          shape: StadiumBorder(side: side),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 12)],
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(color: fg),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
