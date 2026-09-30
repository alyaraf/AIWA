import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/repositories/booking_repository.dart';

/// SOS banner stages on Tracking (flow-screens.jsx:357-376).
enum SosStage { none, alerting, notified, logged }

class LiveBookingState {
  final BookingEntity? booking;
  final String? loadError;

  /// Last failed action, shown inline; cleared by the next action.
  final String? actionError;
  final bool busy;
  final SosStage sos;

  /// Travel fee declined -> "No problem — no fee applied." screen.
  final bool declinedFee;

  const LiveBookingState({
    this.booking,
    this.loadError,
    this.actionError,
    this.busy = false,
    this.sos = SosStage.none,
    this.declinedFee = false,
  });

  LiveBookingState copyWith({
    BookingEntity? booking,
    String? loadError,
    String? actionError,
    bool? busy,
    SosStage? sos,
    bool? declinedFee,
  }) => LiveBookingState(
    booking: booking ?? this.booking,
    loadError: loadError,
    actionError: actionError,
    busy: busy ?? this.busy,
    sos: sos ?? this.sos,
    declinedFee: declinedFee ?? this.declinedFee,
  );
}

/// One booking seen by the customer: Tracking, Proposed time, Payment
/// confirm, Complaint, Rejected and Expired all read and act on it.
class LiveBookingCubit extends Cubit<LiveBookingState> {
  final BookingRepository _repo;
  final String bookingId;
  Timer? _poll;

  /// Where the user is for an SOS, or null. Injectable for tests.
  final Future<({double lat, double lng})?> Function() _locate;

  LiveBookingCubit(
    this._repo,
    this.bookingId, {
    BookingEntity? initial,
    Future<({double lat, double lng})?> Function()? locate,
  }) : _locate = locate ?? _deviceLocation,
       super(LiveBookingState(booking: initial));

  /// Last known fix, else a fresh one within 4 s. Never prompts for
  /// permission mid-emergency; any failure just means "no location".
  static Future<({double lat, double lng})?> _deviceLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final p =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 4),
          );
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }

  static const _live = {
    'PENDING',
    'ACCEPTED',
    'ON_THE_WAY',
    'ARRIVED',
    'IN_PROGRESS',
  };

  Future<void> load() async {
    final r = await _repo.getBookingDetail(bookingId);
    if (isClosed) return;
    r.fold(
      (f) => emit(state.copyWith(loadError: f.message)),
      (b) => emit(state.copyWith(booking: b)),
    );
  }

  /// Status is provider-driven.
  // ponytail: 15s polling of GET /bookings/{id}; swap for push/websocket
  // once the backend streams booking status.
  void startPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 15), (_) {
      final s = state.booking?.status;
      if (s == null || _live.contains(s)) load();
    });
  }

  /// Runs [call], stores the fresh booking; returns true on success.
  Future<bool> _act(
    Future<Either<Failure, BookingEntity>> Function() call,
  ) async {
    emit(state.copyWith(busy: true));
    final r = await call();
    if (isClosed) return false;
    return r.fold(
      (f) {
        emit(state.copyWith(busy: false, actionError: f.message));
        return false;
      },
      (b) {
        emit(state.copyWith(busy: false, booking: b));
        return true;
      },
    );
  }

  Future<bool> cancel(String reason) =>
      _act(() => _repo.cancelBooking(bookingId, reason: reason));

  Future<bool> reschedule(String date, String time) => _act(
    () => _repo.rescheduleBooking(
      bookingId: bookingId,
      newDate: date,
      newTime: time,
    ),
  );

  Future<bool> checkIn() => _act(() => _repo.checkIn(bookingId));

  Future<bool> respondToProposal(bool accept) =>
      _act(() => _repo.respondToProposal(bookingId, accept));

  Future<bool> respondToTravelFee(bool accept) async {
    final ok = await _act(() => _repo.respondToTravelFee(bookingId, accept));
    if (ok && !accept) emit(state.copyWith(declinedFee: true));
    return ok;
  }

  Future<bool> confirmPayment({required bool paid, String? reason}) => _act(
    () => _repo.confirmPayment(
      bookingId,
      paid: paid,
      providerId: state.booking?.providerId,
      reason: reason,
    ),
  );

  /// SOS with the user's location when one is available (it becomes the maps
  /// link in the support / trusted-contact SMS). A timed-out request may still
  /// have been recorded, so check before telling the user it failed (FE-31).
  Future<void> sos() async {
    emit(state.copyWith(sos: SosStage.alerting));
    final at = await _locate();
    final r = await _repo.sendSos(
      bookingId,
      latitude: at?.lat,
      longitude: at?.lng,
    );
    if (isClosed) return;
    var sent = r.isRight();
    if (!sent && r.fold((f) => f is NetworkFailure, (_) => false)) {
      final open = await _repo.hasOpenSos(bookingId);
      if (isClosed) return;
      sent = open.fold((_) => false, (o) => o);
    }
    emit(
      sent
          ? state.copyWith(sos: SosStage.notified)
          : state.copyWith(
              sos: SosStage.none,
              actionError: r.fold((f) => f.message, (_) => null),
            ),
    );
  }

  /// "I'm safe". The SOS event is already logged by [sos]; closing it has no
  /// endpoint yet, so the stage advances whatever the stub returns.
  Future<void> imSafe() async {
    await _repo.resolveSos(bookingId);
    if (!isClosed) emit(state.copyWith(sos: SosStage.logged));
  }

  /// tel: number for the call buttons, or null (error shown inline).
  Future<String?> maskedPhone() async {
    final r = await _repo.maskedPhone(bookingId);
    return r.fold((f) {
      if (!isClosed) emit(state.copyWith(actionError: f.message));
      return null;
    }, (n) => n);
  }

  Future<bool> submitComplaint(String category, String text) async {
    final b = state.booking;
    if (b == null) return false;
    emit(state.copyWith(busy: true));
    final r = await _repo.submitComplaint(
      bookingId: bookingId,
      providerId: b.providerId,
      category: category,
      description: text,
    );
    if (isClosed) return false;
    return r.fold(
      (f) {
        emit(state.copyWith(busy: false, actionError: f.message));
        return false;
      },
      (_) {
        emit(state.copyWith(busy: false));
        return true;
      },
    );
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}

/// Provides a [LiveBookingCubit] seeded with the booking passed as `extra`,
/// refreshed from GET /bookings/{id}.
class LiveBookingScope extends StatelessWidget {
  final String bookingId;
  final BookingEntity? booking;
  final bool poll;
  final Widget child;

  const LiveBookingScope({
    super.key,
    required this.bookingId,
    this.booking,
    this.poll = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final c = LiveBookingCubit(
        sl<BookingRepository>(),
        bookingId,
        initial: booking,
      )..load();
      if (poll) c.startPolling();
      return c;
    },
    child: child,
  );
}
