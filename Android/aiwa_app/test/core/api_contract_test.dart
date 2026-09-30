// fromJson against payloads shaped like the backend DTOs in
// aiwa-backend/.../dto/response/ApiResponse.java.
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/bookings/data/models/booking_model.dart';
import 'package:aiwa_app/features/home/data/models/provider_summary_model.dart';
import 'package:aiwa_app/features/provider_dashboard/domain/repositories/dashboard_repository.dart';
import 'package:aiwa_app/features/providers/data/models/provider_detail_model.dart';
import 'package:flutter_test/flutter_test.dart';

// ProviderSummaryDto
const _summary = {
  'id': 12,
  'businessName': 'Nadia Studio',
  'address': 'Zamalek, Cairo',
  'latitude': 30.06,
  'longitude': 31.22,
  'primaryCategory': 'HAIR',
  'averageRating': 4.9,
  'totalReviews': 312,
  'verificationStatus': 'APPROVED',
  'ownerName': 'Nadia Hassan',
  'profileImageUrl': 'https://cdn.aiwa/p/12.jpg',
  'distanceKm': 1.2,
  'saved': true,
  'providerType': 'SHOP',
  'vacationMode': false,
  'offlineMode': false,
  'settlementPaused': false,
};

// UserDto (trimmed)
const _user = {
  'id': 5,
  'fullName': 'Salma Adel',
  'email': 'salma@example.com',
  'phone': '+201005558821',
  'role': 'CUSTOMER',
  'profileImageUrl': null,
  'active': true,
};

// BookingDto
const _booking = {
  'id': 88,
  'customer': _user,
  'provider': _summary,
  'service': {
    'id': 3,
    'name': 'Blowout',
    'price': 450,
    'durationMinutes': 45,
    'category': 'HAIR',
    'active': true,
  },
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'endTime': '13:15:00',
  'bookingType': 'SCHEDULED',
  'homeService': false,
  'status': 'PENDING',
  'paymentMethod': 'CASH',
  'totalPrice': 500,
  'notes': 'Ring the bell twice',
  'createdAt': '2026-05-18T09:00:00',
  'reviewed': false,
};

void main() {
  test('BookingDto', () {
    final b = BookingModel.fromJson(_booking);
    expect(b.id, '88');
    expect(b.providerId, '12');
    expect(b.providerName, 'Nadia Hassan');
    expect(b.displayProviderName, 'Nadia Studio');
    expect(b.providerAddress, 'Zamalek, Cairo');
    expect(b.providerImageUrl, 'https://cdn.aiwa/p/12.jpg');
    expect(b.scheduledDate, '2026-05-19');
    expect(b.scheduledTime, '12:30:00');
    expect(b.servicePrice, 500); // totalPrice wins over service.price
    expect(b.customerNote, 'Ring the bell twice');
    expect(b.customerName, 'Salma Adel');
  });

  test('ProviderDetailDto', () {
    final p = ProviderDetailModel.fromJson({
      'id': 12,
      'businessName': 'Nadia Studio',
      'bio': 'Cuts and colour.',
      'address': 'Zamalek, Cairo',
      'latitude': 30.06,
      'longitude': 31.22,
      'primaryCategory': 'HAIR',
      'averageRating': 4.9,
      'totalReviews': 312,
      'verificationStatus': 'APPROVED',
      'providerType': 'SHOP',
      'owner': {..._user, 'fullName': 'Nadia Hassan', 'phone': '+201001112222'},
      'services': [
        {
          'id': 3,
          'name': 'Blowout',
          'price': 450,
          'durationMinutes': 45,
          'active': false,
        },
      ],
      'availabilities': [],
      'galleryImages': ['https://cdn.aiwa/g/1.jpg'],
      'staffMembers': [
        {
          'id': 7,
          'providerId': 12,
          'fullName': 'Mona Ali',
          'title': 'Senior stylist',
          'active': true,
        },
        {'id': 8, 'providerId': 12, 'fullName': 'Gone Staff', 'active': false},
      ],
    });
    expect(p.displayName, 'Nadia Studio');
    expect(p.providerName, 'Nadia Hassan');
    expect(p.phone, '+201001112222');
    expect(p.categories, ['HAIR']);
    expect(p.isVerified, isTrue);
    expect(p.latitude, 30.06);
    expect(p.totalReviews, 312);
    expect(p.services.single.available, isFalse);
    expect(p.galleryImages, ['https://cdn.aiwa/g/1.jpg']);
    expect(p.isShop, isTrue);
    expect(p.staff.single.fullName, 'Mona Ali');
    expect(p.staff.single.title, 'Senior stylist');
  });

  test('ReviewDto author comes from `user`', () {
    final r = ReviewSummaryModel.fromJson({
      'id': 1,
      'user': _user,
      'rating': 5,
      'comment': 'Lovely',
      'quickTags': ['On time'],
      'direction': 'CUSTOMER_TO_PROVIDER',
      'hidden': false,
      'createdAt': '2026-05-01T10:00:00',
    });
    expect(r.customerName, 'Salma Adel');
    expect(r.rating, 5);
  });

  test('ProviderSummaryDto', () {
    final s = ProviderSummaryModel.fromJson(_summary);
    expect(s.ownerName, 'Nadia Hassan');
    expect(s.profileImageUrl, 'https://cdn.aiwa/p/12.jpg');
    expect(s.saved, isTrue);
    expect(s.isVerified, isTrue);
    expect(s.openNow, isTrue);
    expect(
      ProviderSummaryModel.fromJson({..._summary, 'offlineMode': true}).openNow,
      isFalse,
    );
  });

  test('DashboardDto', () {
    final d = DashboardStats.fromJson({
      'totalBookings': 40,
      'pendingBookings': 3,
      'confirmedBookings': 5,
      'completedBookings': 30,
      'totalRevenue': 12500.5,
      'averageRating': 4.8,
      'totalClients': 22,
      'todayBookings': [_booking],
    });
    expect(d.pendingBookings, 3);
    expect(d.confirmedBookings, 5);
    expect(d.totalRevenue, 12500.5);
    expect(d.totalClients, 22);
    expect(d.todayBookings.single.id, '88');
  });

  // PROV-02-F1: UserDto carries flat providerProfileId / providerStatus.
  test('UserDto provider approval gates the provider app', () {
    UserModel user(String? status) => UserModel.fromJson({
      ..._user,
      'role': 'PROVIDER',
      'providerProfileId': 12,
      'providerStatus': ?status,
    });
    expect(user('APPROVED').providerProfile!.isApproved, isTrue);
    expect(user('PENDING_VERIFICATION').providerProfile!.isApproved, isFalse);
    expect(user(null).providerProfile, isNull);
  });

  test('BookingDto provider-side fields', () {
    final b = BookingModel.fromJson({
      ..._booking,
      'customer': {..._user, 'bookingCount': 4},
      'savedAddress': {'id': 1, 'label': 'Home', 'addressLine': '14 Road 9'},
      'commissionAmount': 52.5,
    });
    expect(b.customerAddress, '14 Road 9');
    expect(b.customerBookingCount, 4);
    expect(b.commissionAmount, 52.5);
  });
}
