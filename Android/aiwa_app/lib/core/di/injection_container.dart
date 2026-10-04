import '../../features/provider_dashboard/data/provider_manage_repository.dart';
import '../../features/profile/data/account_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../push/push_registrar.dart';
import '../push/push_service.dart';
import '../storage/secure_storage.dart';

// Auth
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Home
import '../../features/home/data/datasources/home_remote_datasource.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';

// Providers
import '../../features/providers/data/datasources/provider_remote_datasource.dart';
import '../../features/providers/data/repositories/provider_repository_impl.dart';
import '../../features/providers/domain/repositories/provider_repository.dart';
import '../../features/providers/presentation/bloc/provider_bloc.dart';

// Bookings
import '../../features/bookings/data/datasources/booking_remote_datasource.dart';
import '../../features/bookings/data/repositories/booking_repository_impl.dart';
import '../../features/bookings/domain/repositories/booking_repository.dart';
import '../../features/bookings/presentation/bloc/booking_bloc.dart';

// Notifications
import '../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';

// Reviews
import '../../features/reviews/data/datasources/review_remote_datasource.dart';
import '../../features/reviews/data/repositories/review_repository_impl.dart';
import '../../features/reviews/domain/repositories/review_repository.dart';
import '../../features/reviews/presentation/bloc/review_bloc.dart';

// Saved
import '../../features/saved/data/datasources/saved_remote_datasource.dart';
import '../../features/saved/data/repositories/saved_repository_impl.dart';
import '../../features/saved/domain/repositories/saved_repository.dart';
import '../../features/saved/presentation/bloc/saved_bloc.dart';

// Provider Dashboard
import '../../features/provider_dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../features/provider_dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/provider_dashboard/domain/repositories/dashboard_repository.dart';
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
  // FE-3: the FCM token, or null (no-op) until Firebase is configured.
  sl.registerLazySingleton(
    () => PushRegistrar(sl<ApiClient>(), tokenSource: PushService.token),
  );
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
  sl.registerFactory(
    () => AuthBloc(
      authRepository: sl<AuthRepository>(),
      secureStorage: sl<SecureStorage>(),
      apiClient: sl<ApiClient>(),
      pushRegistrar: sl<PushRegistrar>(),
    ),
  );

  // Home
  sl.registerFactory<HomeRemoteDataSource>(
    () => HomeRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<HomeRepository>(
    () => HomeRepositoryImpl(sl<HomeRemoteDataSource>()),
  );
  sl.registerFactory(
    () => HomeBloc(
      homeRepository: sl<HomeRepository>(),
    ),
  );

  // Providers
  sl.registerFactory<ProviderRemoteDataSource>(
    () => ProviderRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<ProviderRepository>(
    () => ProviderRepositoryImpl(sl<ProviderRemoteDataSource>()),
  );
  sl.registerFactory(
    () => ProviderBloc(
      providerRepository: sl<ProviderRepository>(),
    ),
  );

  // Bookings
  sl.registerFactory<BookingRemoteDataSource>(
    () => BookingRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<BookingRepository>(
    () => BookingRepositoryImpl(sl<BookingRemoteDataSource>()),
  );
  sl.registerFactory(
    () => BookingBloc(
      bookingRepository: sl<BookingRepository>(),
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
    () => NotificationBloc(
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
  sl.registerFactory(() => ReviewBloc(sl<ReviewRepository>()));

  // Saved
  sl.registerFactory<SavedRemoteDataSource>(
    () => SavedRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerFactory<SavedRepository>(
    () => SavedRepositoryImpl(sl<SavedRemoteDataSource>()),
  );
  sl.registerFactory(
    () => SavedBloc(
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
  sl.registerFactory(
    () => DashboardBloc(
      repository: sl<DashboardRepository>(),
    ),
  );
}
