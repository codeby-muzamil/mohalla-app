import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small gold "SAMPLE" ribbon used on every piece of sample content,
/// so sample data is never mistaken for real data.
class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold),
      ),
      child: const Text(
        'SAMPLE — real data coming later',
        style: TextStyle(
          color: AppTheme.gold,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Standard section heading with a gold underline.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 12),
          height: 3,
          width: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.goldLight, AppTheme.gold],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A number inside a circle that NEVER overflows: the text is scaled
/// down to fit (FittedBox), so 1-, 2- and 3-digit numbers — and 1.3x
/// elder-mode scaling — stay inside the circle.
class NumberBadge extends StatelessWidget {
  final String text;
  final double radius;
  final Color? background;
  final Color? foreground;

  const NumberBadge({
    super.key,
    required this.text,
    this.radius = 20,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? AppTheme.emerald,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: foreground ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A card with press + hover feedback: scales down slightly on press,
/// lifts (shadow + translate) on hover (desktop/web), InkWell splash,
/// and an optional gold gradient border. Every feature card uses this.
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool gradientBorder;
  final double radius;
  final bool glowOnHover;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.gradientBorder = false,
    this.radius = 16,
    this.glowOnHover = true,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.color ??
        (isDark ? AppTheme.nightCard : Colors.white);
    final shadow = _hovered
        ? [
            BoxShadow(
              color: AppTheme.gold.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ]
        : const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ];
    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.translationValues(
        0,
        _hovered ? -3 : 0,
        0,
      ),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.radius),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
    final bordered = widget.gradientBorder
        ? Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius + 1.5),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.goldLight,
                  AppTheme.gold,
                  AppTheme.emerald,
                ],
              ),
            ),
            child: inner,
          )
        : inner;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: bordered,
        ),
      ),
    );
  }
}

/// A card that opens a screen when tapped.
class ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Tightened so the card fits its grid cell with headroom: the old
    // version (14px padding, 26px icon, 10px gaps) was ~1.6px taller
    // than a 1.35-ratio cell on a narrow phone. Title/subtitle both
    // ellipsize and the subtitle is capped at 2 lines, so the card
    // can never overflow its cell, even at 1.3x elder-mode scaling.
    return PressableCard(
      onTap: onTap,
      gradientBorder: true,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.emerald, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold gradient button.
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.ink,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    );
  }
}

/// Simple "coming from sample data" note shown under lists.
class SampleNote extends StatelessWidget {
  final String text;

  const SampleNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
      ),
    );
  }
}
