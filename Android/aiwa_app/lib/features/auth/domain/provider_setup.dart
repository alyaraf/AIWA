import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import 'repositories/auth_repository.dart';

/// What the last steps of a provider sign-up still have to send once the account exists (audit follow-up to M-05).
///
/// It is written to secure storage so that killing the app between two steps does not lose the business details,
/// the staff list, the radius or the picked ID photos. It deliberately holds NO secret: never a password, an OTP, a
/// phone number, an e-mail address or a token (the account already exists and is signed in; those belong to the
/// sign-in, not to the setup). Photos are kept as local file paths and checked again before they are sent.
class ProviderSetupCheckpoint {
  /// The account this belongs to; a checkpoint of another account is ignored and deleted.
  final String userId;

  /// How many of [ProviderSetupStep]s are finished (they are safe to repeat; this only saves work).
  final int done;
  final double minKm;
  final double maxKm;
  final String language;
  final String? termsVersion;
  final String termsType;
  final String? gender;
  final Map<String, dynamic> profile;
  final List<String> staff;
  final String? idFront;
  final String? idBack;
  final String? selfie;

  const ProviderSetupCheckpoint({
    required this.userId,
    this.done = 0,
    required this.minKm,
    required this.maxKm,
    required this.language,
    required this.termsVersion,
    required this.termsType,
    this.gender,
    required this.profile,
    this.staff = const [],
    this.idFront,
    this.idBack,
    this.selfie,
  });

  ProviderSetupCheckpoint withDone(int n) => ProviderSetupCheckpoint(
    userId: userId,
    done: n,
    minKm: minKm,
    maxKm: maxKm,
    language: language,
    termsVersion: termsVersion,
    termsType: termsType,
    gender: gender,
    profile: profile,
    staff: staff,
    idFront: idFront,
    idBack: idBack,
    selfie: selfie,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'done': done,
    'minKm': minKm,
    'maxKm': maxKm,
    'language': language,
    'termsVersion': termsVersion,
    'termsType': termsType,
    'gender': gender,
    'profile': profile,
    'staff': staff,
    'idFront': idFront,
    'idBack': idBack,
    'selfie': selfie,
  };

  String encode() => jsonEncode(toJson());

  /// null for anything that is not a well-formed checkpoint (a corrupt or older value is simply "no checkpoint").
  static ProviderSetupCheckpoint? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return ProviderSetupCheckpoint(
        userId: j['userId'] as String,
        done: (j['done'] as num?)?.toInt() ?? 0,
        minKm: (j['minKm'] as num).toDouble(),
        maxKm: (j['maxKm'] as num).toDouble(),
        language: j['language'] as String? ?? 'en',
        termsVersion: j['termsVersion'] as String?,
        termsType: j['termsType'] as String? ?? 'PROVIDER_TERMS',
        gender: j['gender'] as String?,
        profile: Map<String, dynamic>.from(j['profile'] as Map),
        staff: [for (final s in (j['staff'] as List? ?? const [])) s as String],
        idFront: j['idFront'] as String?,
        idBack: j['idBack'] as String?,
        selfie: j['selfie'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// The three document photos are still on this phone.
  bool documentsPresent([bool Function(String path)? exists]) {
    final ok = exists ?? (String p) => File(p).existsSync();
    return [idFront, idBack, selfie].every((p) => p != null && p.isNotEmpty && ok(p));
  }
}

/// The post-registration steps, in order. Every one is safe to repeat (M-05): the profile step asks the server what
/// it already has and sends only what is missing.
enum ProviderSetupStep { terms, preferences, profileAndStaff, documents }

/// Runs the steps from `checkpoint.done` on. [onProgress] is called after each finished step (the caller persists the
/// new count). Returns the failure that stopped it, or null when everything is done. [acceptTerms] lets the sign-up
/// page route a changed policy back to the terms screen.
Future<Failure?> runProviderSetup(
  AuthRepository repo,
  ProviderSetupCheckpoint checkpoint, {
  Future<Either<Failure, void>> Function()? acceptTerms,
  FutureOr<void> Function(int done)? onProgress,
  bool Function(String path)? fileExists,
  bool provider = true,
}) async {
  final steps = <ProviderSetupStep, Future<Either<Failure, void>> Function()>{
    ProviderSetupStep.terms:
        acceptTerms ??
        () => acceptShownTerms(
          repo,
          type: checkpoint.termsType,
          shownVersion: checkpoint.termsVersion,
        ),
    ProviderSetupStep.preferences: () =>
        repo.updatePreferences(minKm: checkpoint.minKm, maxKm: checkpoint.maxKm),
    ProviderSetupStep.profileAndStaff: () =>
        repo.createProviderProfile(checkpoint.profile, staff: checkpoint.staff),
    ProviderSetupStep.documents: () async {
      if (!checkpoint.documentsPresent(fileExists)) {
        return const Left(DocumentsMissingFailure());
      }
      return repo.uploadVerificationDocuments(
        idFront: checkpoint.idFront!,
        idBack: checkpoint.idBack!,
        selfie: checkpoint.selfie!,
      );
    },
  };
  // A customer's sign-up ends after the preferences; the profile and documents are the provider's.
  final order = provider
      ? ProviderSetupStep.values
      : const [ProviderSetupStep.terms, ProviderSetupStep.preferences];
  var done = checkpoint.done;
  while (done < order.length) {
    final result = await steps[order[done]]!();
    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) return failure;
    done++;
    await onProgress?.call(done);
  }
  return null;
}

/// The ID photos picked earlier are gone (the cache was cleared, or the app was reinstalled): they have to be picked again.
class DocumentsMissingFailure extends Failure {
  const DocumentsMissingFailure() : super('The ID photos are no longer on this phone');
}
