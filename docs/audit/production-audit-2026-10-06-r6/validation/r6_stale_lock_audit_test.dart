import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:aiwa_app/core/constants/app_constants.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class Remote implements AuthRemoteDataSource {
  @override Future<Map<String,String>> login({required String identifier,required String password}) async =>
    {'accessToken':'B-access','refreshToken':'B-refresh','role':'CUSTOMER','userId':'2'};
  @override Future<UserModel> getCurrentUser() async => UserModel.fromJson({'id':2,'fullName':'Bob','role':'CUSTOMER'});
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class DelayedLockAdapter implements HttpClientAdapter {
  final started=Completer<void>();
  final release=Completer<void>();
  String? originalBearer;
  @override Future<ResponseBody> fetch(RequestOptions options,Stream<Uint8List>? body,Future<void>? cancel) async {
    originalBearer=options.headers['Authorization'] as String?;
    started.complete();
    await release.future;
    return ResponseBody.fromString(jsonEncode({'message':'account A locked'}),423,
      headers:{Headers.contentTypeHeader:[Headers.jsonContentType]});
  }
  @override void close({bool force=false}){}
}
void main(){
  test('audit: A stale 423 response causes current B session to log out',() async {
    FlutterSecureStorage.setMockInitialValues({AppConstants.accessTokenKey:'A-access',AppConstants.refreshTokenKey:'A-refresh',AppConstants.userIdKey:'1'});
    final storage=SecureStorage(const FlutterSecureStorage());
    final adapter=DelayedLockAdapter();
    final client=ApiClient(storage,adapter:adapter);
    final bloc=AuthBloc(authRepository:AuthRepositoryImpl(Remote(),storage),secureStorage:storage);
    final events=<int>[];
    // Mirrors _ThemedAppState._onAuthEvent's current unconditional 423 -> AuthLogoutEvent.
    final subscription=ApiClient.authEvents.stream.listen((status){
      events.add(status);
      if(status==423) bloc.add(AuthLogoutEvent());
    });
    final old=client.get('/audit/slow').then<Object>((r)=>r).catchError((Object e)=>e);
    await adapter.started.future.timeout(const Duration(seconds:3));
    expect(adapter.originalBearer,'Bearer A-access');
    final signedIn=bloc.stream.firstWhere((s)=>s is AuthAuthenticated);
    bloc.add(AuthLoginEvent(identifier:'B',password:'synthetic'));
    await signedIn.timeout(const Duration(seconds:3));
    expect(await storage.getAccessToken(),'B-access');
    expect(await storage.getUserId(),'2');
    final signedOut=bloc.stream.firstWhere((s)=>s is AuthUnauthenticated);
    adapter.release.complete();
    await old;
    await signedOut.timeout(const Duration(seconds:3));
    expect(events,contains(423));
    expect(await storage.getAccessToken(),isNull);
    expect(await storage.getRefreshToken(),isNull);
    await subscription.cancel();
    await bloc.close();
  });
}
