import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/core/constants/app_constants.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedStorage extends SecureStorage {
  DelayedStorage():super(const FlutterSecureStorage());
  final started=Completer<void>();
  final release=Completer<void>();
  @override Future<void> saveAccessToken(String value) async {
    if(value=='A-rotated') {started.complete();await release.future;}
    await super.saveAccessToken(value);
  }
}
class Remote implements AuthRemoteDataSource {
  @override Future<Map<String,String>> login({required String identifier,required String password}) async =>
    {'accessToken':'B-access','refreshToken':'B-refresh','role':'CUSTOMER','userId':'2'};
  @override dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class Adapter implements HttpClientAdapter {
  @override Future<ResponseBody> fetch(RequestOptions options,Stream<Uint8List>? stream,Future<void>? cancel) async {
    final refresh=options.path==ApiConstants.refresh;
    final expired=options.headers['Authorization']=='Bearer A-old';
    final payload=refresh
      ? {'data':{'accessToken':'A-rotated','refreshToken':'A-refresh-rotated'}}
      : {'data': options.headers['Authorization']=='Bearer B-access'
          ? {'userId':2,'account':'B'} : {'userId':1,'account':'A'}};
    return ResponseBody.fromString(jsonEncode(payload),refresh||!expired?200:401,
      headers:{Headers.contentTypeHeader:[Headers.jsonContentType]});
  }
  @override void close({bool force=false}){}
}
void main(){
  test('audit reproduction: old refresh write overwrites B access while B refresh/id remain',() async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey:'A-old',
      AppConstants.refreshTokenKey:'A-refresh',
      AppConstants.userIdKey:'1',
    });
    final storage=DelayedStorage();
    final client=ApiClient(storage,adapter:Adapter());
    final oldRequest=client.get('/audit/protected').then<Object>((r)=>r).catchError((Object e)=>e);
    await storage.started.future.timeout(const Duration(seconds:3));
    SecureStorage.beginAuthAttempt();
    final result=await AuthRepositoryImpl(Remote(),storage).login(identifier:'B',password:'synthetic');
    expect(result.isRight(),isTrue);
    expect(await storage.getAccessToken(),'B-access');
    expect(await storage.getRefreshToken(),'B-refresh');
    storage.release.complete();
    await oldRequest;
    expect(await storage.getAccessToken(),'A-rotated');
    expect(await storage.getRefreshToken(),'B-refresh');
    expect(await storage.getUserId(),'2');
    final next=await client.get('/audit/protected');
    expect(next.data['data']['userId'],1);
  },tags:'audit-probe');
}
