import 'package:dartz/dartz.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../bookings/domain/entities/saved_address_entity.dart';

typedef TrustedContact = ({
  String id,
  String name,
  String phone,
  String relationship,
});

/// Customer account endpoints: AccountController (/account), notification
/// preferences (/auth/me/notification-preferences) and /support/contact.
// ponytail: concrete class, no interface — one implementation.
class AccountRepository {
  final ApiClient _api;
  AccountRepository(this._api);

  static Future<Either<Failure, T>> _run<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } catch (_) {
      return const Left(ServerFailure('Something went wrong'));
    }
  }

  static dynamic _data(dynamic body) => body is Map ? body['data'] : null;

  // ── Saved addresses ────────────────────────────────────────────────

  Future<Either<Failure, List<SavedAddressEntity>>> addresses() => _run(
    () async => [
      for (final e
          in _data((await _api.get(ApiConstants.savedAddresses)).data)
                  as List? ??
              const [])
        SavedAddressEntity.fromJson(e as Map<String, dynamic>),
    ],
  );

  /// POST /account/addresses — SavedAddressRequest.
  Future<Either<Failure, void>> addAddress({
    required String label,
    required String addressLine,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) => _run(
    () => _api.post(
      ApiConstants.savedAddresses,
      data: {
        'label': label,
        'addressLine': addressLine,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'defaultAddress': isDefault,
      },
    ),
  );

  /// Backend gap: AccountController has no PUT /account/addresses/{id}.
  Future<Either<Failure, void>> updateAddress(String id) async =>
      const Left(NotSupportedFailure('Editing a saved address'));

  Future<Either<Failure, void>> deleteAddress(String id) =>
      _run(() => _api.delete(ApiConstants.savedAddressById(id)));

  // ── Account ────────────────────────────────────────────────────────

  Future<Either<Failure, void>> deleteAccount() =>
      _run(() => _api.delete(ApiConstants.account));

  /// Header stats: total bookings and saved providers. Reviews written by
  /// the customer have no endpoint, so that tile has no count.
  Future<Either<Failure, ({int bookings, int favorites})>> stats() =>
      _run(() async {
        final res = await Future.wait([
          _api.get(ApiConstants.myBookings, queryParameters: {'size': 1}),
          _api.get(ApiConstants.savedProviders),
        ]);
        return (
          bookings: (_data(res[0].data) as Map?)?['totalElements'] as int? ?? 0,
          favorites: (_data(res[1].data) as List?)?.length ?? 0,
        );
      });

  // ── Notification preferences (NotificationPreferencesDto) ──────────

  Future<Either<Failure, Map<String, dynamic>>> notificationPreferences() =>
      _run(
        () async =>
            _data((await _api.get(ApiConstants.meNotificationPreferences)).data)
                as Map<String, dynamic>,
      );

  /// PATCH with any of notifyPush / notifyEmail / notifySms / muteAll /
  /// quietHoursStart / quietHoursEnd ("HH:mm") / clearQuietHours.
  Future<Either<Failure, Map<String, dynamic>>> updateNotificationPreferences(
    Map<String, dynamic> patch,
  ) => _run(
    () async =>
        _data(
              (await _api.patch(
                ApiConstants.meNotificationPreferences,
                data: patch,
              )).data,
            )
            as Map<String, dynamic>,
  );

  // ── Support ────────────────────────────────────────────────────────

  /// SupportContactDto, or null when no WhatsApp line is configured.
  Future<Either<Failure, Map<String, dynamic>?>> supportContact() => _run(
    () async =>
        _data((await _api.get(ApiConstants.supportContact)).data)
            as Map<String, dynamic>?,
  );

  // ── Trusted contacts ───────────────────────────────────────────────
  // Backend gap: no trusted-contact endpoints exist yet.

  Future<Either<Failure, List<TrustedContact>>> trustedContacts() async =>
      const Left(NotSupportedFailure('Trusted contacts'));

  Future<Either<Failure, TrustedContact>> addTrustedContact({
    required String name,
    required String phone,
    required String relationship,
  }) async => const Left(NotSupportedFailure('Adding a trusted contact'));

  Future<Either<Failure, void>> removeTrustedContact(String id) async =>
      const Left(NotSupportedFailure('Removing a trusted contact'));
}
