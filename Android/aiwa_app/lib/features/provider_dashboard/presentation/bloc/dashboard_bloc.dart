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
    required DashboardRepository repository,
  })  : _repository = repository,
        super(DashboardInitial()) {
    on<DashboardLoadEvent>(_onLoad);
    on<DashboardFilterStatusEvent>(_onFilter);
    on<DashboardAcceptBookingEvent>(_onAccept);
    on<DashboardRejectBookingEvent>(_onReject);
    on<DashboardCompleteBookingEvent>(_onComplete);
    on<DashboardNoShowEvent>(_onNoShow);
    on<DashboardOnTheWayEvent>(_onOnTheWay);
    on<DashboardArrivedEvent>(_onArrived);
    on<DashboardInProgressEvent>(_onInProgress);
  }

  Future<void> _onLoad(
      DashboardLoadEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    final statsResult = await getDashboard();
    final bookingsResult = await _repository.getProviderBookings(
        status: 'PENDING', page: 0);
    statsResult.fold(
      (f) => emit(DashboardError(f.message)),
      (stats) => bookingsResult.fold(
        (f) => emit(DashboardError(f.message)),
        (paged) => emit(DashboardLoaded(
          stats: stats,
          bookings: paged.content,
          hasMore: paged.hasNextPage,
          filterStatus: 'PENDING',
        )),
      ),
    );
  }

  Future<void> _onFilter(
      DashboardFilterStatusEvent event, Emitter<DashboardState> emit) async {
    final current = state;
    if (current is! DashboardLoaded) return;
    final result = await _repository.getProviderBookings(
        status: event.status, page: 0);
    result.fold(
      (_) {},
      (paged) => emit(current.copyWith(
        bookings: paged.content,
        hasMore: paged.hasNextPage,
        filterStatus: event.status,
      )),
    );
  }

  Future<void> _onAccept(
      DashboardAcceptBookingEvent event,
      Emitter<DashboardState> emit) async {
    await _repository.acceptBooking(event.bookingId);
    add(DashboardLoadEvent());
  }

  Future<void> _onReject(
      DashboardRejectBookingEvent event,
      Emitter<DashboardState> emit) async {
    await _repository.rejectBooking(event.bookingId, event.reason);
    add(DashboardLoadEvent());
  }

  Future<void> _onComplete(
      DashboardCompleteBookingEvent event,
      Emitter<DashboardState> emit) async {
    await _repository.completeBooking(event.bookingId);
    add(DashboardLoadEvent());
  }

  Future<void> _onNoShow(
      DashboardNoShowEvent event, Emitter<DashboardState> emit) async {
    await _repository.markNoShow(event.bookingId);
    add(DashboardLoadEvent());
  }

  Future<void> _onOnTheWay(
      DashboardOnTheWayEvent event, Emitter<DashboardState> emit) async {
    await _repository.bookingOnTheWay(event.bookingId);
    add(DashboardLoadEvent());
  }

  Future<void> _onArrived(
      DashboardArrivedEvent event, Emitter<DashboardState> emit) async {
    await _repository.bookingArrived(event.bookingId);
    add(DashboardLoadEvent());
  }

  Future<void> _onInProgress(
      DashboardInProgressEvent event, Emitter<DashboardState> emit) async {
    await _repository.bookingInProgress(event.bookingId);
    add(DashboardLoadEvent());
  }
}
