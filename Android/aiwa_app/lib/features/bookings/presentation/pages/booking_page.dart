import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/dashed_button.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../../shared/widgets/slot_conflict_sheet.dart';
import '../../../providers/domain/entities/provider_detail_entity.dart';
import '../../../providers/presentation/bloc/provider_bloc.dart';
import '../../../providers/presentation/bloc/provider_event.dart';
import '../../../providers/presentation/bloc/provider_state.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/saved_address_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import 'package:aiwa_app/l10n/l10n.dart';

class BookingPage extends StatefulWidget {
  final String providerId;
  final String? initialServiceId;
  final String? staffId;

  /// 'now' (Book Now, BOOK-09) or 'scheduled'.
  final String mode;

  const BookingPage({
    super.key,
    required this.providerId,
    this.initialServiceId,
    this.staffId,
    this.mode = 'scheduled',
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late BookingBloc _bookingBloc;
  late ProviderBloc _providerBloc;
  final _noteController = TextEditingController();
  final _dayFmt = DateFormat('yyyy-MM-dd');

  final _scroll = ScrollController();
  final _dayPickerKey = GlobalKey();

  ServiceEntity? _selectedService;
  late DateTime _selectedDate;
  String? _selectedTime;

  /// 'Where' (BOOK-10/11). Book Now always comes to the customer.
  bool _homeService = true;
  List<SavedAddressEntity>? _addresses;
  String? _addressId;

  /// Set when the slot-conflict sheet rebooks, for the 'Rebooked for' toast.
  String? _rebookedTime;

  late final List<DateTime> _dates;

  bool get _isNow => widget.mode == 'now';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dates = List.generate(14, (i) => today.add(Duration(days: i)));
    _selectedDate = today;
    _bookingBloc = sl<BookingBloc>();
    _providerBloc = sl<ProviderBloc>();
    _providerBloc.add(ProviderLoadEvent(widget.providerId));
    _loadAddresses();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ponytail: plain Future + setState; phase 6's AddressBloc can replace it.
  Future<void> _loadAddresses() async {
    final r = await sl<BookingRepository>().getSavedAddresses();
    if (!mounted) return;
    final list = r.fold((_) => const <SavedAddressEntity>[], (a) => a);
    setState(() {
      _addresses = list;
      if (!list.any((a) => a.id == _addressId)) {
        _addressId =
            (list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull)
                ?.id;
      }
    });
  }

  Future<void> _addAddress() async {
    await context.push(AppRoutes.addressNew);
    _loadAddresses();
  }

  /// /bookings/slots needs the service, so slots load once one is picked.
  void _loadSlots() {
    final service = _selectedService;
    if (service == null) return;
    _providerBloc.add(
      ProviderLoadSlotsEvent(
        widget.providerId,
        service.id,
        _dayFmt.format(_selectedDate),
      ),
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
    });
    _loadSlots();
  }

  void _onServiceSelected(ServiceEntity service) {
    setState(() {
      _selectedService = service;
      _selectedTime = null;
    });
    _loadSlots();
  }

  bool get _toAddress => _isNow || _homeService;

  bool get _canSubmit =>
      _selectedService != null &&
      (_isNow || _selectedTime != null) &&
      (!_toAddress || _addressId != null);

  void _submit() {
    _bookingBloc.add(
      BookingCreateEvent(
        providerId: widget.providerId,
        serviceId: _selectedService!.id,
        scheduledDate: _isNow ? null : _dayFmt.format(_selectedDate),
        scheduledTime: _isNow ? null : _selectedTime,
        staffId: widget.staffId,
        bookNow: _isNow,
        homeService: _toAddress,
        savedAddressId: _toAddress ? _addressId : null,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  /// '13:30' / '13:30:00' -> '1:30 PM' (SlotConflictSheet chips).
  String _ampm(String t) => DateFormat(
    'h:mm a',
    Localizations.localeOf(context).toString(),
  ).format(DateFormat('HH:mm').parse(t.substring(0, 5)));

  /// BOOK-13: offer what's still free that day, rebook on pick.
  Future<void> _onSlotTaken() async {
    final taken = _selectedTime;
    final s = _providerBloc.state;
    final day = _dayFmt.format(_selectedDate);
    final alternatives =
        s is! ProviderLoaded
              ? <String>[]
              : ({
                  for (final x in s.slots)
                    if (_dayFmt.format(x.date) == day) ...x.times,
                }..remove(taken)).toList()
          ..sort();
    _loadSlots();
    final picked = await showSlotConflictSheet(
      context,
      providerName: s is ProviderLoaded
          ? s.provider.displayName
          : AppLocalizations.of(context).bookingThisProvider,
      alternatives: alternatives.take(3).toList(),
      labelOf: _ampm,
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _selectedTime = null);
      final ctx = _dayPickerKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: AppTheme.dur3,
          curve: AppTheme.easeSoft,
        );
      }
      return;
    }
    setState(() {
      _selectedTime = picked;
      _rebookedTime = picked;
    });
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bookingBloc),
        BlocProvider.value(value: _providerBloc),
      ],
      child: BlocListener<BookingBloc, BookingState>(
        bloc: _bookingBloc,
        listener: (ctx, state) {
          if (state is BookingCreated) {
            final rebooked = _rebookedTime;
            context.go(
              '/booking-confirmed/${state.booking.id}',
              extra: state.booking,
            );
            showAiwaToast(
              context,
              rebooked != null
                  ? AppLocalizations.of(
                      context,
                    ).bookingRebookedFor(_ampm(rebooked))
                  : _isNow
                  ? AppLocalizations.of(context).bookingProviderOnWay
                  : AppLocalizations.of(context).bookingPlacedWaiting,
            );
          } else if (state is BookingError && state.slotTaken && !_isNow) {
            _onSlotTaken();
          }
          // Other BookingErrors show inline above Confirm (_buildCtaBar).
        },
        child: BlocConsumer<ProviderBloc, ProviderState>(
          bloc: _providerBloc,
          listener: (ctx, state) {
            if (state is ProviderLoaded && _selectedService == null) {
              final available = state.provider.services
                  .where((s) => s.available)
                  .toList();
              ServiceEntity? pick;
              for (final s in available) {
                if (s.id == widget.initialServiceId) pick = s;
              }
              pick ??= available.length == 1 ? available.first : null;
              if (pick != null) _onServiceSelected(pick);
            }
            // BOOK-08-F9: preselect the first free slot (screens.jsx:332).
            if (state is ProviderLoaded && !_isNow && _selectedTime == null) {
              final day = _dayFmt.format(_selectedDate);
              final free = [
                for (final s in state.slots)
                  if (_dayFmt.format(s.date) == day) ...s.times,
              ]..sort();
              if (free.isNotEmpty) setState(() => _selectedTime = free.first);
            }
          },
          builder: (ctx, state) {
            return Scaffold(
              backgroundColor: AppColors.bone,
              body: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenHeader(
                      eyebrow: AppLocalizations.of(context).bookingBookService,
                      title: AppLocalizations.of(context).bookingPickTime,
                      onBack: () => context.pop(),
                    ),
                  ),
                  if (state is ProviderLoaded)
                    SliverToBoxAdapter(child: _buildForm(state))
                  else if (state is ProviderError)
                    SliverToBoxAdapter(
                      child: ErrorState(
                        body: AppLocalizations.of(context).error(state.message),
                        onRetry: () => _providerBloc.add(
                          ProviderLoadEvent(widget.providerId),
                        ),
                      ),
                    )
                  else
                    const SliverPadding(
                      padding: EdgeInsets.all(AppTheme.gutter),
                      sliver: SliverToBoxAdapter(child: SkeletonList(count: 3)),
                    ),
                ],
              ),
              bottomNavigationBar: state is ProviderLoaded
                  ? _buildCtaBar()
                  : null,
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(ProviderLoaded state) {
    final p = state.provider;
    final services = p.services.where((s) => s.available).toList();
    final day = state.slots.where(
      (s) => _dayFmt.format(s.date) == _dayFmt.format(_selectedDate),
    );
    final free = {for (final s in day) ...s.times};
    final times = {...free, for (final s in day) ...s.booked}.toList()..sort();
    final l = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        14,
        AppTheme.gutter,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(provider: p, service: _selectedService),
          if (services.length > 1 || _selectedService == null) ...[
            const SizedBox(height: 22),
            EyebrowLabel(l.bookingService),
            const SizedBox(height: 10),
            ...services.map(
              (s) => Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: _ServiceOption(
                  service: s,
                  selected: _selectedService?.id == s.id,
                  onTap: () => _onServiceSelected(s),
                ),
              ),
            ),
          ],
          // Book Now: the backend picks today + the next free slot.
          if (!_isNow) ...[
            const SizedBox(height: 22),
            EyebrowLabel(
              l.bookingDateMonth(
                DateFormat('MMMM yyyy', l.localeName).format(_selectedDate),
              ),
              key: _dayPickerKey,
            ),
            const SizedBox(height: 10),
            // 14-day horizon, sized so 5 chips fill the row (screens.jsx:370).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final d in _dates)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: d == _dates.last ? 0 : 8,
                      ),
                      child: _DayChip(
                        date: d,
                        width:
                            (MediaQuery.sizeOf(context).width -
                                2 * AppTheme.gutter -
                                4 * 8) /
                            5,
                        selected:
                            _dayFmt.format(d) == _dayFmt.format(_selectedDate),
                        onTap: () => _onDateSelected(d),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            EyebrowLabel(l.bookingAvailableSlots),
            const SizedBox(height: 10),
            if (times.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l.bookingNoSlots,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.ink3),
                ),
              )
            else
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.9,
                children: times
                    .map(
                      (t) => _SlotChip(
                        time: t,
                        available: free.contains(t),
                        selected: _selectedTime == t,
                        onTap: () => setState(() => _selectedTime = t),
                      ),
                    )
                    .toList(),
              ),
          ],
          const SizedBox(height: 22),
          EyebrowLabel(l.bookingWhere),
          const SizedBox(height: 10),
          if (_isNow)
            InlineBanner(
              tone: BannerTone.plum,
              icon: Icons.home_outlined,
              body: l.bookingNowAddressNote,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _WhereOption(
                    label: l.bookingAtMyAddress,
                    icon: Icons.home_outlined,
                    selected: _homeService,
                    onTap: () => setState(() => _homeService = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WhereOption(
                    label: l.bookingAtSalon,
                    icon: Icons.storefront_outlined,
                    selected: !_homeService,
                    onTap: () => setState(() => _homeService = false),
                  ),
                ),
              ],
            ),
          if (_toAddress) ...[
            const SizedBox(height: 10),
            if (_addresses == null)
              const ShimmerBox(width: double.infinity, height: 58)
            else
              for (final a in _addresses!)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8),
                  child: _AddressRow(
                    address: a,
                    selected: a.id == _addressId,
                    onTap: () => setState(() => _addressId = a.id),
                  ),
                ),
            DashedButton(
              label: l.bookingAddAddress,
              onTap: _addAddress,
              radius: 12,
              padding: 10,
              fontSize: 12.5,
              iconSize: 14,
            ),
          ],
          const SizedBox(height: 22),
          EyebrowLabel(l.bookingPayment),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.gold100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.money_rounded,
                    size: 18,
                    color: AppColors.gold700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.bookingCashOnVisitTitle,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.bookingCashOnVisitSub,
                        style: AppTextStyles.micro.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.success500,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AiwaTextField(
            controller: _noteController,
            label: l.bookingNoteLabel,
            optional: true,
            placeholder: l.bookingNotePlaceholder,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCtaBar() {
    final price = _selectedService?.price;
    final l = AppLocalizations.of(context);
    return StickyBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(l.bookingTotalCash, style: AppTextStyles.meta),
              ),
              Text(
                price != null ? l.egp(price) : '—',
                style: AppTextStyles.price,
              ),
            ],
          ),
          const SizedBox(height: 10),
          BlocBuilder<BookingBloc, BookingState>(
            bloc: _bookingBloc,
            builder: (ctx, state) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state is BookingError && !(state.slotTaken && !_isNow)) ...[
                  InlineBanner(
                    tone: BannerTone.danger,
                    icon: Icons.error_outline_rounded,
                    body: l.error(state.message),
                    compact: true,
                  ),
                  const SizedBox(height: 10),
                ],
                AiwaButton(
                  label: _selectedService == null
                      ? l.bookingChooseService
                      : !_isNow && _selectedTime == null
                      ? l.bookingChooseTime
                      : _toAddress && _addressId == null
                      ? l.bookingChooseAddress
                      : l.bookingConfirm,
                  onPressed: _canSubmit ? _submit : null,
                  loading: state is BookingLoading,
                  fullWidth: true,
                  size: AiwaButtonSize.lg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ProviderDetailEntity provider;
  final ServiceEntity? service;

  const _SummaryCard({required this.provider, this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          AiwaAvatar(
            name: provider.displayName,
            size: 44,
            verified: provider.isVerified,
            imageUrl: provider.profileImageUrl,
            palette: AiwaAvatar.paletteFor(provider.id),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(fontSize: 17, height: 1.1),
                ),
                const SizedBox(height: 3),
                Text(
                  service != null
                      ? '${service!.name} · ${AppLocalizations.of(context).durationLabel(service!.durationMinutes)}'
                      : AppLocalizations.of(context).bookingChooseServiceBelow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (service != null)
            Text(
              AppLocalizations.of(context).egp(service!.price),
              style: AppTextStyles.h4.copyWith(fontSize: 18),
            ),
        ],
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  final ServiceEntity service;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceOption({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum100 : AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.plum700 : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: AppTextStyles.label.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).durationMinutes(service.durationMinutes),
                    style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Text(
              AppLocalizations.of(context).egp(service.price),
              style: AppTextStyles.label.copyWith(color: AppColors.plum900),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_rounded, size: 16, color: AppColors.plum700),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.date,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.paper : AppColors.plum900;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum700 : AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.divider,
          ),
        ),
        child: Column(
          children: [
            Text(
              DateFormat(
                'EEE',
                Localizations.localeOf(context).toString(),
              ).format(date).toUpperCase(),
              style: AppTextStyles.labelSm.copyWith(
                fontSize: 11,
                letterSpacing: 1.1,
                color: fg.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat(
                'd',
                Localizations.localeOf(context).toString(),
              ).format(date),
              style: AppTextStyles.h3.copyWith(color: fg, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final String time;
  final bool available;
  final bool selected;
  final VoidCallback onTap;

  const _SlotChip({
    required this.time,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Backend returns HH:mm or HH:mm:ss — show HH:mm.
    final label = time.length >= 5 ? time.substring(0, 5) : time;
    return GestureDetector(
      onTap: available ? onTap : null,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.plum700
              : available
              ? AppColors.paper
              : AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 14,
            color: selected
                ? AppColors.paper
                : available
                ? AppColors.ink
                : AppColors.ink4,
            decoration: available ? null : TextDecoration.lineThrough,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// 'At my address' / 'At the salon' (screens.jsx:409-417).
class _WhereOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _WhereOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum700 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppColors.plum700,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved address row (screens.jsx:422-433).
class _AddressRow extends StatelessWidget {
  final SavedAddressEntity address;
  final bool selected;
  final VoidCallback onTap;

  const _AddressRow({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = address.label.toLowerCase();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 1.5,
            color: selected ? AppColors.plum700 : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.plum700,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                label == 'work'
                    ? Icons.work_outline_rounded
                    : label == 'home'
                    ? Icons.home_outlined
                    : Icons.place_outlined,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).addressLabel(address.label),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    address.addressLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 16, color: AppColors.plum700),
          ],
        ),
      ),
    );
  }
}
