import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

/// An active policy: version, EN/AR text and an optional PDF (TermsPolicyDto).
typedef TermsDoc = ({
  String version,
  String content,
  String contentAr,
  String? pdfUrl,
});

extension TermsDocText on TermsDoc {
  /// Arabic text for an Arabic UI when the policy has it, else English.
  String textFor(String localeName) =>
      localeName == 'ar' && contentAr.isNotEmpty ? contentAr : content;
}

/// The policy a role accepts (TermsController infers the same from the role).
String termsTypeFor({required bool provider}) =>
    provider ? 'PROVIDER_TERMS' : 'CUSTOMER_TERMS';

/// Records acceptance of the version the person was SHOWN ([shownVersion]), and only that one (audit M-07). If a newer
/// version went live since, nothing is recorded: acceptance of text they never saw would be meaningless, so the caller
/// sends them back to read the current one. [shownVersion] null (an older client flow) accepts the latest, as before.
Future<Either<Failure, void>> acceptShownTerms(
  AuthRepository repo, {
  required String type,
  required String? shownVersion,
}) async {
  final latest = await repo.latestTerms(type);
  return latest.fold((f) async => Left(f), (policy) {
    if (shownVersion != null && shownVersion != policy.version) {
      return Future.value(const Left(TermsChangedFailure()));
    }
    return repo.acceptTerms(shownVersion ?? policy.version);
  });
}

abstract class AuthRepository {
  Future<Either<Failure, Map<String, String>>> login({
    required String identifier,
    required String password,
  });

  Future<Either<Failure, Map<String, String>>> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required String role,
    String? gender,
    String? profileImageUrl,
    String? preferredLanguage,
  });

  Future<Either<Failure, void>> sendOtp({required String phone});

  Future<Either<Failure, void>> verifyOtp({
    required String phone,
    required String code,
  });

  /// Verify [code] (sent to the new [phone]) and switch the account to it.
  /// [currentPassword] is required by the backend (CR-05).
  Future<Either<Failure, void>> changePhone({
    required String phone,
    required String code,
    required String currentPassword,
  });

  /// Confirm the email waiting in pendingEmail with [code]; stores the fresh
  /// tokens (other sessions are signed out).
  Future<Either<Failure, void>> verifyEmail({required String code});

  Future<Either<Failure, UserEntity>> getCurrentUser();

  /// A changed [email] needs [currentPassword]; it stays pendingEmail until
  /// [verifyEmail].
  Future<Either<Failure, UserEntity>> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? profileImageUrl,
  });

  Future<Either<Failure, void>> updateLanguage({required String language});

  /// Forgot password. Phone only: the backend has no email reset yet.
  Future<Either<Failure, void>> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  });

  Future<Either<Failure, void>> uploadAvatar(String path);

  /// Provider sign-up, after register: business profile + staff.
  Future<Either<Failure, void>> createProviderProfile(
    Map<String, dynamic> profile, {
    List<String> staff = const [],
  });

  Future<Either<Failure, void>> uploadVerificationDocuments({
    required String idFront,
    required String idBack,
    required String selfie,
  });

  /// Latest active policy of [type] (CUSTOMER_TERMS / PROVIDER_TERMS):
  /// version, contentEn / contentAr and pdfUrl.
  Future<Either<Failure, TermsDoc>> latestTerms(
    String type,
  );

  Future<Either<Failure, void>> acceptTerms(String version);

  Future<Either<Failure, void>> updatePreferences({
    required double minKm,
    required double maxKm,
  });

  Future<Either<Failure, String>> refreshToken({required String refreshToken});
}
