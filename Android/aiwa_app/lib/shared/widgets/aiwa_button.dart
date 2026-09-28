import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

enum AiwaButtonVariant {
  primary,
  accent,
  secondary,
  ghost,
  danger,
  dark,
  light,
}

enum AiwaButtonSize { sm, md, lg }

/// Pill button — mirrors `Btn` in the design kit.
///
/// No spinners (design rule): while [loading] the label pulses instead.
class AiwaButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AiwaButtonVariant variant;
  final AiwaButtonSize size;
  final bool fullWidth;
  final IconData? icon;
  final bool loading;

  const AiwaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AiwaButtonVariant.primary,
    this.size = AiwaButtonSize.md,
    this.fullWidth = false,
    this.icon,
    this.loading = false,
  });

  @override
  State<AiwaButton> createState() => _AiwaButtonState();
}

class _AiwaButtonState extends State<AiwaButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.35,
    upperBound: 1,
  );

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AiwaButton old) {
    super.didUpdateWidget(old);
    if (widget.loading && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.loading && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _sizeConfig(widget.size);
    final c = _colorConfig(widget.variant);

    Widget content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: s.iconSize, color: c.fg),
          SizedBox(width: s.gap),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.button.copyWith(
              fontSize: s.fontSize,
              color: c.fg,
            ),
          ),
        ),
      ],
    );

    if (widget.loading) {
      content = FadeTransition(opacity: _pulse, child: content);
    }

    return AnimatedOpacity(
      opacity: widget.onPressed == null && !widget.loading ? 0.45 : 1.0,
      duration: AppTheme.dur2,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: AppTheme.dur1,
        curve: AppTheme.easeSoft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTap: _enabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: AppTheme.dur2,
            curve: AppTheme.easeSoft,
            width: widget.fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: s.hPad, vertical: s.vPad),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: c.border,
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  _SizeConfig _sizeConfig(AiwaButtonSize size) {
    switch (size) {
      case AiwaButtonSize.sm:
        return const _SizeConfig(
          hPad: 14,
          vPad: 8,
          fontSize: 13,
          iconSize: 14,
          gap: 6,
        );
      case AiwaButtonSize.md:
        return const _SizeConfig(
          hPad: 20,
          vPad: 12,
          fontSize: 15,
          iconSize: 16,
          gap: 8,
        );
      case AiwaButtonSize.lg:
        return const _SizeConfig(
          hPad: 26,
          vPad: 15,
          fontSize: 16,
          iconSize: 18,
          gap: 10,
        );
    }
  }

  _ColorConfig _colorConfig(AiwaButtonVariant variant) {
    switch (variant) {
      case AiwaButtonVariant.primary:
        return _ColorConfig(bg: AppColors.plum700, fg: AppColors.paper);
      case AiwaButtonVariant.accent:
        return _ColorConfig(bg: AppColors.rose500, fg: AppColors.plum900);
      case AiwaButtonVariant.secondary:
        return _ColorConfig(
          bg: Colors.transparent,
          fg: AppColors.plum700,
          border: Border.all(color: AppColors.plum700, width: 1.5),
        );
      case AiwaButtonVariant.ghost:
        return _ColorConfig(bg: Colors.transparent, fg: AppColors.plum700);
      case AiwaButtonVariant.danger:
        return _ColorConfig(bg: AppColors.danger500, fg: AppColors.paper);
      case AiwaButtonVariant.dark:
        return _ColorConfig(bg: AppColors.plum900, fg: AppColors.bone);
      case AiwaButtonVariant.light:
        return _ColorConfig(bg: AppColors.bone, fg: AppColors.plum900);
    }
  }
}

class _SizeConfig {
  final double hPad, vPad, fontSize, iconSize, gap;
  const _SizeConfig({
    required this.hPad,
    required this.vPad,
    required this.fontSize,
    required this.iconSize,
    required this.gap,
  });
}

class _ColorConfig {
  final Color bg, fg;
  final BoxBorder? border;
  _ColorConfig({required this.bg, required this.fg, this.border});
}
