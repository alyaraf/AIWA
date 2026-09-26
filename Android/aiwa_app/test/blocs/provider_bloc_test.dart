import 'dart:async';

import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/features/providers/domain/entities/provider_detail_entity.dart';
import 'package:aiwa_app/features/providers/domain/repositories/provider_repository.dart';
import 'package:aiwa_app/features/providers/domain/usecases/check_saved_usecase.dart';
import 'package:aiwa_app/features/providers/domain/usecases/get_provider_detail_usecase.dart';
import 'package:aiwa_app/features/providers/domain/usecases/get_provider_slots_usecase.dart';
import 'package:aiwa_app/features/providers/domain/usecases/save_provider_usecase.dart';
import 'package:aiwa_app/features/providers/presentation/bloc/provider_bloc.dart';
import 'package:aiwa_app/features/providers/presentation/bloc/provider_event.dart';
import 'package:aiwa_app/features/providers/presentation/bloc/provider_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

const _provider = ProviderDetailEntity(
  id: '1',
  providerName: 'Nadia',
  businessName: 'Nadia Studio',
  email: 'nadia@example.com',
  phone: '+201005558821',
  categories: ['HAIR'],
  averageRating: 4.9,
  totalReviews: 312,
  totalBookings: 40,
  isVerified: true,
  isActive: true,
);

class _FakeProviderRepository implements ProviderRepository {
  /// Completes the detail request; tests can hold it open.
  Completer<void> detailGate = Completer<void>()..complete();
  final Map<String, List<AvailabilitySlot>> slotsByDate = {};
  bool slotsFail = false;
  bool saved = false;
  final List<String> saveCalls = [];

  @override
  Future<Either<Failure, ProviderDetailEntity>> getProviderDetail(
    String providerId,
  ) async {
    await detailGate.future;
    return const Right(_provider);
  }

  @override
  Future<Either<Failure, List<AvailabilitySlot>>> getAvailableSlots(
    String providerId,
    String date,
  ) async {
    if (slotsFail) return const Left(ServerFailure('boom'));
    return Right(slotsByDate[date] ?? const []);
  }

  @override
  Future<Either<Failure, bool>> isProviderSaved(String providerId) async =>
      Right(saved);

  @override
  Future<Either<Failure, void>> saveProvider(String providerId) async {
    saveCalls.add('save:$providerId');
    saved = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unsaveProvider(String providerId) async {
    saveCalls.add('unsave:$providerId');
    saved = false;
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ServiceEntity>>> getProviderServices(
    String providerId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<ReviewSummaryEntity>>> getProviderReviews(
    String providerId, {
    int page = 0,
    int size = 10,
  }) async => const Right([]);
}

ProviderBloc _bloc(ProviderRepository repo) => ProviderBloc(
  getProviderDetail: GetProviderDetailUseCase(repo),
  saveProvider: SaveProviderUseCase(repo),
  checkSaved: CheckSavedUseCase(repo),
  getSlots: GetProviderSlotsUseCase(repo),
);

AvailabilitySlot _slot(String date, List<String> times) =>
    AvailabilitySlot(date: DateTime.parse(date), times: times);

Future<ProviderLoaded> _nextLoaded(
  ProviderBloc bloc,
  bool Function(ProviderLoaded s) test,
) async {
  final current = bloc.state;
  if (current is ProviderLoaded && test(current)) return current;
  return await bloc.stream
      .where((s) => s is ProviderLoaded && test(s))
      .cast<ProviderLoaded>()
      .first
      .timeout(const Duration(seconds: 2));
}

void main() {
  late _FakeProviderRepository repo;
  late ProviderBloc bloc;

  setUp(() {
    repo = _FakeProviderRepository();
    bloc = _bloc(repo);
  });

  tearDown(() => bloc.close());

  test('loads the provider detail and saved flag', () async {
    repo.saved = true;
    bloc.add(const ProviderLoadEvent('1'));

    final loaded = await _nextLoaded(bloc, (_) => true);
    expect(loaded.provider.displayName, 'Nadia Studio');
    expect(loaded.isSaved, isTrue);
  });

  test('slot request after load fills the time grid', () async {
    repo.slotsByDate['2026-10-01'] = [
      _slot('2026-10-01', ['10:00', '10:30']),
    ];
    bloc.add(const ProviderLoadEvent('1'));
    await _nextLoaded(bloc, (_) => true);

    bloc.add(const ProviderLoadSlotsEvent('1', '2026-10-01'));
    final loaded = await _nextLoaded(bloc, (s) => s.slots.isNotEmpty);

    expect(loaded.slots.single.times, ['10:00', '10:30']);
  });

  test('slots that arrive before the detail are not lost', () async {
    // Booking page fires both events at once; the slot handler can win.
    repo.detailGate = Completer<void>();
    repo.slotsByDate['2026-10-01'] = [
      _slot('2026-10-01', ['12:00']),
    ];

    bloc.add(const ProviderLoadEvent('1'));
    bloc.add(const ProviderLoadSlotsEvent('1', '2026-10-01'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    repo.detailGate.complete();

    final loaded = await _nextLoaded(bloc, (s) => s.slots.isNotEmpty);
    expect(loaded.slots.single.times, ['12:00']);
  });

  test('changing date replaces only that day', () async {
    repo.slotsByDate['2026-10-01'] = [
      _slot('2026-10-01', ['10:00']),
    ];
    repo.slotsByDate['2026-10-02'] = [
      _slot('2026-10-02', ['11:00']),
    ];
    bloc.add(const ProviderLoadEvent('1'));
    await _nextLoaded(bloc, (_) => true);

    bloc.add(const ProviderLoadSlotsEvent('1', '2026-10-01'));
    await _nextLoaded(bloc, (s) => s.slots.length == 1);
    bloc.add(const ProviderLoadSlotsEvent('1', '2026-10-02'));
    final both = await _nextLoaded(bloc, (s) => s.slots.length == 2);

    expect(both.slots.expand((s) => s.times), containsAll(['10:00', '11:00']));

    // Re-fetching day 1 with new availability replaces it, no duplicates.
    repo.slotsByDate['2026-10-01'] = [
      _slot('2026-10-01', ['15:00']),
    ];
    bloc.add(const ProviderLoadSlotsEvent('1', '2026-10-01'));
    final refreshed = await _nextLoaded(
      bloc,
      (s) => s.slots.expand((x) => x.times).contains('15:00'),
    );
    expect(refreshed.slots.expand((s) => s.times).toList()..sort(), [
      '11:00',
      '15:00',
    ]);
  });

  test('a failed slot request leaves the page usable (no slots)', () async {
    repo.slotsFail = true;
    bloc.add(const ProviderLoadEvent('1'));
    await _nextLoaded(bloc, (_) => true);

    bloc.add(const ProviderLoadSlotsEvent('1', '2026-10-01'));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = bloc.state as ProviderLoaded;
    expect(state.slots, isEmpty);
  });

  test('toggle save calls save then unsave', () async {
    bloc.add(const ProviderLoadEvent('1'));
    await _nextLoaded(bloc, (_) => true);

    bloc.add(const ProviderToggleSaveEvent('1'));
    await _nextLoaded(bloc, (s) => s.isSaved);
    bloc.add(const ProviderToggleSaveEvent('1'));
    await _nextLoaded(bloc, (s) => !s.isSaved);

    expect(repo.saveCalls, ['save:1', 'unsave:1']);
  });
}
