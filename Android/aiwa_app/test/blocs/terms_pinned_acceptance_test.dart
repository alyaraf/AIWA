// M-07: consent is recorded for the version the person was shown, never for a newer one they did not read.
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements AuthRepository {
  _Repo(this.latest);
  String latest;
  final accepted = <String>[];

  @override
  Future<Either<Failure, TermsDoc>> latestTerms(String type) async =>
      Right((version: latest, content: 'text', contentAr: '', pdfUrl: null));

  @override
  Future<Either<Failure, void>> acceptTerms(String version) async {
    accepted.add(version);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('the shown version is the one accepted', () async {
    final repo = _Repo('1.1.0');
    final r = await acceptShownTerms(repo, type: 'PROVIDER_TERMS', shownVersion: '1.1.0');
    expect(r.isRight(), isTrue);
    expect(repo.accepted, ['1.1.0']);
  });

  test('a version published after the person read the terms is NOT accepted on their behalf', () async {
    final repo = _Repo('1.2.0'); // an admin published while they were signing up
    final r = await acceptShownTerms(repo, type: 'CUSTOMER_TERMS', shownVersion: '1.1.0');
    expect(r.fold((f) => f, (_) => null), isA<TermsChangedFailure>());
    expect(repo.accepted, isEmpty);
  });

  test('without a pinned version (an older flow) the latest is accepted as before', () async {
    final repo = _Repo('1.2.0');
    final r = await acceptShownTerms(repo, type: 'CUSTOMER_TERMS', shownVersion: null);
    expect(r.isRight(), isTrue);
    expect(repo.accepted, ['1.2.0']);
  });

  test('a failure to load the policy is passed on and nothing is accepted', () async {
    final repo = _FailingRepo();
    final r = await acceptShownTerms(repo, type: 'CUSTOMER_TERMS', shownVersion: '1.0.0');
    expect(r.fold((f) => f, (_) => null), isA<NetworkFailure>());
    expect(repo.accepted, isEmpty);
  });
}

class _FailingRepo extends _Repo {
  _FailingRepo() : super('x');

  @override
  Future<Either<Failure, TermsDoc>> latestTerms(String type) async => const Left(NetworkFailure());
}
