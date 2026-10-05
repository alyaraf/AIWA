import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// S-08: the check behind the release-build guard in main.dart.
void main() {
  test('accepts an https API base with a host', () {
    expect(ApiConstants.isSecureBaseUrl('https://api.aiwa.app/api'), isTrue);
    expect(ApiConstants.isSecureBaseUrl('https://staging.aiwa.app:8443/api'), isTrue);
  });

  test('refuses the emulator default, plain http, a missing value and a bare scheme', () {
    expect(ApiConstants.isSecureBaseUrl('http://10.0.2.2:8080/api'), isFalse);
    expect(ApiConstants.isSecureBaseUrl('http://api.aiwa.app/api'), isFalse);
    expect(ApiConstants.isSecureBaseUrl(''), isFalse);
    expect(ApiConstants.isSecureBaseUrl('https://'), isFalse);
    expect(ApiConstants.isSecureBaseUrl('api.aiwa.app/api'), isFalse);
  });

  test('the checked-in default stays the debug emulator address, which release builds refuse', () {
    // Debug/dev keep the emulator default; a release build without API_BASE_URL must not pass.
    expect(ApiConstants.isSecureBaseUrl('http://10.0.2.2:8080/api'), isFalse);
  });
}
