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

/// Where the user is for an SOS: when the fix was taken ([at]) and its
/// accuracy in metres travel with it, so support can judge it (CR-16).
typedef SosFix = ({double lat, double lng, DateTime? at, double? accuracy});

class LiveBookingState {
  final BookingEntity? booking;
  final String? loadError;

  /// Last failed action, shown inline; cleared by the next action.
  final String? actionError;
  final bool busy;
  final SosStage sos;

  /// What the SOS actually reached (R2-03); null until known.
  final SosReport? sosReport;

  /// The last SOS did not go out: Tracking offers a retry and the 122 hint.
  final bool sosFailed;

  /// Travel fee declined -> "No problem — no fee applied." screen.
  final bool declinedFee;

  const LiveBookingState({
    this.booking,
    this.loadError,
    this.actionError,
    this.busy = false,
    this.sos = SosStage.none,
    this.sosReport,
    this.sosFailed = false,
    this.declinedFee = false,
  });

  LiveBookingState copyWith({
    BookingEntity? booking,
    String? loadError,
    String? actionError,
    bool? busy,
    SosStage? sos,
    SosReport? sosReport,
    bool? sosFailed,
    bool? declinedFee,
  }) => LiveBookingState(
    booking: booking ?? this.booking,
    loadError: loadError,
    actionError: actionError,
    busy: busy ?? this.busy,
    sos: sos ?? this.sos,
    sosReport: sosReport ?? this.sosReport,
    sosFailed: sosFailed ?? this.sosFailed,
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
  final Future<SosFix?> Function() _locate;

  LiveBookingCubit(
    this._repo,
    this.bookingId, {
    BookingEntity? initial,
    Future<SosFix?> Function()? locate,
  }) : _locate = locate ?? _deviceLocation,
       super(LiveBookingState(booking: initial));

  /// A fresh fix within 4 s, else the last known one (which can be hours old
  /// and far away, so it is only the fallback: CR-16). Never prompts for
  /// permission mid-emergency; any failure just means "no location".
  static Future<SosFix?> _deviceLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      Position? p;
      try {
        p = await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 4),
        );
      } catch (_) {}
      p ??= await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      return (
        lat: p.latitude,
        lng: p.longitude,
        at: p.timestamp,
        accuracy: p.accuracy,
      );
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
    if (r.isRight() && state.sos == SosStage.none) await _restoreSos();
  }

  /// An SOS raised before this screen opened (or before the app restarted)
  /// may still be open: bring back its banner and "I'm safe" (CR-16).
  /// Otherwise it could only be closed by pressing SOS again, which re-alerts
  /// support. A failed read just leaves the page as it was.
  Future<void> _restoreSos() async {
    final report = (await _repo.sosReport(
      bookingId,
    )).fold((_) => null, (x) => x);
    if (isClosed || report == null || state.sos != SosStage.none) return;
    emit(
      state.copyWith(
        sos: SosStage.notified,
        sosReport: report,
        sosFailed: false,
      ),
    );
    if (report.contactsPending > 0) _followSosDelivery();
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
    emit(state.copyWith(sos: SosStage.alerting, sosFailed: false));
    try {
      final at = await _locate();
      final r = await _repo.sendSos(
        bookingId,
        latitude: at?.lat,
        longitude: at?.lng,
        locationTime: at?.at,
        locationAccuracy: at?.accuracy,
      );
      if (isClosed) return;
      // What reached whom comes from the backend's delivery records (R2-03).
      // After a timeout the SOS may still have been recorded (FE-31).
      final shouldCheck = r.isRight() || r.fold((f) => f is NetworkFailure, (_) => false);
      final report = shouldCheck
          ? (await _repo.sosReport(bookingId)).fold((_) => null, (x) => x)
          : null;
      if (isClosed) return;
      final sent = r.isRight() || report != null;
      emit(
        sent
            ? state.copyWith(sos: SosStage.notified, sosReport: report ?? const SosReport())
            : state.copyWith(
                sos: SosStage.none,
                sosFailed: true,
                actionError: r.fold((f) => f.message, (_) => null),
              ),
      );
      if (sent) _followSosDelivery();
    } catch (_) {
      // Whatever went wrong, never stay on "Alerting…": the button must come
      // back so the SOS can be raised again (CR-15).
      if (!isClosed) emit(state.copyWith(sos: SosStage.none, sosFailed: true));
    }
  }

  Timer? _sosPoll;

  /// Texts go out in the background; refresh the counts until none is pending.
  void _followSosDelivery({int tries = 15, Duration every = const Duration(seconds: 4)}) {
    _sosPoll?.cancel();
    var left = tries;
    _sosPoll = Timer.periodic(every, (t) async {
      if (isClosed || state.sos != SosStage.notified || --left < 0) {
        t.cancel();
        return;
      }
      final r = await _repo.sosReport(bookingId);
      if (isClosed) return;
      final report = r.fold((_) => null, (x) => x);
      if (report == null) return;
      emit(state.copyWith(sosReport: report));
      if (report.contactsPending == 0) t.cancel();
    });
  }

  /// "I'm safe": closes the SOS. Only says so when it was really closed.
  Future<void> imSafe() async {
    final r = await _repo.resolveSos(bookingId);
    if (isClosed) return;
    emit(
      r.isRight()
          ? state.copyWith(sos: SosStage.logged)
          : state.copyWith(actionError: r.fold((f) => f.message, (_) => null)),
    );
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
    _sosPoll?.cancel();
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
