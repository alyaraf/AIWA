import 'dart:async';

import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/features/bookings/domain/entities/chat_message_entity.dart';
import 'package:aiwa_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/chat_cubit.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessageEntity _m(int id) => ChatMessageEntity(
  id: '$id',
  senderId: 1,
  message: 'm$id',
  removed: false,
  createdAt: DateTime(2026),
);

/// Records each getChat call's afterId; the thread grows by one per call.
class _Repo implements BookingRepository {
  final calls = <String?>[];
  int total = 2;

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getChat(
    String bookingId, {
    String? afterId,
  }) async {
    calls.add(afterId);
    final all = [for (var i = 1; i <= total; i++) _m(i)];
    total++;
    final after = afterId == null ? 0 : int.parse(afterId);
    return Right([for (final m in all) if (int.parse(m.id) > after) m]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// SA-12: answers arrive when the test says so, so requests can overlap.
class _SlowRepo implements BookingRepository {
  final loads = <Completer<Either<Failure, List<ChatMessageEntity>>>>[];
  final sends = <Completer<Either<Failure, ChatMessageEntity>>>[];

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getChat(String bookingId, {String? afterId}) {
    final c = Completer<Either<Failure, List<ChatMessageEntity>>>();
    loads.add(c);
    return c.future;
  }

  @override
  Future<Either<Failure, ChatMessageEntity>> sendChat(String bookingId, String text) {
    final c = Completer<Either<Failure, ChatMessageEntity>>();
    sends.add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// AU-10: the poll asks only for newer messages and reloads the whole thread
/// about once a minute.
void main() {
  testWidgets('a message sent while a full load is running is not dropped', (tester) async {
    final repo = _SlowRepo();
    final cubit = ChatCubit(repo, '5');
    await tester.pump();
    repo.loads[0].complete(Right([_m(1)]));
    await tester.pump();
    expect(cubit.state.messages!.map((m) => m.id), ['1']);

    final reload = cubit.load(); // a slow full load that started before the send
    await tester.pump();
    final sent = cubit.send('hi');
    await tester.pump();
    repo.sends[0].complete(Right(_m(2)));
    await sent;
    repo.loads[1].complete(Right([_m(1)])); // the load's answer predates message 2
    await reload;

    expect(cubit.state.messages!.map((m) => m.id), ['1', '2']);
    await cubit.close();
  });

  testWidgets('a message the poll already showed is not listed twice after send returns', (tester) async {
    final repo = _SlowRepo();
    final cubit = ChatCubit(repo, '5');
    await tester.pump();
    repo.loads[0].complete(Right([_m(1)]));
    await tester.pump();

    final sent = cubit.send('hi');
    await tester.pump(const Duration(seconds: 5)); // the poll runs while send is pending
    repo.loads[1].complete(Right([_m(2)])); // ...and already sees message 2
    await tester.pump();
    repo.sends[0].complete(Right(_m(2)));
    await sent;

    expect(cubit.state.messages!.map((m) => m.id), ['1', '2']);
    await cubit.close();
  });

  testWidgets('polls only for messages after the last one', (tester) async {
    final repo = _Repo();
    final cubit = ChatCubit(repo, '5');
    await tester.pump(); // first, full load
    expect(repo.calls, [null]);
    expect(cubit.state.messages!.map((m) => m.id), ['1', '2']);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(repo.calls.last, '2');
    expect(cubit.state.messages!.map((m) => m.id), ['1', '2', '3']);

    // Ticks 2…11 are incremental; tick 12 reloads everything.
    for (var i = 0; i < 11; i++) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    }
    expect(repo.calls.last, isNull);
    expect(repo.calls.where((c) => c == null).length, 2);
    final ids = cubit.state.messages!.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'no duplicates');
    await cubit.close();
  });
}
