import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/provider_detail_entity.dart';
import '../../domain/usecases/check_saved_usecase.dart';
import '../../domain/usecases/get_provider_detail_usecase.dart';
import '../../domain/usecases/get_provider_slots_usecase.dart';
import '../../domain/usecases/save_provider_usecase.dart';
import 'provider_event.dart';
import 'provider_state.dart';

class ProviderBloc extends Bloc<ProviderEvent, ProviderState> {
  final GetProviderDetailUseCase getProviderDetail;
  final SaveProviderUseCase saveProvider;
  final CheckSavedUseCase checkSaved;
  final GetProviderSlotsUseCase getSlots;

  /// Slots fetched so far. Kept outside the state because a slot request can
  /// finish before the provider detail does (handlers run concurrently).
  List<AvailabilitySlot> _slots = const [];

  ProviderBloc({
    required this.getProviderDetail,
    required this.saveProvider,
    required this.checkSaved,
    required this.getSlots,
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
    final detailResult = await getProviderDetail(event.providerId);
    await detailResult.fold((f) async => emit(ProviderError(f.message)), (
      provider,
    ) async {
      final savedResult = await checkSaved(event.providerId);
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
    if (current.isSaved) {
      await saveProvider.unsave(event.providerId);
      emit(current.copyWith(isSaved: false));
    } else {
      await saveProvider.save(event.providerId);
      emit(current.copyWith(isSaved: true));
    }
  }

  Future<void> _onLoadSlots(
    ProviderLoadSlotsEvent event,
    Emitter<ProviderState> emit,
  ) async {
    final result = await getSlots(event.providerId, event.date);
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
