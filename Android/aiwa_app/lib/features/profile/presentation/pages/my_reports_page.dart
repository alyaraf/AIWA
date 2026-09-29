import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../data/account_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// "My reports" under Help: the customer's complaints with their status and
/// the team's resolution note (GET /complaints/my, FE-24).
// ponytail: first page (20) only, add paging when someone files more.
class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final r = await sl<AccountRepository>().myComplaints();
    if (!mounted) return;
    setState(
      () => r.fold(
        (f) => _error = AppLocalizations.of(context).error(f.message),
        (items) => _items = items,
      ),
    );
  }

  String _status(AppLocalizations l, String? s) => switch (s) {
    'RESOLVED' || 'CLOSED' => l.reportStatusResolved,
    'UNDER_REVIEW' || 'ESCALATED' => l.reportStatusReview,
    _ => l.reportStatusOpen,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          ScreenHeader(
            eyebrow: l.supEyebrow,
            title: l.reportsTitle,
            onBack: () => context.pop(),
          ),
          if (_error != null)
            ErrorState(body: _error, onRetry: _load, compact: true)
          else if (items == null)
            const Padding(
              padding: EdgeInsets.all(AppTheme.gutter),
              child: ShimmerBox(height: 90),
            )
          else if (items.isEmpty)
            EmptyState(
              icon: LucideIcons.flag,
              title: l.reportsEmpty,
              compact: true,
            )
          else
            for (final c in items)
              Container(
                margin: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  12,
                  AppTheme.gutter,
                  0,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c['targetProviderName'] as String? ??
                                c['category'] as String? ??
                                '',
                            style: AppTextStyles.label,
                          ),
                        ),
                        Text(
                          _status(l, c['status'] as String?),
                          style: AppTextStyles.meta.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.plum700,
                          ),
                        ),
                      ],
                    ),
                    if (DateTime.tryParse('${c['createdAt']}') case final d?)
                      Text(
                        DateFormat.yMMMd(l.localeName).format(d),
                        style: AppTextStyles.meta,
                      ),
                    Text(
                      c['description'] as String? ?? '',
                      style: AppTextStyles.bodySm,
                    ),
                    if ((c['adminNotes'] as String?)?.isNotEmpty ?? false)
                      Text(
                        l.reportsResolution(c['adminNotes'] as String),
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.ink,
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
