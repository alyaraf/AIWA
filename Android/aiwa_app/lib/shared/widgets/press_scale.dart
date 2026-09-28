import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Tap target that dips to .96 while pressed — the prototype's global
/// `button:active { transform: scale(.96) }` (prototype.html:41-42).
class PressScale extends StatefulWidget {
  final VoidCallback? onTap;
  final HitTestBehavior? behavior;
  final Widget child;

  const PressScale({
    super.key,
    required this.onTap,
    this.behavior,
    required this.child,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: widget.behavior,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _pressed ? .96 : 1,
          duration: AppTheme.dur1,
          curve: AppTheme.easeSoft,
          child: widget.child,
        ),
      ),
    );
  }
}
