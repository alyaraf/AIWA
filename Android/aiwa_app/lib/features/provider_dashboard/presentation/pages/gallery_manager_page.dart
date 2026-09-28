import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_tag.dart';
import '../../../../shared/widgets/confirm_sheet.dart';
import '../../../../shared/widgets/dashed_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../data/provider_manage_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Gallery manager — `GalleryManagerScreen` (provider-manage.jsx:84-175).
class GalleryManagerPage extends StatefulWidget {
  const GalleryManagerPage({super.key});

  @override
  State<GalleryManagerPage> createState() => _GalleryManagerPageState();
}

class _GalleryManagerPageState extends State<GalleryManagerPage> {
  final _repo = sl<ProviderManageRepository>();
  List<String>? _items;
  String? _error;
  double? _progress;
  CancelToken? _cancel;

  // BACKEND GAP: gallery GET returns bare URLs, no moderation flag, so no
  // photo is ever marked hidden yet.
  final Set<String> _hidden = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await _repo.gallery(providerIdOf(context));
    if (!mounted) return;
    setState(() {
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _items = r.fold((_) => _items, (g) => g);
    });
  }

  Future<void> _upload() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _progress = 0;
      _error = null;
    });
    final r = await _repo.uploadPhoto(
      picked.path,
      cancel: cancel,
      onProgress: (sent, total) {
        if (mounted && total > 0) setState(() => _progress = sent / total);
      },
    );
    if (!mounted) return;
    setState(() {
      _progress = null;
      _cancel = null;
      if (cancel.isCancelled) return;
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _items = r.fold((_) => _items, (g) => g);
    });
  }

  Future<void> _delete(String url) async {
    final ok = await showConfirmSheet(
      context,
      eyebrow: AppLocalizations.of(context).galEyebrow,
      title: AppLocalizations.of(context).galDeleteTitle,
      body: AppLocalizations.of(context).galDeleteBody,
      confirmLabel: AppLocalizations.of(context).commonDelete,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    final r = await _repo.deletePhoto(url);
    if (!mounted) return;
    setState(() {
      _error = r.fold(
        (f) => AppLocalizations.of(context).error(f.message),
        (_) => null,
      );
      _items = r.fold((_) => _items, (g) => g);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.revEyebrow,
            title: l.galEyebrow,
            onBack: () => context.pop(),
            trailing: items == null ? null : AiwaTag('${items.length}/20'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              14,
              AppTheme.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.galIntro,
                  style: AppTextStyles.meta.copyWith(
                    color: AppColors.ink3,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 14),
                if (_progress != null) ...[
                  _UploadCard(
                    progress: _progress!,
                    onCancel: () => _cancel?.cancel(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null) ...[
                  InlineBanner(tone: BannerTone.danger, body: _error),
                  const SizedBox(height: 12),
                ],
                if (items == null)
                  _error != null
                      ? ErrorState(body: _error!, onRetry: _load, compact: true)
                      : const SkeletonRows(cols: 3, rows: 2)
                else if (items.isEmpty)
                  EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: l.providerNoPhotos,
                    subtitle: l.galEmptyBody,
                    actionLabel: l.galUploadFirst,
                    onAction: _progress == null ? _upload : null,
                  )
                else
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 120,
                          mainAxisSpacing: 9,
                          crossAxisSpacing: 9,
                        ),
                    children: [
                      for (final (i, url) in items.indexed)
                        _Tile(
                          url: url,
                          cover: i == 0,
                          hidden: _hidden.contains(url),
                          onDelete: () => _delete(url),
                        ),
                      // ponytail: backend caps at 20 (gallery.error.max_images).
                      if (items.length < 20)
                        DashedButton(
                          label: l.commonAdd,
                          vertical: true,
                          radius: 15,
                          padding: 0,
                          fontSize: 11,
                          iconSize: 20,
                          onTap: _progress == null ? _upload : null,
                        ),
                    ],
                  ),
                if (items != null && items.any(_hidden.contains)) ...[
                  const SizedBox(height: 14),
                  InlineBanner(
                    tone: BannerTone.warn,
                    icon: Icons.visibility_off_outlined,
                    title: l.galOneHidden,
                    body: l.galOneHiddenBody,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final double progress;
  final VoidCallback onCancel;
  const _UploadCard({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            spacing: 10,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.plum100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 16,
                  color: AppColors.plum700,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).galUploading,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: AppTextStyles.mono.copyWith(
                        fontSize: 11,
                        color: AppColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCancel,
                tooltip: AppLocalizations.of(context).galCancelUpload,
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.ink3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 130),
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: AppColors.cream,
                color: AppColors.plum700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String url;
  final bool cover, hidden;
  final VoidCallback onDelete;
  const _Tile({
    required this.url,
    required this.cover,
    required this.hidden,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.divider),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          if (hidden)
            Container(
              color: AppColors.plum900.withValues(alpha: .72),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 5,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 17,
                    color: AppColors.rose300,
                  ),
                  Text(
                    AppLocalizations.of(context).galHiddenByMod,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: 9.5,
                      height: 1.3,
                      color: AppColors.bone,
                    ),
                  ),
                ],
              ),
            ),
          if (cover && !hidden)
            PositionedDirectional(
              top: 6,
              start: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  AppLocalizations.of(context).galCover,
                  style: AppTextStyles.labelSm.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .36,
                    color: AppColors.plum700,
                  ),
                ),
              ),
            ),
          PositionedDirectional(
            top: 6,
            end: 6,
            child: Semantics(
              button: true,
              label: AppLocalizations.of(context).galDeletePhoto,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.plum900.withValues(alpha: .6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
