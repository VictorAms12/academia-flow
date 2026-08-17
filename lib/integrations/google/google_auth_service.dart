import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'google_models.dart';
import 'google_oauth_config.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  static const _refreshTokenKey = 'academia_flow_google_refresh_token';
  static const _desktopScopesKey = 'academia_flow_google_desktop_scopes';
  static const _androidProfileKey = 'academia_flow_google_android_profile';
  static const _androidAccessTokenKey = 'academia_flow_google_android_access_token';
  static const _androidAccessTokenAtKey = 'academia_flow_google_android_access_token_at';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';
  static const _userInfoEndpoint = 'https://openidconnect.googleapis.com/v1/userinfo';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final http.Client _http = http.Client();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _androidInitialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _androidAuthSubscription;
  GoogleSignInAccount? _androidAccount;
  String? _desktopAccessToken;
  DateTime? _desktopAccessTokenExpiry;
  Set<String> _desktopGrantedScopes = <String>{};

  bool get configured => GoogleOAuthConfig.currentPlatformConfigured;
  bool get supported => GoogleOAuthConfig.currentPlatformSupported;

  Future<GoogleAccountProfile?> restore() async {
    if (!configured) return null;
    if (Platform.isAndroid) {
      // Não executa attemptLightweightAuthentication aqui. No Android 7.x,
      // esse fluxo pode mostrar One Tap/seletor de contas, mesmo quando o app
      // só quer restaurar o estado visual. O perfil persistido é suficiente.
      await _initializeAndroid();
      return _readRememberedAndroidProfile();
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
      final profile = _fromAndroidAccount(account);
      await _saveRememberedAndroidProfile(profile);
      return profile;
    }
    final result = await _authorizeDesktop(GoogleOAuthConfig.baseScopes);
    return _fetchUserInfo(result.accessToken);
  }

  Future<String> classroomAccessToken({required bool interactive}) async {
    if (!configured) throw StateError(GoogleOAuthConfig.configurationMessage);
    if (Platform.isAndroid) {
      await _initializeAndroid();

      // Enquanto o processo do app estiver vivo, a conta real do plugin é a
      // melhor fonte: authorizationForScopes não mostra UI quando a autorização
      // já existe.
      final account = _androidAccount;
      if (account != null) {
        final profile = _fromAndroidAccount(account);
        await _saveRememberedAndroidProfile(profile);
        final cached = await account.authorizationClient
            .authorizationForScopes(GoogleOAuthConfig.classroomScopes);
        if (cached != null) {
          await _saveAndroidAccessToken(cached.accessToken);
          return cached.accessToken;
        }
      }

      final remembered = await _readRememberedAndroidProfile();

      // Após o Android matar o processo, não temos mais um GoogleSignInAccount
      // Dart. Em vez de abrir o Credential Manager para reconstruí-lo, fazemos
      // a mesma solicitação silenciosa do plugin diretamente, mas informando o
      // ID e e-mail da conta já escolhida. promptIfUnauthorized=false garante
      // que esta tentativa não abra seletor nem consentimento.
      if (remembered != null) {
        final silent = await _androidAuthorizationForProfile(
          remembered,
          promptIfUnauthorized: false,
        );
        if (silent != null) {
          await _saveAndroidAccessToken(silent.accessToken);
          return silent.accessToken;
        }
      }

      // Fallback para reaberturas muito recentes: reutiliza apenas token salvo
      // recentemente. Tokens antigos nunca são usados como sessão permanente.
      final recentToken = await _readRecentAndroidAccessToken();
      if (recentToken != null) return recentToken;

      if (!interactive) {
        throw StateError('A autorização do Google Classroom precisa ser renovada.');
      }

      // Se a autorização realmente precisar de interação, ainda direcionamos
      // o pedido para a conta já salva. Isso evita um seletor de contas apenas
      // para escolher novamente a mesma conta.
      if (remembered != null) {
        final granted = await _androidAuthorizationForProfile(
          remembered,
          promptIfUnauthorized: true,
        );
        if (granted != null) {
          await _saveAndroidAccessToken(granted.accessToken);
          return granted.accessToken;
        }
      }

      // Último recurso: só há novo login quando não existe mais uma conta
      // persistida/autorização recuperável.
      final signedIn = await _googleSignIn.authenticate(
        scopeHint: GoogleOAuthConfig.classroomScopes,
      );
      _androidAccount = signedIn;
      final profile = _fromAndroidAccount(signedIn);
      await _saveRememberedAndroidProfile(profile);
      final client = signedIn.authorizationClient;
      final cachedAfterLogin =
          await client.authorizationForScopes(GoogleOAuthConfig.classroomScopes);
      if (cachedAfterLogin != null) {
        await _saveAndroidAccessToken(cachedAfterLogin.accessToken);
        return cachedAfterLogin.accessToken;
      }
      final grantedAfterLogin =
          await client.authorizeScopes(GoogleOAuthConfig.classroomScopes);
      await _saveAndroidAccessToken(grantedAfterLogin.accessToken);
      return grantedAfterLogin.accessToken;
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

  Future<ClientAuthorizationTokenData?> _androidAuthorizationForProfile(
    GoogleAccountProfile profile, {
    required bool promptIfUnauthorized,
  }) {
    return GoogleSignInPlatform.instance.clientAuthorizationTokensForScopes(
      ClientAuthorizationTokensForScopesParameters(
        request: AuthorizationRequestDetails(
          scopes: GoogleOAuthConfig.classroomScopes,
          userId: profile.id,
          email: profile.email,
          promptIfUnauthorized: promptIfUnauthorized,
        ),
      ),
    );
  }

  Future<void> _saveAndroidAccessToken(String accessToken) async {
    if (accessToken.trim().isEmpty) return;
    await _secureStorage.write(key: _androidAccessTokenKey, value: accessToken);
    await _secureStorage.write(
      key: _androidAccessTokenAtKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<String?> _readRecentAndroidAccessToken() async {
    final token = await _secureStorage.read(key: _androidAccessTokenKey);
    final savedAtRaw = await _secureStorage.read(key: _androidAccessTokenAtKey);
    if (token == null || token.trim().isEmpty || savedAtRaw == null) return null;
    final savedAt = DateTime.tryParse(savedAtRaw)?.toUtc();
    if (savedAt == null) return null;
    if (DateTime.now().toUtc().difference(savedAt) > const Duration(minutes: 45)) {
      await _clearAndroidAccessToken();
      return null;
    }
    return token;
  }

  Future<void> _clearAndroidAccessToken() async {
    await _secureStorage.delete(key: _androidAccessTokenKey);
    await _secureStorage.delete(key: _androidAccessTokenAtKey);
  }

  Future<void> signOut({bool revoke = false}) async {
    if (Platform.isAndroid) {
      if (_androidInitialized) {
        try {
          if (revoke) {
            await _googleSignIn.disconnect();
          } else {
            await _googleSignIn.signOut();
          }
        } catch (_) {}
      }
      _androidAccount = null;
      await _secureStorage.delete(key: _androidProfileKey);
      await _clearAndroidAccessToken();
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
    _androidAuthSubscription ??= _googleSignIn.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _androidAccount = event.user;
          unawaited(_saveRememberedAndroidProfile(_fromAndroidAccount(event.user)));
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _androidAccount = null;
        }
      },
      onError: (_) {},
    );
    _androidInitialized = true;
  }

  Future<void> _saveRememberedAndroidProfile(GoogleAccountProfile profile) async {
    await _secureStorage.write(
      key: _androidProfileKey,
      value: jsonEncode({
        'id': profile.id,
        'email': profile.email,
        'displayName': profile.displayName,
        'photoUrl': profile.photoUrl,
      }),
    );
  }

  Future<GoogleAccountProfile?> _readRememberedAndroidProfile() async {
    final raw = await _secureStorage.read(key: _androidProfileKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = '${map['id'] ?? ''}'.trim();
      final email = '${map['email'] ?? ''}'.trim();
      if (id.isEmpty || email.isEmpty) return null;
      return GoogleAccountProfile(
        id: id,
        email: email,
        displayName: '${map['displayName'] ?? ''}',
        photoUrl: '${map['photoUrl'] ?? ''}',
      );
    } catch (_) {
      await _secureStorage.delete(key: _androidProfileKey);
      return null;
    }
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
