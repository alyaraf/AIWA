import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_chip.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../bloc/review_bloc.dart';
import '../bloc/review_event.dart';
import '../bloc/review_state.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import 'package:aiwa_app/l10n/l10n.dart';

class ReviewPage extends StatefulWidget {
  final String bookingId;

  /// Optional — shows the provider/service card when available.
  final BookingEntity? booking;

  const ReviewPage({super.key, required this.bookingId, this.booking});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late ReviewBloc _bloc;
  late BookingEntity? _booking = widget.booking;
  int _rating = 0;
  final _commentController = TextEditingController();
  final _selectedTags = <String>{};

  /// Sent to the backend as-is; shown via [AiwaL10n.reviewTag].
  static const _tags = [
    'Punctual',
    'Skilled',
    'Friendly',
    'Clean studio',
    'Worth the price',
    'Great with hair',
  ];

  @override
  void initState() {
    super.initState();
    _bloc = sl<ReviewBloc>();
    if (_booking == null) _loadBooking();
  }

  /// Deep links to /review/:id carry no extra (BOOK-34-F3).
  Future<void> _loadBooking() async {
    final r = await sl<BookingRepository>().getBookingDetail(widget.bookingId);
    if (!mounted) return;
    r.fold((_) {}, (b) => setState(() => _booking = b));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    _bloc.add(
      ReviewSubmitEvent(
        bookingId: widget.bookingId,
        rating: _rating.toDouble(),
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        tags: _selectedTags.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<ReviewBloc, ReviewState>(
        bloc: _bloc,
        listener: (ctx, state) {
          if (state is ReviewSubmitted) {
            showAiwaToast(context, AppLocalizations.of(context).reviewThanks);
            context.go(AppRoutes.myBookings);
          }
          // ReviewError shows inline above Submit (bottomNavigationBar).
        },
        child: Scaffold(
          backgroundColor: AppColors.bone,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              ScreenHeader(
                eyebrow: AppLocalizations.of(context).reviewEyebrow,
                title: AppLocalizations.of(context).reviewTitle,
                onBack: () => context.pop(),
              ),
              // Kit header bottom padding is 12, ScreenHeader's 8.
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  14,
                  AppTheme.gutter,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRatingCard(),
                    const SizedBox(height: 22),
                    EyebrowLabel(AppLocalizations.of(context).reviewQuickTags),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((tag) {
                        final on = _selectedTags.contains(tag);
                        return AiwaChip(
                          label: AppLocalizations.of(context).reviewTag(tag),
                          active: on,
                          onTap: () => setState(() {
                            on
                                ? _selectedTags.remove(tag)
                                : _selectedTags.add(tag);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    EyebrowLabel(AppLocalizations.of(context).reviewStoodOut),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: TextField(
                        controller: _commentController,
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        cursorColor: AppColors.plum700,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).reviewHint,
                          hintStyle: AppTextStyles.bodySm.copyWith(
                            color: AppColors.ink4,
                          ),
                          filled: true,
                          fillColor: AppColors.paper,
                          contentPadding: const EdgeInsets.all(14),
                          border: AppTheme.inputBorder(AppColors.divider),
                          enabledBorder: AppTheme.inputBorder(
                            AppColors.divider,
                          ),
                          focusedBorder: AppTheme.inputBorder(
                            AppColors.plum700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: StickyBar(
            child: BlocBuilder<ReviewBloc, ReviewState>(
              bloc: _bloc,
              builder: (ctx, state) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state is ReviewError) ...[
                    InlineBanner(
                      tone: BannerTone.danger,
                      icon: Icons.error_outline_rounded,
                      body: AppLocalizations.of(context).error(state.message),
                      compact: true,
                    ),
                    const SizedBox(height: 10),
                  ],
                  AiwaButton(
                    label: AppLocalizations.of(context).reviewSubmit,
                    onPressed: _rating > 0 ? _submit : null,
                    loading: state is ReviewLoading,
                    fullWidth: true,
                    size: AiwaButtonSize.lg,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    final b = _booking;
    final l = AppLocalizations.of(context);
    String? subtitle;
    if (b != null) {
      try {
        subtitle =
            '${bidiIsolate(b.serviceName)} · ${DateFormat.MMMEd(l.localeName).format(DateTime.parse(b.scheduledDate))}';
      } catch (_) {
        subtitle = b.serviceName;
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          if (b != null) ...[
            AiwaAvatar(
              name: b.displayProviderName,
              size: 64,
              imageUrl: b.providerImageUrl,
              verified: b.providerVerified,
              palette: AiwaAvatar.paletteFor(b.providerId),
            ),
            const SizedBox(height: 10),
            Text(
              b.displayProviderName,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(fontSize: 20, height: 1.1),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: AppTextStyles.micro.copyWith(fontSize: 12)),
            ],
            const SizedBox(height: 18),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final on = _rating > i;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: AnimatedScale(
                  scale: on ? 1 : 0.94,
                  duration: const Duration(milliseconds: 180),
                  curve: AppTheme.easeSoft,
                  child: Padding(
                    // gap 10 + 2x4 button padding ≈ 18 between stars.
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Icon(
                      on ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 38,
                      color: on ? AppColors.gold500 : AppColors.ink4,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            [
              l.reviewTapStar,
              l.reviewDisappointing,
              l.reviewBelow,
              l.reviewGood,
              l.reviewGreat,
              l.reviewOutstanding,
            ][_rating],
            style: AppTextStyles.h4.copyWith(
              color: _rating > 0 ? AppColors.plum900 : AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
