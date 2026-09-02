import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import 'classroom_api.dart';
import 'google_auth_service.dart';
import 'google_integration_store.dart';
import 'google_models.dart';
import 'google_oauth_config.dart';

class GoogleIntegrationController extends ChangeNotifier {
  GoogleIntegrationController._();
  static final GoogleIntegrationController instance = GoogleIntegrationController._();

  final GoogleAuthService _auth = GoogleAuthService.instance;
  final GoogleIntegrationStore _store = GoogleIntegrationStore.instance;
  final ClassroomApi _classroom = ClassroomApi();

  AppState? _state;
  bool initialized = false;
  bool busy = false;
  bool authenticated = false;
  String? error;
  GoogleAccountProfile? account;
  List<ClassroomCourse> courses = [];
  List<ClassroomCourseLink> courseLinks = [];
  List<ClassroomTaskLink> taskLinks = [];
  ClassroomSyncReport? lastReport;

  bool get supported => GoogleOAuthConfig.currentPlatformSupported;
  bool get configured => GoogleOAuthConfig.currentPlatformConfigured;
  String get configurationMessage => GoogleOAuthConfig.configurationMessage;

  Future<void> initialize(AppState state) async {
    _state = state;
    if (initialized) return;
    await _store.ensureSchema();
    account = await _store.getAccount();
    authenticated = account != null;
    if (account != null) {
      courseLinks = await _store.getCourseLinks(account!.id);
      taskLinks = await _store.getTaskLinks(account!.id);
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> signIn() async {
    await _run(() async {
      final previous = await _store.getAccount();
      final profile = await _auth.signIn();
      final sameAccount = previous?.id == profile.id;
      account = profile.copyWith(
        classroomConnected: sameAccount ? previous!.classroomConnected : false,
        lastSyncAt: sameAccount ? previous!.lastSyncAt : null,
      );
      authenticated = true;
      courses = [];
      courseLinks = await _store.getCourseLinks(profile.id);
      taskLinks = await _store.getTaskLinks(profile.id);
      await _store.saveAccount(account!);
    });
  }

  Future<void> signOut() async {
    await _run(() async {
      await _auth.signOut();
      await _store.clearAccount();
      authenticated = false;
      account = null;
      courses = [];
      courseLinks = [];
      taskLinks = [];
      lastReport = null;
    });
  }

  Future<void> disconnectAndRevoke() async {
    await _run(() async {
      await _auth.signOut(revoke: true);
      await _store.clearAccount();
      authenticated = false;
      account = null;
      courses = [];
      courseLinks = [];
      taskLinks = [];
      lastReport = null;
    });
  }

  Future<void> connectClassroom() async {
    if (account == null) throw StateError('Entre com uma conta Google antes de conectar o Classroom.');
    await _run(() async {
      final token = await _auth.classroomAccessToken(interactive: true);
      courses = await _classroom.listActiveCourses(token);
      authenticated = true;
      account = account!.copyWith(classroomConnected: true);
      await _store.saveAccount(account!);
    });
  }

  Future<void> refreshCourses() async {
    if (account == null) return;
    await _run(() async {
      final token = await _auth.classroomAccessToken(interactive: true);
      courses = await _classroom.listActiveCourses(token);
      authenticated = true;
      if (!account!.classroomConnected) {
        account = account!.copyWith(classroomConnected: true);
        await _store.saveAccount(account!);
      }
    });
  }

  ClassroomCourseLink? linkForCourse(String courseId) {
    for (final link in courseLinks) {
      if (link.courseId == courseId) return link;
    }
    return null;
  }

  ClassroomTaskLink? taskLinkForTask(int? taskId) {
    if (taskId == null) return null;
    for (final link in taskLinks) {
      if (link.taskId == taskId) return link;
    }
    return null;
  }

  Subject? suggestedSubject(ClassroomCourse course) {
    final state = _state;
    if (state == null) return null;
    final target = normalizeCourseName(course.name);
    for (final subject in state.subjects) {
      if (normalizeCourseName(subject.name) == target) return subject;
    }
    for (final subject in state.subjects) {
      final normalized = normalizeCourseName(subject.name);
      if (normalized.isNotEmpty && (target.contains(normalized) || normalized.contains(target))) return subject;
    }
    return null;
  }

  Future<void> linkCourse(ClassroomCourse course, {Subject? subject}) async {
    final state = _state;
    final profile = account;
    if (state == null || profile == null) return;
    await _run(() async {
      var target = subject;
      target ??= await state.saveSubject(Subject(name: course.name.trim().isEmpty ? 'Turma do Classroom' : course.name.trim(), room: course.section.trim()));
      if (target.id == null) throw StateError('Não foi possível vincular a matéria local.');
      await _store.saveCourseLink(ClassroomCourseLink(
        googleUserId: profile.id,
        courseId: course.id,
        subjectId: target.id!,
        courseName: course.name,
        courseState: course.state,
        alternateLink: course.alternateLink,
      ));
      courseLinks = await _store.getCourseLinks(profile.id);
    });
  }

  Future<void> unlinkCourse(ClassroomCourse course) async {
    final profile = account;
    if (profile == null) return;
    await _run(() async {
      await _store.deleteCourseLink(profile.id, course.id);
      await _store.deleteTaskLinksForCourse(profile.id, course.id);
      courseLinks = await _store.getCourseLinks(profile.id);
      taskLinks = await _store.getTaskLinks(profile.id);
    });
  }

  Future<ClassroomSyncReport> syncClassroom() async {
    final state = _state;
    final profile = account;
    if (state == null || profile == null) throw StateError('Entre com sua conta Google.');
    if (courseLinks.isEmpty) throw StateError('Vincule pelo menos uma turma do Classroom a uma matéria.');

    late ClassroomSyncReport report;
    await _run(() async {
      final token = await _auth.classroomAccessToken(interactive: true);
      authenticated = true;
      final existingLinks = <String, ClassroomTaskLink>{
        for (final link in await _store.getTaskLinks(profile.id)) '${link.courseId}:${link.courseWorkId}': link,
      };
      final localTasks = <int, AcademicTask>{for (final task in state.tasks) if (task.id != null) task.id!: task};
      var created = 0;
      var updated = 0;
      var completed = 0;
      var skipped = 0;
      var changedLocally = false;

      try {
        for (final courseLink in courseLinks) {
          // Future.wait registra listeners nas duas chamadas imediatamente:
          // ambas rodam em paralelo e uma falha não deixa a outra Future solta.
          final responses = await Future.wait<Object>([
            _classroom.listCourseWork(courseLink.courseId, token).then<Object>((value) => value),
            _classroom.listMySubmissions(courseLink.courseId, token).then<Object>((value) => value),
          ]);
          final work = responses[0] as List<ClassroomCourseWork>;
          final submissions = responses[1] as List<ClassroomSubmission>;
          final submissionByWork = <String, ClassroomSubmission>{for (final submission in submissions) submission.courseWorkId: submission};

          for (final item in work) {
            final key = '${courseLink.courseId}:${item.id}';
            final previousLink = existingLinks[key];
            final submission = submissionByWork[item.id];
            final dueAt = item.dueAt;

            if (previousLink == null && dueAt == null) {
              skipped++;
              continue;
            }

            AcademicTask? task = previousLink == null ? null : localTasks[previousLink.taskId];
            if (task == null) {
              if (dueAt == null) {
                skipped++;
                continue;
              }
              task = await state.saveTask(
                AcademicTask(
                  title: item.title,
                  subjectId: courseLink.subjectId,
                  dueDate: dueAt,
                  priority: Priority.medium,
                  status: submission?.submitted == true ? TaskStatus.done : TaskStatus.todo,
                  kind: _taskKind(item.workType),
                  reminderEnabled: true,
                  description: _classroomDescription(item),
                ),
                reload: false,
                scheduleNotification: false,
                notify: false,
              );
              if (task.id != null) localTasks[task.id!] = task;
              changedLocally = true;
              created++;
            } else {
              // Campos acadêmicos vindos do Classroom continuam sincronizados,
              // mas a descrição local é do usuário e nunca é sobrescrita depois
              // da importação inicial.
              final sourceChanged = item.title != task.title ||
                  (dueAt != null && dueAt != task.dueDate) ||
                  task.subjectId != courseLink.subjectId ||
                  task.kind != _taskKind(item.workType);
              final shouldComplete = submission?.submitted == true && task.status != TaskStatus.done;
              if (sourceChanged || shouldComplete) {
                task = await state.saveTask(
                  task.copyWith(
                    title: item.title,
                    subjectId: courseLink.subjectId,
                    dueDate: dueAt ?? task.dueDate,
                    kind: _taskKind(item.workType),
                    status: shouldComplete ? TaskStatus.done : task.status,
                  ),
                  reload: false,
                  scheduleNotification: false,
                  notify: false,
                );
                if (task.id != null) localTasks[task.id!] = task;
                changedLocally = true;
                if (sourceChanged) updated++;
                if (shouldComplete) completed++;
              }
            }

            if (task.id != null) {
              final taskLink = ClassroomTaskLink(
                googleUserId: profile.id,
                courseId: courseLink.courseId,
                courseWorkId: item.id,
                taskId: task.id!,
                submissionState: submission?.state ?? '',
                alternateLink: item.alternateLink,
                updatedAt: DateTime.now(),
              );
              await _store.saveTaskLink(taskLink);
              existingLinks[key] = taskLink;
            }
          }

          await _store.saveCourseLink(ClassroomCourseLink(
            googleUserId: courseLink.googleUserId,
            courseId: courseLink.courseId,
            subjectId: courseLink.subjectId,
            courseName: courseLink.courseName,
            courseState: courseLink.courseState,
            alternateLink: courseLink.alternateLink,
            lastSyncedAt: DateTime.now(),
          ));
        }
      } finally {
        if (changedLocally) await state.refreshTasksAfterBatch();
      }

      final syncTime = DateTime.now();
      account = profile.copyWith(classroomConnected: true, lastSyncAt: syncTime);
      await _store.saveAccount(account!);
      courseLinks = await _store.getCourseLinks(profile.id);
      taskLinks = await _store.getTaskLinks(profile.id);
      report = ClassroomSyncReport(created: created, updated: updated, completed: completed, skippedWithoutDueDate: skipped, courses: courseLinks.length);
      lastReport = report;
    });
    return report;
  }

  Future<void> openClassroom(String url) async {
    if (url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw StateError('Não foi possível abrir o Google Classroom.');
  }

  Future<void> clearLocalIntegration() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    await _store.clearAll();
    authenticated = false;
    account = null;
    courses = [];
    courseLinks = [];
    taskLinks = [];
    lastReport = null;
    initialized = false;
    notifyListeners();
  }

  Future<void> reloadLinks() async {
    final profile = account;
    if (profile == null) return;
    courseLinks = await _store.getCourseLinks(profile.id);
    taskLinks = await _store.getTaskLinks(profile.id);
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) throw StateError('Aguarde a operação atual terminar.');
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = _friendlyError(e);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final text = '$error'.replaceFirst('Bad state: ', '').replaceFirst('StateError: ', '');
    if (text.contains('clientConfigurationError')) return 'A configuração OAuth do Android não corresponde ao pacote/assinatura deste app.';
    return text;
  }

  static String normalizeCourseName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áàâãéèêíïóôõöúç ]'), ' ')
      .replaceAll(RegExp(r'\b(ads|202[0-9]|1|2|3|4|5|6|7|8|9|semestre|turma)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static TaskKind _taskKind(String workType) => switch (workType) {
        'ASSIGNMENT' => TaskKind.activity,
        'SHORT_ANSWER_QUESTION' => TaskKind.other,
        'MULTIPLE_CHOICE_QUESTION' => TaskKind.other,
        _ => TaskKind.other,
      };

  static String _classroomDescription(ClassroomCourseWork item) {
    final parts = <String>['Google Classroom • sincronizado'];
    if (item.description.trim().isNotEmpty) parts.add(item.description.trim());
    if (item.alternateLink.trim().isNotEmpty) parts.add('Abrir no Classroom: ${item.alternateLink.trim()}');
    return parts.join('\n\n');
  }
}
