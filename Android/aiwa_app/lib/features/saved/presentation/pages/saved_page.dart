import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/guest_locked_view.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../home/domain/entities/provider_summary_entity.dart';
import '../../../home/presentation/widgets/provider_card.dart';
import '../bloc/saved_bloc.dart';
import '../bloc/saved_event.dart';
import '../bloc/saved_state.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../shared/widgets/star_rating.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (a, b) => (a is AuthAuthenticated) != (b is AuthAuthenticated),
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return Scaffold(
            backgroundColor: AppColors.bone,
            body: Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: GuestLockedView(
                title: AppLocalizations.of(context).savedGuestTitle,
                body: AppLocalizations.of(context).savedGuestBody,
                icon: LucideIcons.heart,
              ),
            ),
          );
        }
        return const _SavedView();
      },
    );
  }
}

class _SavedView extends StatefulWidget {
  const _SavedView();

  @override
  State<_SavedView> createState() => _SavedViewState();
}

class _SavedViewState extends State<_SavedView> {
  late SavedBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<SavedBloc>();
    _bloc.add(SavedLoadEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColors.bone,
        body: CustomScrollView(
          physics: AiwaRefresh.physics,
          slivers: [
            AiwaRefresh(onRefresh: () async => _bloc.add(SavedLoadEvent())),
            SliverToBoxAdapter(
              child: PageTitle(
                eyebrow: AppLocalizations.of(context).savedEyebrow,
                title: AppLocalizations.of(context).tabSaved,
                bottom: 18,
                letterSpacing: 0,
              ),
            ),
            BlocConsumer<SavedBloc, SavedState>(
              bloc: _bloc,
              listenWhen: (_, s) => s is SavedLoaded && s.error != null,
              listener: (context, s) => showAiwaToast(
                context,
                AppLocalizations.of(context).error((s as SavedLoaded).error!),
              ),
              builder: (context, state) => _buildBody(state),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SavedState state) {
    const pad = EdgeInsets.symmetric(horizontal: AppTheme.gutter);
    final l = AppLocalizations.of(context);
    if (state is SavedError) {
      return SliverToBoxAdapter(
        child: ErrorState(
          body: l.error(state.message),
          onRetry: () => _bloc.add(SavedLoadEvent()),
        ),
      );
    }
    if (state is! SavedLoaded) {
      return const SliverPadding(
        padding: pad,
        sliver: SliverToBoxAdapter(child: SkeletonList(count: 3)),
      );
    }
    if (state.providers.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: LucideIcons.heart,
          tone: EmptyStateTone.rose,
          title: l.savedEmpty,
          subtitle: l.savedEmptyBody,
          actionLabel: l.savedBrowse,
          onAction: () => context.go(AppRoutes.search),
        ),
      );
    }
    return SliverPadding(
      padding: pad,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          if (i == state.providers.length) {
            return state.hasMore
                ? Center(
                    child: AiwaButton(
                      label: l.commonLoadMore,
                      variant: AiwaButtonVariant.ghost,
                      size: AiwaButtonSize.sm,
                      onPressed: () => _bloc.add(SavedLoadMoreEvent()),
                    ),
                  )
                : const SizedBox.shrink();
          }
          final p = state.providers[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SavedCard(
              provider: p,
              onOpen: () => context.push('/provider/${p.id}'),
              // Book again reopens the profile (service, staff, booking type).
              onBook: () => context.push('/provider/${p.id}'),
              onRemove: () => _bloc.add(SavedRemoveEvent(p.id.toString())),
            ),
          );
        }, childCount: state.providers.length + 1),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final ProviderSummaryEntity provider;
  final VoidCallback onOpen;
  final VoidCallback onBook;
  final VoidCallback onRemove;

  const _SavedCard({
    required this.provider,
    required this.onOpen,
    required this.onBook,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final rating = provider.averageRating;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        height: 110,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: CoverImage(
                url: provider.profileImageUrl,
                initial: provider.businessName,
                showInitial: true,
                colors: [AppColors.plum500, AppColors.plum900],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EyebrowLabel(
                          AppLocalizations.of(
                            context,
                          ).category(provider.primaryCategory),
                          fontSize: 10,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h4.copyWith(
                            fontSize: 18,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        AiwaStar(size: 11, color: AppColors.gold500),
                        const SizedBox(width: 3),
                        Text(
                          rating != null && rating > 0
                              ? rating.toStringAsFixed(1)
                              : AppLocalizations.of(context).providerNew,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.ink2,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onBook,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.plum100,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusPill,
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context).savedBookAgain,
                              style: AppTextStyles.labelSm.copyWith(
                                fontSize: AppTextStyles.fsMicroPlus,
                                fontWeight: FontWeight.w700,
                                color: AppColors.plum700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 20,
                  color: AppColors.rose500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
