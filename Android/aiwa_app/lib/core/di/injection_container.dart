import '../../features/provider_dashboard/data/provider_manage_repository.dart';
import '../../features/profile/data/account_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../storage/secure_storage.dart';

// Auth
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/send_otp_usecase.dart';
import '../../features/auth/domain/usecases/verify_otp_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/update_profile_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Home
import '../../features/home/data/datasources/home_remote_datasource.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_nearby_providers_usecase.dart';
import '../../features/home/domain/usecases/search_providers_usecase.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';

// Providers
import '../../features/providers/data/datasources/provider_remote_datasource.dart';
import '../../features/providers/data/repositories/provider_repository_impl.dart';
import '../../features/providers/domain/repositories/provider_repository.dart';
import '../../features/providers/domain/usecases/get_provider_detail_usecase.dart';
import '../../features/providers/domain/usecases/save_provider_usecase.dart';
import '../../features/providers/domain/usecases/check_saved_usecase.dart';
import '../../features/providers/domain/usecases/get_provider_slots_usecase.dart';
import '../../features/providers/presentation/bloc/provider_bloc.dart';

// Bookings
import '../../features/bookings/data/datasources/booking_remote_datasource.dart';
import '../../features/bookings/data/repositories/booking_repository_impl.dart';
import '../../features/bookings/domain/repositories/booking_repository.dart';
import '../../features/bookings/domain/usecases/create_booking_usecase.dart';
import '../../features/bookings/domain/usecases/get_my_bookings_usecase.dart';
import '../../features/bookings/domain/usecases/cancel_booking_usecase.dart';
import '../../features/bookings/presentation/bloc/booking_bloc.dart';

// Notifications
import '../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/get_notifications_usecase.dart';
import '../../features/notifications/domain/usecases/get_unread_count_usecase.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';

// Reviews
import '../../features/reviews/data/datasources/review_remote_datasource.dart';
import '../../features/reviews/data/repositories/review_repository_impl.dart';
import '../../features/reviews/domain/repositories/review_repository.dart';
import '../../features/reviews/domain/usecases/submit_review_usecase.dart';
import '../../features/reviews/presentation/bloc/review_bloc.dart';

// Saved
import '../../features/saved/data/datasources/saved_remote_datasource.dart';
import '../../features/saved/data/repositories/saved_repository_impl.dart';
import '../../features/saved/domain/repositories/saved_repository.dart';
import '../../features/saved/domain/usecases/get_saved_providers_usecase.dart';
import '../../features/saved/presentation/bloc/saved_bloc.dart';

// Provider Dashboard
import '../../features/provider_dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../features/provider_dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/provider_dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/provider_dashboard/domain/usecases/get_dashboard_usecase.dart';
import '../../features/provider_dashboard/presentation/bloc/dashboard_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // External
  sl.registerSingleton<FlutterSecureStorage>(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );

  // Core
  sl.registerSingleton<SecureStorage>(
    SecureStorage(sl<FlutterSecureStorage>()),
  );
  sl.registerSingleton<ApiClient>(ApiClient(sl<SecureStorage>()));
  sl.registerFactory(() => AccountRepository(sl<ApiClient>()));
  sl.registerFactory(() => ProviderManageRepository(sl<ApiClient>()));

  // Auth
  sl.registerFactory<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<ApiClient>()),
  );
  // ponytail: every domain repository interface has exactly one *Impl, drop the abstract classes unless a fake/second impl is needed
  sl.registerFactory<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>(), sl<SecureStorage>()),
  );
  // ponytail: all 21 usecases are one-line pass-throughs to a repository, blocs can call repositories directly; delete usecases/ when a feature is next reworked
  sl.registerFactory(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => RegisterUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => SendOtpUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => VerifyOtpUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => GetCurrentUserUseCase(sl<AuthRepository>()));
  sl.registerFactory(() => UpdateProfileUseCase(sl<AuthRepository>()));
  sl.registerFactory(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      registerUseCase: sl<RegisterUseCase>(),
      sendOtpUseCase: sl<SendOtpUseCase>(),
      verifyOtpUseCase: sl<VerifyOtpUseCase>(),
      getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
      updateProfileUseCase: sl<UpdateProfileUseCase>(),
      secureStorage: sl<SecureStorage>(),
    ),
  );

  // Home
  sl.registerFactory<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<HomeRepository>(
    () => HomeRepositoryImpl(sl<HomeRemoteDataSource>()),
  );
  sl.registerFactory(() => GetNearbyProvidersUseCase(sl<HomeRepository>()));
  sl.registerFactory(() => SearchProvidersUseCase(sl<HomeRepository>()));
  sl.registerFactory(
    () => HomeBloc(
      getNearbyProviders: sl<GetNearbyProvidersUseCase>(),
      searchProviders: sl<SearchProvidersUseCase>(),
    ),
  );

  // Providers
  sl.registerFactory<ProviderRemoteDataSource>(
    () => ProviderRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<ProviderRepository>(
    () => ProviderRepositoryImpl(sl<ProviderRemoteDataSource>()),
  );
  sl.registerFactory(() => GetProviderDetailUseCase(sl<ProviderRepository>()));
  sl.registerFactory(() => SaveProviderUseCase(sl<ProviderRepository>()));
  sl.registerFactory(() => CheckSavedUseCase(sl<ProviderRepository>()));
  sl.registerFactory(() => GetProviderSlotsUseCase(sl<ProviderRepository>()));
  sl.registerFactory(
    () => ProviderBloc(
      getProviderDetail: sl<GetProviderDetailUseCase>(),
      saveProvider: sl<SaveProviderUseCase>(),
      checkSaved: sl<CheckSavedUseCase>(),
      getSlots: sl<GetProviderSlotsUseCase>(),
    ),
  );

  // Bookings
  sl.registerFactory<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<BookingRepository>(
    () => BookingRepositoryImpl(sl<BookingRemoteDataSource>()),
  );
  sl.registerFactory(() => CreateBookingUseCase(sl<BookingRepository>()));
  sl.registerFactory(() => GetMyBookingsUseCase(sl<BookingRepository>()));
  sl.registerFactory(() => CancelBookingUseCase(sl<BookingRepository>()));
  sl.registerFactory(
    () => BookingBloc(
      createBooking: sl<CreateBookingUseCase>(),
      getMyBookings: sl<GetMyBookingsUseCase>(),
      cancelBooking: sl<CancelBookingUseCase>(),
    ),
  );

  // Notifications
  sl.registerFactory<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(sl<NotificationRemoteDataSource>()),
  );
  sl.registerFactory(
    () => GetNotificationsUseCase(sl<NotificationRepository>()),
  );
  sl.registerFactory(() => GetUnreadCountUseCase(sl<NotificationRepository>()));
  sl.registerFactory(
    () => NotificationBloc(
      getNotifications: sl<GetNotificationsUseCase>(),
      getUnreadCount: sl<GetUnreadCountUseCase>(),
      repository: sl<NotificationRepository>(),
    ),
  );

  // Reviews
  sl.registerFactory<ReviewRemoteDataSource>(
    () => ReviewRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<ReviewRepository>(
    () => ReviewRepositoryImpl(sl<ReviewRemoteDataSource>()),
  );
  // ponytail: registered but never resolved (ReviewBloc uses ReviewRepository), delete with its file
  sl.registerFactory(() => SubmitReviewUseCase(sl<ReviewRepository>()));
  sl.registerFactory(() => ReviewBloc(sl<ReviewRepository>()));

  // Saved
  sl.registerFactory<SavedRemoteDataSource>(
    () => SavedRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<SavedRepository>(
    () => SavedRepositoryImpl(sl<SavedRemoteDataSource>()),
  );
  sl.registerFactory(() => GetSavedProvidersUseCase(sl<SavedRepository>()));
  sl.registerFactory(
    () => SavedBloc(
      getSavedProviders: sl<GetSavedProvidersUseCase>(),
      repository: sl<SavedRepository>(),
    ),
  );

  // Provider Dashboard
  sl.registerFactory<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<DashboardRepository>(
    () => DashboardRepositoryImpl(sl<DashboardRemoteDataSource>()),
  );
  sl.registerFactory(() => GetDashboardUseCase(sl<DashboardRepository>()));
  sl.registerFactory(
    () => DashboardBloc(
      getDashboard: sl<GetDashboardUseCase>(),
      repository: sl<DashboardRepository>(),
    ),
  );
}
