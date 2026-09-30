import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_dashboard_usecase.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetDashboardUseCase getDashboard;
  final DashboardRepository _repository;

  DashboardBloc({
    required this.getDashboard,
    required this._repository,
  }) : super(DashboardInitial()) {
    on<DashboardLoadEvent>(_onLoad);
  }

  Future<void> _onLoad(
    DashboardLoadEvent event,
    Emitter<DashboardState> emit,
  ) async {
    // Refreshes keep the current content instead of flashing the skeleton.
    if (state is! DashboardLoaded) emit(DashboardLoading());
    final stats = await getDashboard();
    final pending = await _repository.getProviderBookings(
      status: 'PENDING',
      size: providerBookingsPageSize,
    );
    stats.fold(
      (f) => emit(DashboardError(f.message)),
      (s) => pending.fold(
        (f) => emit(DashboardError(f.message)),
        (p) => emit(DashboardLoaded(stats: s, pending: p.content)),
      ),
    );
  }
}
