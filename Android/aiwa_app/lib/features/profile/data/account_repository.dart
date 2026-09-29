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

  /// PUT /account/addresses/{id} — same body as add; isDefault=true makes it
  /// the only default.
  Future<Either<Failure, void>> updateAddress(
    String id, {
    required String label,
    required String addressLine,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) => _run(
    () => _api.put(
      ApiConstants.savedAddressById(id),
      data: {
        'label': label,
        'addressLine': addressLine,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'defaultAddress': ?isDefault,
      },
    ),
  );

  Future<Either<Failure, void>> deleteAddress(String id) =>
      _run(() => _api.delete(ApiConstants.savedAddressById(id)));

  // ── Account ────────────────────────────────────────────────────────

  Future<Either<Failure, void>> deleteAccount() =>
      _run(() => _api.delete(ApiConstants.account));

  /// Header stats: total bookings, saved providers and reviews written
  /// (each list's totalElements).
  Future<Either<Failure, ({int bookings, int favorites, int reviews})>>
  stats() => _run(() async {
    final res = await Future.wait([
      _api.get(ApiConstants.myBookings, queryParameters: {'size': 1}),
      _api.get(ApiConstants.savedProviders),
      _api.get(ApiConstants.myReviews, queryParameters: {'size': 1}),
    ]);
    return (
      bookings: (_data(res[0].data) as Map?)?['totalElements'] as int? ?? 0,
      favorites: (_data(res[1].data) as List?)?.length ?? 0,
      reviews: (_data(res[2].data) as Map?)?['totalElements'] as int? ?? 0,
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
  // /account/trusted-contacts — texted by SMS when you press SOS (max 5).

  static TrustedContact _contact(Map<String, dynamic> e) => (
    id: '${e['id']}',
    name: e['name'] as String? ?? '',
    phone: e['phone'] as String? ?? '',
    relationship: e['relationship'] as String? ?? '',
  );

  Future<Either<Failure, List<TrustedContact>>> trustedContacts() => _run(
    () async => [
      for (final e
          in _data((await _api.get(ApiConstants.trustedContacts)).data)
                  as List? ??
              const [])
        _contact(e as Map<String, dynamic>),
    ],
  );

  Future<Either<Failure, TrustedContact>> addTrustedContact({
    required String name,
    required String phone,
    required String relationship,
  }) => _run(
    () async => _contact(
      _data(
            (await _api.post(
              ApiConstants.trustedContacts,
              data: {
                'name': name,
                'phone': phone,
                if (relationship.isNotEmpty) 'relationship': relationship,
              },
            )).data,
          )
          as Map<String, dynamic>,
    ),
  );

  Future<Either<Failure, void>> removeTrustedContact(String id) =>
      _run(() => _api.delete(ApiConstants.trustedContactById(id)));
}
