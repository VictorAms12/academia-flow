import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'google_models.dart';

class ClassroomApi {
  ClassroomApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _networkTimeout = Duration(seconds: 20);

  Future<List<ClassroomCourse>> listActiveCourses(String accessToken) async {
    final result = <ClassroomCourse>[];
    String? pageToken;
    do {
      final query = <String, String>{
        'studentId': 'me',
        'courseStates': 'ACTIVE',
        'pageSize': '100',
        if (pageToken != null) 'pageToken': pageToken,
      };
      final json = await _getJson(
        Uri.https('classroom.googleapis.com', '/v1/courses', query),
        accessToken,
      );
      final items = (json['courses'] as List?) ?? const [];
      result.addAll(items.whereType<Map>().map((e) => ClassroomCourse.fromJson(Map<String, dynamic>.from(e))));
      pageToken = (json['nextPageToken'] as String?)?.trim();
      if (pageToken?.isEmpty == true) pageToken = null;
    } while (pageToken != null);
    return result;
  }

  Future<List<ClassroomCourseWork>> listCourseWork(String courseId, String accessToken) async {
    final result = <ClassroomCourseWork>[];
    String? pageToken;
    do {
      final query = <String, String>{
        'pageSize': '100',
        'orderBy': 'dueDate asc,updateTime desc',
        if (pageToken != null) 'pageToken': pageToken,
      };
      final json = await _getJson(
        Uri.https('classroom.googleapis.com', '/v1/courses/$courseId/courseWork', query),
        accessToken,
      );
      final items = (json['courseWork'] as List?) ?? const [];
      result.addAll(items.whereType<Map>().map((e) => ClassroomCourseWork.fromJson(Map<String, dynamic>.from(e))));
      pageToken = (json['nextPageToken'] as String?)?.trim();
      if (pageToken?.isEmpty == true) pageToken = null;
    } while (pageToken != null);
    return result;
  }

  Future<List<ClassroomSubmission>> listMySubmissions(String courseId, String accessToken) async {
    final result = <ClassroomSubmission>[];
    String? pageToken;
    do {
      final query = <String, String>{
        'userId': 'me',
        'pageSize': '100',
        if (pageToken != null) 'pageToken': pageToken,
      };
      final json = await _getJson(
        Uri.https(
          'classroom.googleapis.com',
          '/v1/courses/$courseId/courseWork/-/studentSubmissions',
          query,
        ),
        accessToken,
      );
      final items = (json['studentSubmissions'] as List?) ?? const [];
      result.addAll(items.whereType<Map>().map((e) => ClassroomSubmission.fromJson(Map<String, dynamic>.from(e))));
      pageToken = (json['nextPageToken'] as String?)?.trim();
      if (pageToken?.isEmpty == true) pageToken = null;
    } while (pageToken != null);
    return result;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri, String accessToken) async {
    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(_networkTimeout);
      if (response.statusCode == 401) {
        throw StateError('A autorização Google expirou. Entre novamente.');
      }
      if (response.statusCode == 403) {
        throw StateError('O Google Classroom negou acesso. Confira as permissões da conta ou da instituição.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Falha ao consultar o Classroom (${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException('Resposta inesperada do Classroom.');
      return Map<String, dynamic>.from(decoded);
    } on TimeoutException {
      throw StateError('O Google Classroom demorou demais para responder. Verifique a conexão e tente novamente.');
    } on FormatException {
      throw StateError('O Google Classroom retornou uma resposta inválida. Tente novamente em instantes.');
    }
  }
}
