import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_chip.dart';
import '../../../../shared/widgets/aiwa_tag.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../data/provider_manage_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Filter ids (labels come from [_filterLabel]).
const _filters = ['All', 'Needs reply', '5 star', '4 star'];

String _filterLabel(AppLocalizations l, String f) => switch (f) {
  'All' => l.revFilterAll,
  'Needs reply' => l.revFilterNeedsReply,
  _ => l.revFilterStars(int.parse(f[0])),
};

/// Reviews matching a filter chip. ReviewDto has no reply yet, so
/// 'Needs reply' keeps every review without a local `reply`.
List<Json> filterReviews(List<Json> all, String f) => switch (f) {
  'All' => all,
  'Needs reply' => [
    for (final r in all)
      if ((r['reply'] as String?)?.isNotEmpty != true) r,
  ],
  _ => [
    for (final r in all)
      if (r['rating'] == int.parse(f[0])) r,
  ],
};

/// Provider reviews + reply — `ProviderReviewsScreen`
/// (provider-manage.jsx:185-275).
class ProviderReviewsPage extends StatefulWidget {
  const ProviderReviewsPage({super.key});

  @override
  State<ProviderReviewsPage> createState() => _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends State<ProviderReviewsPage> {
  final _repo = sl<ProviderManageRepository>();
  final _draft = TextEditingController();
  List<Json>? _all;
  String? _error, _replyError;
  String _filter = 'All';
  String? _replyTo;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await _repo.reviews(providerIdOf(context));
    if (!mounted) return;
    setState(() {
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _all = r.fold(
        (_) => _all,
        (list) => [
          for (final e in list)
            if (e['direction'] != 'PROVIDER_TO_CUSTOMER' &&
                e['direction'] != 'SAFETY')
              e,
        ],
      );
    });
  }

  void _openComposer(String id) => setState(() {
    _replyTo = id;
    _replyError = null;
    _draft.clear();
  });

  Future<void> _post(Json r) async {
    final text = _draft.text.trim();
    setState(() => _posting = true);
    final res = await _repo.replyToReview('${r['id']}', text);
    if (!mounted) return;
    res.fold(
      (f) => setState(() {
        _posting = false;
        _replyError = AppLocalizations.of(context).error(f.message);
      }),
      (_) => setState(() {
        _posting = false;
        r['reply'] = text;
        _replyTo = null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.revEyebrow,
            title: l.revTitle,
            onBack: () => context.pop(),
          ),
          if (all == null)
            Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: _error != null
                  ? ErrorState(body: _error!, onRetry: _load, compact: true)
                  : const SkeletonList(),
            )
          else if (all.isEmpty)
            EmptyState(
              icon: LucideIcons.star,
              title: l.providerNoReviews,
              subtitle: l.revEmptyBody,
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                0,
              ),
              child: _Summary(all: all),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                16,
                AppTheme.gutter,
                0,
              ),
              child: Row(
                spacing: 7,
                children: [
                  for (final f in _filters)
                    AiwaChip(
                      label: _filterLabel(l, f),
                      active: _filter == f,
                      onTap: () => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                0,
              ),
              child: Column(
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (filterReviews(all, _filter).isEmpty)
                    EmptyState(
                      icon: LucideIcons.messageCircle,
                      title: l.revNothingHere,
                      subtitle: l.revNoMatch,
                      compact: true,
                    ),
                  for (final r in filterReviews(all, _filter))
                    _ReviewCard(
                      r: r,
                      composer: _replyTo == '${r['id']}'
                          ? _Composer(
                              controller: _draft,
                              error: _replyError,
                              posting: _posting,
                              onChanged: () => setState(() {}),
                              onCancel: () => setState(() => _replyTo = null),
                              onPost: () => _post(r),
                            )
                          : null,
                      onReply: () => _openComposer('${r['id']}'),
                    ),
                  EndOfList(label: l.revTotal(all.length)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<Json> all;
  const _Summary({required this.all});

  @override
  Widget build(BuildContext context) {
    final avg =
        all.fold<num>(0, (s, r) => s + (r['rating'] as num? ?? 0)) / all.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        spacing: 20,
        children: [
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: AppTextStyles.display.copyWith(
                  fontSize: 38,
                  height: 1,
                  color: AppColors.plum900,
                ),
              ),
              const SizedBox(height: 5),
              StarRating(value: avg.roundToDouble(), size: 13),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).revCount(all.length),
                style: AppTextStyles.micro.copyWith(fontSize: 11),
              ),
            ],
          ),
          Expanded(
            child: Column(
              spacing: 4,
              children: [
                for (final n in [5, 4, 3, 2, 1])
                  _DistRow(
                    n: n,
                    count: all.where((r) => r['rating'] == n).length,
                    total: all.length,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistRow extends StatelessWidget {
  final int n, count, total;
  const _DistRow({required this.n, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final mono = AppTextStyles.mono.copyWith(fontSize: 10.5);
    return Row(
      spacing: 7,
      children: [
        SizedBox(
          width: 8,
          child: Text('$n', style: mono.copyWith(color: AppColors.ink3)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: count / total,
              minHeight: 5,
              backgroundColor: AppColors.cream,
              color: AppColors.gold500,
            ),
          ),
        ),
        SizedBox(
          width: 14,
          child: Text(
            '$count',
            textAlign: TextAlign.end,
            style: mono.copyWith(color: AppColors.ink4),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Json r;
  final Widget? composer;
  final VoidCallback onReply;
  const _ReviewCard({required this.r, this.composer, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final author =
        (r['user'] as Json?)?['fullName'] as String? ?? l.commonCustomer;
    final at = DateTime.tryParse('${r['createdAt']}');
    final tags = [for (final t in r['quickTags'] as List? ?? const []) '$t'];
    final reply = r['reply'] as String?;
    final comment = r['comment'] as String?;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 11,
            children: [
              AiwaAvatar(
                name: author,
                size: 38,
                imageUrl: (r['user'] as Json?)?['profileImageUrl'] as String?,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: AppTextStyles.label.copyWith(
                        fontSize: AppTextStyles.fsMetaPlus,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // BACKEND GAP: ReviewDto has no service name.
                    if (at != null)
                      Text(
                        l.relativeDay(at),
                        style: AppTextStyles.micro.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ),
              StarRating(
                value: (r['rating'] as num? ?? 0).toDouble(),
                size: 13,
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (comment != null && comment.isNotEmpty) ...[
            Text(
              comment,
              style: AppTextStyles.body.copyWith(
                fontSize: AppTextStyles.fsMetaPlus,
                color: AppColors.ink2,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 9),
          ],
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in tags) AiwaTag(l.reviewTag(t))],
            ),
            const SizedBox(height: 10),
          ],
          if (reply != null && reply.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.plum100,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      Icon(
                        LucideIcons.cornerDownRightDir,
                        size: 12,
                        color: AppColors.plum700,
                      ),
                      Text(
                        l.revYourReply,
                        style: AppTextStyles.labelSm.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .44,
                          color: AppColors.plum700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reply,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: AppTextStyles.fsLabelSmPlus,
                      height: 1.5,
                      color: AppColors.plum700,
                    ),
                  ),
                ],
              ),
            )
          else
            composer ??
                AiwaButton(
                  label: l.revReplyPublicly,
                  icon: LucideIcons.replyDir,
                  variant: AiwaButtonVariant.secondary,
                  size: AiwaButtonSize.sm,
                  onPressed: onReply,
                ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final bool posting;
  final VoidCallback onChanged, onCancel, onPost;

  const _Composer({
    required this.controller,
    required this.error,
    required this.posting,
    required this.onChanged,
    required this.onCancel,
    required this.onPost,
  });

  @override
  Widget build(BuildContext context) {
    final ready = controller.text.trim().isNotEmpty && !posting;
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 74,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 280,
            maxLines: null,
            expands: true,
            onChanged: (_) => onChanged(),
            cursorColor: AppColors.plum700,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              height: 1.5,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              hintText: l.revReplyHint,
              hintStyle: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.ink4,
              ),
              filled: true,
              fillColor: AppColors.bone,
              contentPadding: const EdgeInsets.all(12),
              counterText: '',
              border: _border,
              enabledBorder: _border,
              focusedBorder: _border,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 9,
          children: [
            Expanded(
              child: Text(
                '${controller.text.length}/280',
                style: AppTextStyles.mono.copyWith(
                  fontSize: 10.5,
                  color: AppColors.ink4,
                ),
              ),
            ),
            AiwaButton(
              label: l.commonCancel,
              variant: AiwaButtonVariant.ghost,
              size: AiwaButtonSize.sm,
              onPressed: onCancel,
            ),
            AiwaButton(
              label: l.revPostReply,
              size: AiwaButtonSize.sm,
              loading: posting,
              onPressed: ready ? onPost : null,
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          InlineBanner(tone: BannerTone.danger, body: error),
        ],
      ],
    );
  }

  static final _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: BorderSide(color: AppColors.plum700, width: 1.5),
  );
}
