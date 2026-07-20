import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

// ─── Gradient Containers ──────────────────────────────────────────────────────

class AppGradient extends StatelessWidget {
  const AppGradient({
    super.key,
    required this.child,
    this.colors = AppColors.brandGradientLight,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.borderRadius,
    this.padding,
  });
  final Widget child;
  final List<Color> colors;
  final AlignmentGeometry begin, end;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: begin, end: end, colors: colors),
      borderRadius: borderRadius,
    ),
    child: child,
  );
}

// ─── Shimmer Loading Boxes ────────────────────────────────────────────────────

class AppShimmerBox extends StatelessWidget {
  const AppShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });
  final double? width, height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE5E7EB),
    highlightColor: const Color(0xFFF9FAFB),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ),
  );
}

class AppShimmerCard extends StatelessWidget {
  const AppShimmerCard({super.key, this.height = 200});
  final double height;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE5E7EB),
    highlightColor: const Color(0xFFF9FAFB),
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}

// ─── Badge/Tag ────────────────────────────────────────────────────────────────

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.brand,
    this.soft = false,
  });
  final String label;
  final IconData? icon;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final bg = soft ? color.withValues(alpha: .12) : color;
    final fg = soft ? color : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar ──────────────────────────────────────────────────────────────────

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.fontSize,
  });
  final String name;
  final String? imageUrl;
  final double radius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.brandLight.withValues(alpha: .15),
      backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
          ? NetworkImage(imageUrl!)
          : null,
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Text(
              initial,
              style: AppTextStyles.label.copyWith(
                fontSize: fontSize ?? radius * 0.75,
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

// ─── Rating Row ───────────────────────────────────────────────────────────────

class AppRatingRow extends StatelessWidget {
  const AppRatingRow({
    super.key,
    required this.rating,
    this.count,
    this.light = false,
    this.size = 16,
  });
  final double rating;
  final int? count;
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textColor = light ? Colors.white : AppColors.ink;
    final mutedColor = light ? Colors.white.withValues(alpha: .65) : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: AppColors.gold, size: size),
        const SizedBox(width: 4),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : 'New',
          style: AppTextStyles.label.copyWith(color: textColor, fontSize: size - 2),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: AppTextStyles.caption.copyWith(color: mutedColor),
          ),
        ],
      ],
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.brand,
    this.softColor = AppColors.accentLight,
  });
  final IconData icon;
  final String value, label;
  final Color iconColor, softColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: softColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.h4.copyWith(color: iconColor)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    ),
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 36, color: AppColors.subtle),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppTextStyles.h4, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

// ─── Error State ─────────────────────────────────────────────────────────────

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, String? message, String? error, required this.onRetry})
      : _message = error ?? message ?? 'Something went wrong';
  final String _message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.errorSoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.error),
          ),
          const SizedBox(height: 18),
          Text('Something went wrong', style: AppTextStyles.h4),
          const SizedBox(height: 8),
          Text(_message, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

// ─── Section Header ───────────────────────────────────────────────────────────

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h3),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      ),
      ?trailing
    ],
  );
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = AppColors.accent,
  });
  final IconData icon;
  final String label, value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppTextStyles.labelSmall),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.label),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Hero Gradient Overlay ────────────────────────────────────────────────────

class AppHeroOverlay extends StatelessWidget {
  const AppHeroOverlay({super.key, this.strong = false});
  final bool strong;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: strong
            ? [const Color(0x55000000), const Color(0xEE000000)]
            : [const Color(0x22000000), const Color(0xCC000000)],
        stops: const [0.0, 1.0],
      ),
    ),
  );
}

// ─── Pill Chip ────────────────────────────────────────────────────────────────

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: .25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: selected ? Colors.white : AppColors.muted,
          fontSize: 13,
        ),
      ),
    ),
  );
}
