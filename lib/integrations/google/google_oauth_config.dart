import 'dart:io' show Platform;

abstract final class GoogleOAuthConfig {
  static const androidServerClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_SERVER_CLIENT_ID',
  );
  static const desktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
  );
  static const desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
  );

  static const baseScopes = <String>[
    'openid',
    'email',
    'profile',
  ];

  static const classroomScopes = <String>[
    'https://www.googleapis.com/auth/classroom.courses.readonly',
    'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
    'https://www.googleapis.com/auth/classroom.student-submissions.me.readonly',
  ];

  static List<String> get allScopes => [...baseScopes, ...classroomScopes];

  static bool get currentPlatformSupported => Platform.isAndroid || Platform.isWindows;

  static bool get currentPlatformConfigured {
    if (Platform.isAndroid) return androidServerClientId.trim().isNotEmpty;
    if (Platform.isWindows) return desktopClientId.trim().isNotEmpty;
    return false;
  }

  static String get configurationMessage {
    if (Platform.isAndroid) {
      return 'Defina GOOGLE_ANDROID_SERVER_CLIENT_ID com o Client ID OAuth do tipo Web usado pelo app Android.';
    }
    if (Platform.isWindows) {
      return 'Defina GOOGLE_DESKTOP_CLIENT_ID (e, se fornecido pelo Google, GOOGLE_DESKTOP_CLIENT_SECRET) para o cliente OAuth Desktop.';
    }
    return 'A integração Google desta versão está disponível no Android e Windows.';
  }
}
