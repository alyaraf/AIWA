import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/saved_repository.dart';
import 'saved_event.dart';
import 'saved_state.dart';

class SavedBloc extends Bloc<SavedEvent, SavedState> {
  final SavedRepository _repository;
  int _page = 0;

  SavedBloc({
    required this._repository,
  }) : super(SavedInitial()) {
    on<SavedLoadEvent>(_onLoad);
    on<SavedLoadMoreEvent>(_onLoadMore);
    on<SavedRemoveEvent>(_onRemove);
  }

  Future<void> _onLoad(SavedLoadEvent event, Emitter<SavedState> emit) async {
    emit(SavedLoading());
    _page = 0;
    final result = await _repository.getSavedProviders(page: 0);
    result.fold(
      (f) => emit(SavedError(f.message)),
      (paged) => emit(
        SavedLoaded(providers: paged.content, hasMore: paged.hasNextPage),
      ),
    );
  }

  Future<void> _onLoadMore(
    SavedLoadMoreEvent event,
    Emitter<SavedState> emit,
  ) async {
    final current = state;
    if (current is! SavedLoaded || !current.hasMore) return;
    _page++;
    final result = await _repository.getSavedProviders(page: _page);
    result.fold(
      (_) {},
      (paged) => emit(
        current.copyWith(
          providers: [...current.providers, ...paged.content],
          hasMore: paged.hasNextPage,
        ),
      ),
    );
  }

  Future<void> _onRemove(
    SavedRemoveEvent event,
    Emitter<SavedState> emit,
  ) async {
    // Optimistic: drop it now, restore it if the server says no.
    final before = state;
    if (before is SavedLoaded) {
      emit(
        before.copyWith(
          providers: before.providers
              .where((p) => p.id.toString() != event.providerId)
              .toList(),
        ),
      );
    }
    final result = await _repository.removeProvider(event.providerId);
    result.fold((f) {
      if (before is SavedLoaded) emit(before.copyWith(error: f.message));
    }, (_) {});
  }
}
