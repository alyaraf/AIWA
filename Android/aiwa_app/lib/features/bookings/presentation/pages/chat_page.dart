import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../bloc/chat_cubit.dart';
import '../bloc/live_booking_cubit.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// BOOK-36 / 37 — chat with the provider (customer-extras-2.jsx:100-177).
class ChatPage extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  const ChatPage({super.key, required this.bookingId, this.booking});

  @override
  Widget build(BuildContext context) => LiveBookingScope(
    bookingId: bookingId,
    booking: booking,
    child: BlocProvider(
      create: (_) => ChatCubit(sl<BookingRepository>(), bookingId),
      child: const _ChatView(),
    ),
  );
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    if (!await context.read<ChatCubit>().send(t)) _text.text = t;
  }

  Future<void> _report(ChatMessageEntity m) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: AppLocalizations.of(context).chatReportEyebrow,
      title: AppLocalizations.of(context).chatReportTitle,
      body: AppLocalizations.of(context).chatReportBody,
      confirmLabel: AppLocalizations.of(context).chatReportEyebrow,
      icon: Icons.flag_outlined,
    );
    if (ok && mounted) context.read<ChatCubit>().report(m.id);
  }

  Future<void> _call() async {
    final n = await context.read<LiveBookingCubit>().maskedPhone();
    if (n != null) await launchUrl(Uri(scheme: 'tel', path: n));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final me = auth is AuthAuthenticated ? auth.user.id : -1;
    final booking = context.watch<LiveBookingCubit>().state;
    final name = booking.booking?.displayProviderName ?? '';
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              AppTheme.gutter,
              MediaQuery.paddingOf(context).top + 14,
              AppTheme.gutter,
              12,
            ),
            decoration: BoxDecoration(
              color: AppColors.paper,
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                AiwaIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: 12),
                AiwaAvatar(
                  name: name,
                  size: 36,
                  imageUrl: booking.booking?.providerImageUrl,
                  verified: booking.booking?.providerVerified ?? false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      // ponytail: static; no presence or masked-number
                      // status in the backend yet.
                      Text(
                        AppLocalizations.of(context).chatMaskedOnline,
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success700,
                        ),
                      ),
                    ],
                  ),
                ),
                AiwaIconButton(
                  icon: Icons.phone_outlined,
                  size: 36,
                  onTap: _call,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
            child: Column(
              children: [
                InlineBanner(
                  tone: BannerTone.plum,
                  icon: Icons.visibility_outlined,
                  body: AppLocalizations.of(context).chatAdminNote,
                ),
                if (booking.actionError != null) ...[
                  const SizedBox(height: 8),
                  InlineBanner(
                    tone: BannerTone.danger,
                    body: AppLocalizations.of(
                      context,
                    ).error(booking.actionError!),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, s) {
                final list = s.messages;
                return Column(
                  children: [
                    if (s.error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: InlineBanner(
                          tone: BannerTone.danger,
                          body: AppLocalizations.of(context).error(s.error!),
                        ),
                      ),
                    Expanded(
                      child: list == null
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: SkeletonList(count: 3),
                            )
                          // Reversed so the newest stays pinned to the bottom.
                          : ListView.separated(
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              itemCount: list.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final m = list[list.length - 1 - i];
                                final mine = m.senderId == me;
                                return _Bubble(
                                  m: m,
                                  mine: mine,
                                  onReport:
                                      mine ||
                                          m.removed ||
                                          s.reported.contains(m.id)
                                      ? null
                                      : () => _report(m),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              14,
              14,
              14,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    cursorColor: AppColors.plum700,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).chatHint,
                      hintStyle: AppTextStyles.bodySm.copyWith(
                        color: AppColors.ink4,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.cream,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      border: _pill(AppColors.divider),
                      enabledBorder: _pill(AppColors.divider),
                      focusedBorder: _pill(AppColors.plum700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AiwaIconButton(
                  icon: Icons.send_rounded,
                  variant: AiwaIconButtonVariant.plum,
                  onTap: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static OutlineInputBorder _pill(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(999),
    borderSide: BorderSide(color: c, width: 1.5),
  );
}

class _Bubble extends StatelessWidget {
  final ChatMessageEntity m;
  final bool mine;
  final VoidCallback? onReport;
  const _Bubble({required this.m, required this.mine, this.onReport});

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.sizeOf(context).width * .78;
    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: max),
          child: m.removed
              // ponytail: solid 1px border; the kit's is dashed.
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        size: 13,
                        color: AppColors.ink4,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context).chatRemoved,
                          style: AppTextStyles.meta.copyWith(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.ink4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.plum700 : AppColors.paper,
                    border: mine ? null : Border.all(color: AppColors.divider),
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: const Radius.circular(16),
                      topEnd: const Radius.circular(16),
                      bottomStart: Radius.circular(mine ? 16 : 4),
                      bottomEnd: Radius.circular(mine ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.message,
                        textDirection: textDirectionOf(m.message),
                        style: AppTextStyles.bodySm.copyWith(
                          height: 1.45,
                          color: mine ? AppColors.bone : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: .65,
                        child: Text(
                          DateFormat(
                            'h:mm a',
                            Localizations.localeOf(context).toString(),
                          ).format(m.createdAt),
                          style: AppTextStyles.micro.copyWith(
                            fontSize: 10,
                            color: mine ? AppColors.bone : AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (onReport != null)
          GestureDetector(
            onTap: onReport,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 3, 2, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 10, color: AppColors.ink4),
                  const SizedBox(width: 3),
                  Text(
                    AppLocalizations.of(context).chatReport,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 10.5,
                      color: AppColors.ink4,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
