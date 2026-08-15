import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'google_models.dart';
import 'google_oauth_config.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const _refreshTokenKey = 'academia_flow_google_refresh_token';
  static const _desktopScopesKey = 'academia_flow_google_desktop_scopes';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';
  static const _userInfoEndpoint = 'https://openidconnect.googleapis.com/v1/userinfo';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final http.Client _http = http.Client();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _androidInitialized = false;
  GoogleSignInAccount? _androidAccount;
  String? _desktopAccessToken;
  DateTime? _desktopAccessTokenExpiry;
  Set<String> _desktopGrantedScopes = <String>{};

  bool get configured => GoogleOAuthConfig.currentPlatformConfigured;
  bool get supported => GoogleOAuthConfig.currentPlatformSupported;

  Future<GoogleAccountProfile?> restore() async {
    if (!configured) return null;
    if (Platform.isAndroid) {
      await _initializeAndroid();
      try {
        final lightweight = _googleSignIn.attemptLightweightAuthentication();
        final account = lightweight == null ? null : await lightweight;
        if (account == null) return null;
        _androidAccount = account;
        return _fromAndroidAccount(account);
      } on GoogleSignInException {
        return null;
      }
    }
    if (Platform.isWindows) {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) return null;
      _desktopGrantedScopes = await _readDesktopScopes();
      try {
        final token = await _refreshDesktopToken(refreshToken);
        return await _fetchUserInfo(token);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<GoogleAccountProfile> signIn() async {
    if (!supported) {
      throw UnsupportedError('Login Google disponível somente no Android e Windows nesta versão.');
    }
    if (!configured) throw StateError(GoogleOAuthConfig.configurationMessage);
    if (Platform.isAndroid) {
      await _initializeAndroid();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw StateError('O dispositivo não oferece o fluxo interativo de login esperado.');
      }
      final account = await _googleSignIn.authenticate();
      _androidAccount = account;
      return _fromAndroidAccount(account);
    }
    final result = await _authorizeDesktop(GoogleOAuthConfig.baseScopes);
    return _fetchUserInfo(result.accessToken);
  }

  Future<String> classroomAccessToken({required bool interactive}) async {
    if (!configured) throw StateError(GoogleOAuthConfig.configurationMessage);
    if (Platform.isAndroid) {
      await _initializeAndroid();
      var account = _androidAccount;
      if (account == null) {
        final lightweight = _googleSignIn.attemptLightweightAuthentication();
        if (lightweight != null) account = await lightweight;
      }
      if (account == null) {
        if (!interactive) throw StateError('Entre com sua conta Google novamente.');
        account = await _googleSignIn.authenticate();
      }
      _androidAccount = account;
      final client = account.authorizationClient;
      final cached = await client.authorizationForScopes(GoogleOAuthConfig.classroomScopes);
      if (cached != null) return cached.accessToken;
      if (!interactive) throw StateError('O Google Classroom precisa de autorização.');
      final granted = await client.authorizeScopes(GoogleOAuthConfig.classroomScopes);
      return granted.accessToken;
    }
    if (Platform.isWindows) {
      final requiredScopes = GoogleOAuthConfig.allScopes.toSet();
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final scopesCoverClassroom = _desktopGrantedScopes.containsAll(requiredScopes);
      if (refreshToken != null && refreshToken.isNotEmpty && scopesCoverClassroom) {
        if (_desktopAccessToken != null &&
            _desktopAccessTokenExpiry != null &&
            DateTime.now().isBefore(_desktopAccessTokenExpiry!.subtract(const Duration(minutes: 2)))) {
          return _desktopAccessToken!;
        }
        try {
          return await _refreshDesktopToken(refreshToken);
        } catch (_) {
          if (!interactive) rethrow;
        }
      }
      if (!interactive) throw StateError('Autorize o Google Classroom para continuar.');
      final result = await _authorizeDesktop(GoogleOAuthConfig.allScopes);
      return result.accessToken;
    }
    throw UnsupportedError('Google Classroom disponível somente no Android e Windows nesta versão.');
  }

  Future<void> signOut({bool revoke = false}) async {
    if (Platform.isAndroid && _androidInitialized) {
      try {
        if (revoke) {
          await _googleSignIn.disconnect();
        } else {
          await _googleSignIn.signOut();
        }
      } catch (_) {}
      _androidAccount = null;
    }
    if (Platform.isWindows) {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (revoke && refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await _http.post(Uri.parse(_revokeEndpoint), body: {'token': refreshToken});
        } catch (_) {}
      }
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _desktopScopesKey);
      _desktopAccessToken = null;
      _desktopAccessTokenExpiry = null;
      _desktopGrantedScopes = <String>{};
    }
  }

  Future<void> _initializeAndroid() async {
    if (_androidInitialized) return;
    await _googleSignIn.initialize(
      serverClientId: GoogleOAuthConfig.androidServerClientId,
    );
    _androidInitialized = true;
  }

  GoogleAccountProfile _fromAndroidAccount(GoogleSignInAccount account) => GoogleAccountProfile(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? '',
        photoUrl: account.photoUrl ?? '',
      );

  Future<GoogleAccountProfile> _fetchUserInfo(String accessToken) async {
    final response = await _http.get(
      Uri.parse(_userInfoEndpoint),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Não foi possível ler o perfil Google (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return GoogleAccountProfile(
      id: '${json['sub'] ?? ''}',
      email: '${json['email'] ?? ''}',
      displayName: '${json['name'] ?? ''}',
      photoUrl: '${json['picture'] ?? ''}',
    );
  }

  Future<_DesktopOAuthResult> _authorizeDesktop(List<String> scopes) async {
    if (GoogleOAuthConfig.desktopClientId.trim().isEmpty) {
      throw StateError(GoogleOAuthConfig.configurationMessage);
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}/oauth2callback';
    final verifier = _randomUrlSafe(64);
    final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    final state = _randomUrlSafe(32);
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': GoogleOAuthConfig.desktopClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scopes.join(' '),
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
      'state': state,
    });

    final opened = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await server.close(force: true);
      throw StateError('Não foi possível abrir o navegador para autenticação.');
    }

    try {
      final request = await server.first.timeout(const Duration(minutes: 3));
      final params = request.uri.queryParameters;
      final error = params['error'];
      final returnedState = params['state'];
      final code = params['code'];
      request.response.headers.contentType = ContentType.html;
      request.response.write('''<!doctype html><html><head><meta charset="utf-8"><title>Academia Flow</title></head><body style="font-family:Arial,sans-serif;padding:40px;background:#091e26;color:white"><h2>Academia Flow</h2><p>${error == null && code != null ? 'Conta Google conectada. Você já pode voltar ao aplicativo.' : 'Não foi possível concluir o login. Volte ao Academia Flow e tente novamente.'}</p></body></html>''');
      await request.response.close();
      if (error != null) throw StateError('Autorização Google cancelada ou negada: $error');
      if (returnedState != state || code == null || code.isEmpty) {
        throw StateError('A resposta do Google não pôde ser validada.');
      }
      final body = <String, String>{
        'client_id': GoogleOAuthConfig.desktopClientId,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      };
      if (GoogleOAuthConfig.desktopClientSecret.trim().isNotEmpty) {
        body['client_secret'] = GoogleOAuthConfig.desktopClientSecret;
      }
      final response = await _http.post(Uri.parse(_tokenEndpoint), body: body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Falha ao concluir OAuth Google (${response.statusCode}).');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = '${json['access_token'] ?? ''}';
      if (accessToken.isEmpty) throw StateError('O Google não retornou um token de acesso.');
      final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
      _desktopAccessToken = accessToken;
      _desktopAccessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
      _desktopGrantedScopes = scopes.toSet();
      final refreshToken = '${json['refresh_token'] ?? ''}';
      if (refreshToken.isNotEmpty) {
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      }
      await _writeDesktopScopes(_desktopGrantedScopes);
      return _DesktopOAuthResult(accessToken: accessToken);
    } finally {
      await server.close(force: true);
    }
  }

  Future<String> _refreshDesktopToken(String refreshToken) async {
    final body = <String, String>{
      'client_id': GoogleOAuthConfig.desktopClientId,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    };
    if (GoogleOAuthConfig.desktopClientSecret.trim().isNotEmpty) {
      body['client_secret'] = GoogleOAuthConfig.desktopClientSecret;
    }
    final response = await _http.post(Uri.parse(_tokenEndpoint), body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('A sessão Google expirou. Entre novamente.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = '${json['access_token'] ?? ''}';
    if (accessToken.isEmpty) throw StateError('Não foi possível renovar a sessão Google.');
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _desktopAccessToken = accessToken;
    _desktopAccessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    return accessToken;
  }

  Future<Set<String>> _readDesktopScopes() async {
    final raw = await _secureStorage.read(key: _desktopScopesKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    return raw.split('\n').where((e) => e.trim().isNotEmpty).toSet();
  }

  Future<void> _writeDesktopScopes(Set<String> scopes) =>
      _secureStorage.write(key: _desktopScopesKey, value: scopes.join('\n'));

  String _randomUrlSafe(int bytes) {
    final random = Random.secure();
    final values = List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }
}

class _DesktopOAuthResult {
  const _DesktopOAuthResult({required this.accessToken});
  final String accessToken;
}
