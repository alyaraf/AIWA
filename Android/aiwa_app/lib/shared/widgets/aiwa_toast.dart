import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

OverlayEntry? _current;

/// Success toast at the top of the screen — `Toast` in prototype.jsx.
/// Success only: failures go inline (InlineBanner / field errors).
void showAiwaToast(BuildContext context, String message) {
  _current?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  const _Toast({required this.message, required this.onDone});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppTheme.dur3);
  late final _a = CurvedAnimation(parent: _c, curve: AppTheme.easeSoft);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 2800), () async {
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _a,
        child: SlideTransition(
          // aiwa-toast: translateY(-10px) -> 0.
          position: Tween(
            begin: const Offset(0, -.2),
            end: Offset.zero,
          ).animate(_a),
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.toastShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: AppColors.plum900.withValues(alpha: .96),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.success500,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: AppColors.paper,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: AppTextStyles.meta.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.bone,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
