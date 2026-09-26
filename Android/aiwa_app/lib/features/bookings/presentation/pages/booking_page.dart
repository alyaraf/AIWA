import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_avatar.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/loading_shimmer.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../../providers/domain/entities/provider_detail_entity.dart';
import '../../../providers/presentation/bloc/provider_bloc.dart';
import '../../../providers/presentation/bloc/provider_event.dart';
import '../../../providers/presentation/bloc/provider_state.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';

class BookingPage extends StatefulWidget {
  final String providerId;
  final String? initialServiceId;

  const BookingPage({
    super.key,
    required this.providerId,
    this.initialServiceId,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late BookingBloc _bookingBloc;
  late ProviderBloc _providerBloc;
  final _noteController = TextEditingController();
  final _dayFmt = DateFormat('yyyy-MM-dd');

  ServiceEntity? _selectedService;
  late DateTime _selectedDate;
  String? _selectedTime;

  late final List<DateTime> _dates;

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
    _loadSlots(today);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _loadSlots(DateTime date) {
    _providerBloc.add(
      ProviderLoadSlotsEvent(widget.providerId, _dayFmt.format(date)),
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
    });
    _loadSlots(date);
  }

  bool get _canSubmit => _selectedService != null && _selectedTime != null;

  void _submit() {
    _bookingBloc.add(
      BookingCreateEvent(
        providerId: widget.providerId,
        serviceId: _selectedService!.id,
        scheduledDate: _dayFmt.format(_selectedDate),
        scheduledTime: _selectedTime!,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
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
            context.go(
              '/booking-confirmed/${state.booking.id}',
              extra: state.booking,
            );
          } else if (state is BookingError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
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
              if (pick != null) setState(() => _selectedService = pick);
            }
          },
          builder: (ctx, state) {
            return Scaffold(
              backgroundColor: AppColors.bone,
              body: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ScreenHeader(
                      eyebrow: 'Book a service',
                      title: 'Pick a time',
                      onBack: () => context.pop(),
                    ),
                  ),
                  if (state is ProviderLoaded)
                    SliverToBoxAdapter(child: _buildForm(state))
                  else if (state is ProviderError)
                    SliverToBoxAdapter(
                      child: ErrorState(
                        body: state.message,
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
    final times =
        state.slots
            .where(
              (s) => _dayFmt.format(s.date) == _dayFmt.format(_selectedDate),
            )
            .expand((s) => s.times)
            .toSet()
            .toList()
          ..sort();

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
            const EyebrowLabel('Service'),
            const SizedBox(height: 10),
            ...services.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ServiceOption(
                  service: s,
                  selected: _selectedService?.id == s.id,
                  onTap: () => setState(() => _selectedService = s),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          EyebrowLabel(
            'Date · ${DateFormat('MMMM yyyy').format(_selectedDate)}',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _dates[i];
                return _DayChip(
                  date: d,
                  selected: _dayFmt.format(d) == _dayFmt.format(_selectedDate),
                  onTap: () => _onDateSelected(d),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          const EyebrowLabel('Available slots'),
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
                'No free slots on this day — try another date.',
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
                      selected: _selectedTime == t,
                      onTap: () => setState(() => _selectedTime = t),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 22),
          const EyebrowLabel('Payment'),
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
                    Icons.payments_outlined,
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
                        'Cash on visit',
                        style: AppTextStyles.label.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pay the provider directly after your service',
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
            label: 'Note for the provider',
            optional: true,
            placeholder: 'Any special requests…',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildCtaBar() {
    final price = _selectedService?.price;
    return StickyBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Total · cash', style: AppTextStyles.meta)),
              Text(
                price != null
                    ? 'EGP ${NumberFormat.decimalPattern('en').format(price.round())}'
                    : '—',
                style: AppTextStyles.price,
              ),
            ],
          ),
          const SizedBox(height: 10),
          BlocBuilder<BookingBloc, BookingState>(
            bloc: _bookingBloc,
            builder: (ctx, state) => AiwaButton(
              label: _selectedService == null
                  ? 'Choose a service'
                  : _selectedTime == null
                  ? 'Choose a time'
                  : 'Confirm booking',
              onPressed: _canSubmit ? _submit : null,
              loading: state is BookingLoading,
              fullWidth: true,
              size: AiwaButtonSize.lg,
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
                      ? '${service!.name} · ${service!.durationMinutes} min'
                      : 'Choose a service below',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (service != null)
            Text(
              'EGP ${NumberFormat.decimalPattern('en').format(service!.price.round())}',
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
                    '${service.durationMinutes} min',
                    style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Text(
              'EGP ${NumberFormat.decimalPattern('en').format(service.price.round())}',
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
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.date,
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
        width: 58,
        decoration: BoxDecoration(
          color: selected ? AppColors.plum700 : AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.divider,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE').format(date).toUpperCase(),
              style: AppTextStyles.labelSm.copyWith(
                fontSize: 11,
                letterSpacing: 1.1,
                color: fg.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('d').format(date),
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
  final bool selected;
  final VoidCallback onTap;

  const _SlotChip({
    required this.time,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Backend returns HH:mm or HH:mm:ss — show HH:mm.
    final label = time.length >= 5 ? time.substring(0, 5) : time;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.plum700 : AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            fontSize: 14,
            color: selected ? AppColors.paper : AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
