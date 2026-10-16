import 'package:aiwa_app/core/router/app_router.dart';
import 'package:aiwa_app/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';

UserEntity _user({bool? upToDate, String? accepted}) => UserEntity(
  id: 1,
  fullName: 'Sara',
  role: 'CUSTOMER',
  active: true,
  preferredLanguage: 'EN',
  termsAccepted: accepted != null,
  acceptedTermsVersion: accepted,
  termsUpToDate: upToDate,
);

void main() {
  // Splash and Sign-in go() to landingFor, replacing anything pushed before:
  // the updated-terms screen has to be the landing itself.
  test('a user behind on the live terms lands on the re-accept screen', () {
    expect(
      AppRoutes.landingFor(_user(upToDate: false, accepted: '1.0')),
      AppRoutes.termsReaccept,
    );
  });

  test('up to date, or still in sign-up, lands on home', () {
    expect(
      AppRoutes.landingFor(_user(upToDate: true, accepted: '1.0')),
      AppRoutes.home,
    );
    expect(AppRoutes.landingFor(_user(upToDate: false)), AppRoutes.home);
  });
}
