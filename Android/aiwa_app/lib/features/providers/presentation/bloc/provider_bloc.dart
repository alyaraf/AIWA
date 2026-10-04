import '../../domain/repositories/provider_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/provider_detail_entity.dart';
import 'provider_event.dart';
import 'provider_state.dart';

class ProviderBloc extends Bloc<ProviderEvent, ProviderState> {
  final ProviderRepository providerRepository;

  /// Slots fetched so far. Kept outside the state because a slot request can
  /// finish before the provider detail does (handlers run concurrently).
  List<AvailabilitySlot> _slots = const [];

  ProviderBloc({
    required this.providerRepository,
  }) : super(ProviderInitial()) {
    on<ProviderLoadEvent>(_onLoad);
    on<ProviderToggleSaveEvent>(_onToggleSave);
    on<ProviderLoadSlotsEvent>(_onLoadSlots);
  }

  Future<void> _onLoad(
    ProviderLoadEvent event,
    Emitter<ProviderState> emit,
  ) async {
    emit(ProviderLoading());
    final detailResult = await providerRepository.getProviderDetail(event.providerId);
    await detailResult.fold((f) async => emit(ProviderError(f.message)), (
      provider,
    ) async {
      final savedResult = await providerRepository.isProviderSaved(event.providerId);
      final isSaved = savedResult.fold((_) => false, (s) => s);
      emit(
        ProviderLoaded(
          provider: provider,
          isSaved: isSaved,
          slots: _slots.isNotEmpty ? _slots : provider.availableSlots,
        ),
      );
    });
  }

  Future<void> _onToggleSave(
    ProviderToggleSaveEvent event,
    Emitter<ProviderState> emit,
  ) async {
    final current = state;
    if (current is! ProviderLoaded) return;
    final next = !current.isSaved;
    emit(current.copyWith(isSaved: next));
    final result = next
        ? await providerRepository.saveProvider(event.providerId)
        : await providerRepository.unsaveProvider(event.providerId);
    final latest = state;
    if (result.isLeft() && latest is ProviderLoaded) {
      emit(latest.copyWith(isSaved: !next));
    }
  }

  Future<void> _onLoadSlots(
    ProviderLoadSlotsEvent event,
    Emitter<ProviderState> emit,
  ) async {
    final result = await providerRepository.getAvailableSlots(
      event.providerId,
      event.serviceId,
      event.date,
      staffId: event.staffId,
    );
    final fetched = result.fold((_) => <AvailabilitySlot>[], (s) => s);
    final fmt = DateFormat('yyyy-MM-dd');
    // Replace any slots we already had for the requested date.
    _slots = [
      ..._slots.where((s) => fmt.format(s.date) != event.date),
      ...fetched,
    ];
    final current = state;
    if (current is ProviderLoaded) {
      emit(current.copyWith(slots: _slots));
    }
  }
}
