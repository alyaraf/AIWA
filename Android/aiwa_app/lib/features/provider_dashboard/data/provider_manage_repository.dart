import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';

typedef Json = Map<String, dynamic>;

/// Signed-in provider's ProviderProfile id (AuthBloc user.providerProfile).
String providerIdOf(BuildContext context) {
  final s = context.read<AuthBloc>().state;
  return s is AuthAuthenticated ? '${s.user.providerProfile?.id ?? 0}' : '0';
}

/// Provider self-management: profile, services, availability, mode,
/// settlement, gallery, reviews and staff. Payloads stay as backend JSON
/// (ProviderDetailDto, ServiceDto, AvailabilityDto, …) — field names match
/// aiwa-backend ApiResponse.java.
// ponytail: concrete class on raw JSON maps, no entities — one consumer each.
class ProviderManageRepository {
  final ApiClient _api;
  ProviderManageRepository(this._api);

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

  static dynamic _data(Response r) => r.data is Map ? r.data['data'] : null;

  /// GET /providers/{id} — ProviderDetailDto: services (active only),
  /// availabilities, staffMembers, galleryImages, vacationMode,
  /// travelBufferMinutes, averageRating, totalReviews…
  Future<Either<Failure, Json>> detail(String providerId) => _run(
    () async =>
        _data(await _api.get(ApiConstants.providerProfile(providerId))) as Json,
  );

  /// PUT /provider/profile. The backend overwrites every field, so callers
  /// pass the current [detail] merged with their changes.
  Future<Either<Failure, Json>> updateProfile(Json detail) => _run(
    () async =>
        _data(
              await _api.put(
                ApiConstants.myProviderProfile,
                data: {
                  'businessName': detail['businessName'],
                  'bio': detail['bio'],
                  'address': detail['address'],
                  'latitude': detail['latitude'],
                  'longitude': detail['longitude'],
                  'providerType': detail['providerType'],
                  'primaryCategory': detail['primaryCategory'],
                  'travelBufferMinutes': detail['travelBufferMinutes'],
                },
              ),
            )
            as Json,
  );

  /// PATCH /provider/mode/travel-buffer?minutes= (0–60). Narrow on purpose (audit M-06): the buffer stepper used to
  /// send the whole business profile through PUT /provider/profile, which put back an older name, bio or address if
  /// they had been edited elsewhere since the Schedule screen loaded.
  Future<Either<Failure, void>> setTravelBuffer(int minutes) => _run(
    () => _api.patch(
      ApiConstants.providerTravelBuffer,
      queryParameters: {'minutes': minutes},
    ),
  );

  /// PATCH /provider/mode/travel-fee — null/0 clears the fee.
  Future<Either<Failure, void>> setTravelFee(num? amount) => _run(
    () => _api.patch(
      ApiConstants.providerTravelFee,
      queryParameters: amount == null || amount == 0
          ? {'clear': true}
          : {'amount': amount},
    ),
  );

  /// PATCH /provider/mode/service-radius?km= — how far you travel for home service.
  Future<Either<Failure, void>> setServiceRadius(int km) => _run(
    () => _api.patch(
      ApiConstants.providerServiceRadius,
      queryParameters: {'km': km},
    ),
  );

  /// PATCH /provider/mode?vacationMode=
  Future<Either<Failure, void>> setVacation(bool on) => _run(
    () => _api.patch(
      ApiConstants.providerMode,
      queryParameters: {'vacationMode': on},
    ),
  );

  // ── Services (ServiceRequest) ──────────────────────────────────────

  Future<Either<Failure, void>> saveService({
    String? id,
    required String name,
    required num price,
    required int durationMinutes,
    required bool fixed,
  }) => _run(() {
    final body = {
      'name': name,
      'price': price,
      'durationMinutes': durationMinutes,
      'pricingType': fixed ? 'FIXED' : 'STARTS_AT',
    };
    return id == null
        ? _api.post(ApiConstants.providerServiceCreate, data: body)
        : _api.put(ApiConstants.providerServiceUpdate(id), data: body);
  });

  /// DELETE deactivates; the public list then drops it.
  Future<Either<Failure, void>> hideService(String id) =>
      _run(() => _api.delete(ApiConstants.providerServiceDelete(id)));

  // ── Availability (AvailabilityRequest) ─────────────────────────────

  /// Upserts one weekday (per staff member when [staffMemberId] is set).
  Future<Either<Failure, Json>> saveDay({
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    required bool available,
    Object? staffMemberId,
  }) => _run(
    () async =>
        _data(
              await _api.post(
                ApiConstants.providerAvailabilityCreate,
                data: {
                  'staffMemberId': ?staffMemberId,
                  'dayOfWeek': dayOfWeek,
                  'startTime': startTime,
                  'endTime': endTime,
                  'available': available,
                },
              ),
            )
            as Json,
  );

  // ── Settlement (SettlementSummaryDto) ──────────────────────────────

  Future<Either<Failure, Json>> settlement() => _run(
    () async => _data(await _api.get(ApiConstants.providerSettlement)) as Json,
  );

  Future<Either<Failure, Json>> settle() => _run(
    () async =>
        _data(await _api.patch(ApiConstants.providerSettlementPay)) as Json,
  );

  // ── Gallery (List<String> of image paths) ──────────────────────────

  Future<Either<Failure, List<String>>> gallery(String providerId) => _run(
    () async => [
      for (final e
          in _data(await _api.get(ApiConstants.providerGallery(providerId)))
                  as List? ??
              const [])
        '$e',
    ],
  );

  /// GET /provider/gallery-images — your own photos, including the ones
  /// moderation hid from the public gallery (GalleryImageDto: id, url, hidden).
  Future<Either<Failure, ({List<String> urls, Set<String> hidden})>>
  ownGallery() => _run(() async {
    final urls = <String>[];
    final hidden = <String>{};
    for (final e
        in _data(await _api.get(ApiConstants.providerGalleryImages)) as List? ??
            const []) {
      final m = e as Json;
      final url = '${m['url']}';
      urls.add(url);
      if (m['hidden'] == true) hidden.add(url);
    }
    return (urls: urls, hidden: hidden);
  });

  Future<Either<Failure, List<String>>> uploadPhoto(
    String path, {
    required ProgressCallback onProgress,
    required CancelToken cancel,
  }) => _run(() async {
    final r = await _api.postForm(
      ApiConstants.providerGalleryUpload,
      formData: FormData.fromMap({'image': await MultipartFile.fromFile(path)}),
      onSendProgress: onProgress,
      cancelToken: cancel,
    );
    return [for (final e in _data(r) as List? ?? const []) '$e'];
  });

  Future<Either<Failure, List<String>>> deletePhoto(String url) =>
      _run(() async {
        final r = await _api.delete(
          ApiConstants.providerGalleryUpload,
          queryParameters: {'imageUrl': url},
        );
        return [for (final e in _data(r) as List? ?? const []) '$e'];
      });

  // ── Reviews (ReviewDto page) ───────────────────────────────────────

  Future<Either<Failure, List<Json>>> reviews(String providerId) =>
      _run(() async {
        final d = _data(
          await _api.get(
            ApiConstants.providerReviews(providerId),
            // ponytail: one big page; paginate if providers pass ~200 reviews.
            queryParameters: {'page': 0, 'size': 200},
          ),
        );
        return [
          for (final e in (d is List ? d : d['content'] as List)) e as Json,
        ];
      });

  /// POST /provider/reviews/{id}/reply — public reply; sending again edits it.
  Future<Either<Failure, void>> replyToReview(String id, String text) => _run(
    () => _api.post(ApiConstants.providerReviewReply(id), data: {'reply': text}),
  );

  // ── Staff (StaffMemberRequest) ─────────────────────────────────────

  Future<Either<Failure, void>> addStaff({
    required String fullName,
    String? title,
    String? skills,
  }) => _run(
    () => _api.post(
      ApiConstants.providerStaff,
      data: {'fullName': fullName, 'title': title, 'skills': skills},
    ),
  );

  /// PUT /provider/staff/{id}. Send title and phone every time: the backend
  /// overwrites them. serviceIds [] = performs every service.
  Future<Either<Failure, void>> updateStaff(String id, Json body) =>
      _run(() => _api.put(ApiConstants.providerStaffById(id), data: body));
}
