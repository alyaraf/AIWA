import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/widgets/step_header.dart';
import '../../domain/entities/provider_detail_entity.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

/// 'Pick your stylist.' — `StaffPickerScreen` in customer-extras-2.jsx.
/// Shop-type providers only; pushed from the profile's Book actions.
class StaffPickerPage extends StatelessWidget {
  final ProviderDetailEntity provider;
  final String? serviceId;

  const StaffPickerPage({super.key, required this.provider, this.serviceId});

  void _pick(BuildContext context, String? staffId) {
    final target = AppRoutes.bookingTypeFor(
      provider.id,
      serviceId: serviceId,
      staffId: staffId,
    );
    if (context.read<AuthBloc>().state is AuthAuthenticated) {
      context.push(target);
    } else {
      context.push(AppRoutes.authGate, extra: target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthStepScaffold(
      bottom: const SizedBox.shrink(),
      children: [
        AiwaIconButton(
          icon: LucideIcons.arrowLeftDir,
          onTap: () => context.pop(),
        ),
        const SizedBox(height: 22),
        EyebrowLabel(provider.displayName),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context).staffPickTitle,
          style: AppTextStyles.h1.copyWith(
            fontSize: 28,
            height: 1.05,
            letterSpacing: -0.56,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).staffPickBody,
          style: AppTextStyles.bodySm.copyWith(
            fontSize: 14,
            color: AppColors.ink2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 22),
        for (final (i, s) in provider.staff.indexed) ...[
          _StaffCard(
            onTap: () => _pick(context, s.id),
            leading: AiwaAvatar(
              name: s.fullName,
              size: 50,
              verified: true,
              palette: AvatarPalette.values[i % AvatarPalette.values.length],
            ),
            title: s.fullName,
            subtitle: s.title ?? '',
            trailing: Icon(
              LucideIcons.chevronRightDir,
              size: 18,
              color: AppColors.ink3,
            ),
          ),
          const SizedBox(height: 10),
        ],
        _StaffCard(
          onTap: () => _pick(context, null),
          dashed: true,
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.plum100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.shuffle,
              size: 20,
              color: AppColors.plum700,
            ),
          ),
          title: AppLocalizations.of(context).staffNoPreference,
          subtitle: AppLocalizations.of(context).staffFirstAvailable,
        ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool dashed;

  const _StaffCard({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h4.copyWith(fontSize: 18, height: 1.1),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextStyles.micro.copyWith(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: dashed
          ? CustomPaint(
              painter: _DashedBorder(AppColors.divider),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: content,
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: content,
            ),
    );
  }
}

/// 1.5px dashed rounded border (no dotted_border dependency).
class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppTheme.radiusLg),
        ).deflate(.75),
      );
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
