// M-05: provider sign-up can be resumed. Every step is safe to repeat, and the app is told by the server how far the
// provider got, so a restart does not strand them or claim documents were received that never were.
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Remote implements AuthRemoteDataSource {
  bool hasProfile = false;
  final calls = <String>[];
  final staff = <String>[];
  String? failStaffNamed;

  @override
  Future<UserModel> getCurrentUser() async => UserModel.fromJson({
    'id': 1,
    'fullName': 'Nadia',
    'role': 'PROVIDER',
    if (hasProfile) 'providerProfileId': 12,
    if (hasProfile) 'providerStatus': 'PENDING_VERIFICATION',
  });

  @override
  Future<void> createProviderProfile(Map<String, dynamic> profile) async {
    calls.add('createProfile');
    hasProfile = true; // committed on the server
  }

  @override
  Future<List<String>> staffNames(int providerId) async => List.of(staff);

  @override
  Future<void> addStaff(String fullName) async {
    calls.add('addStaff:$fullName');
    if (fullName == failStaffNamed) {
      throw const NetworkException();
    }
    staff.add(fullName);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _Remote remote;
  late AuthRepositoryImpl repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    remote = _Remote();
    repo = AuthRepositoryImpl(remote, SecureStorage(const FlutterSecureStorage()));
  });

  test('a retry after a failed staff step does not create the profile again and adds only the missing staff', () async {
    remote.failStaffNamed = 'Dina';

    final first = await repo.createProviderProfile({'businessName': 'Studio'}, staff: ['Mona', 'Dina', 'Rania']);
    expect(first.isLeft(), isTrue); // profile committed, 'Mona' added, 'Dina' failed
    expect(remote.calls, ['createProfile', 'addStaff:Mona', 'addStaff:Dina']);

    remote.calls.clear();
    remote.failStaffNamed = null;
    final retry = await repo.createProviderProfile({'businessName': 'Studio'}, staff: ['Mona', 'Dina', 'Rania']);

    expect(retry.isRight(), isTrue);
    expect(remote.calls, ['addStaff:Dina', 'addStaff:Rania']); // no second profile POST, no duplicate Mona
    expect(remote.staff, ['Mona', 'Dina', 'Rania']);
  });

  test('running the whole step again after it fully succeeded changes nothing', () async {
    await repo.createProviderProfile({'businessName': 'Studio'}, staff: ['Mona']);
    remote.calls.clear();

    final again = await repo.createProviderProfile({'businessName': 'Studio'}, staff: ['mona ', 'MONA']);

    expect(again.isRight(), isTrue);
    expect(remote.calls, isEmpty); // existing profile, staff compared case-insensitively and trimmed
  });

  test('blank staff names are ignored', () async {
    final r = await repo.createProviderProfile({'businessName': 'Studio'}, staff: ['', '  ', 'Mona']);
    expect(r.isRight(), isTrue);
    expect(remote.calls, ['createProfile', 'addStaff:Mona']);
  });

  test('the onboarding stage from the server survives the offline cache round trip', () {
    for (final stage in ['NO_PROFILE', 'NEEDS_DOCUMENTS', 'SUBMITTED', null]) {
      final user = UserModel.fromJson({'id': 1, 'fullName': 'N', 'role': 'PROVIDER', 'providerOnboarding': stage});
      expect(user.providerOnboarding, stage);
      expect(UserModel.fromJson(user.toJson()).providerOnboarding, stage);
    }
  });
}
