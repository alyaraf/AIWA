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
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../bloc/review_bloc.dart';
import '../bloc/review_event.dart';
import '../bloc/review_state.dart';

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
  int _rating = 0;
  final _commentController = TextEditingController();
  final _selectedTags = <String>{};

  static const _tags = [
    'Punctual',
    'Skilled',
    'Friendly',
    'Clean studio',
    'Worth the price',
    'Great with hair',
  ];

  static const _adjectives = [
    'Tap a star',
    'Disappointing',
    'Below expectations',
    'Good',
    'Great',
    'Outstanding',
  ];

  @override
  void initState() {
    super.initState();
    _bloc = sl<ReviewBloc>();
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
            context.go(AppRoutes.myBookings);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thanks — your review is live.')),
            );
          } else if (state is ReviewError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.bone,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              ScreenHeader(
                eyebrow: 'Leave a review',
                title: 'How was it?',
                onBack: () => context.pop(),
              ),
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
                    const EyebrowLabel('Quick tags (optional)'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((tag) {
                        final on = _selectedTags.contains(tag);
                        return AiwaChip(
                          label: tag,
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
                    AiwaTextField(
                      controller: _commentController,
                      label: 'Tell others what stood out',
                      placeholder:
                          "Optional — your review will be public on the provider's profile.",
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: StickyBar(
            child: BlocBuilder<ReviewBloc, ReviewState>(
              bloc: _bloc,
              builder: (ctx, state) => AiwaButton(
                label: 'Submit review',
                onPressed: _rating > 0 ? _submit : null,
                loading: state is ReviewLoading,
                fullWidth: true,
                size: AiwaButtonSize.lg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard() {
    final b = widget.booking;
    String? subtitle;
    if (b != null) {
      try {
        subtitle =
            '${b.serviceName} · ${DateFormat('EEE, MMM d').format(DateTime.parse(b.scheduledDate))}';
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
                    padding: const EdgeInsets.symmetric(horizontal: 5),
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
            _adjectives[_rating],
            style: AppTextStyles.h4.copyWith(
              color: _rating > 0 ? AppColors.plum900 : AppColors.ink3,
            ),
          ),
        ],
      ),
    );
  }
}
