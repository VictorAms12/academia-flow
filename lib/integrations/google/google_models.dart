class GoogleAccountProfile {
  const GoogleAccountProfile({
    required this.id,
    required this.email,
    this.displayName = '',
    this.photoUrl = '',
    this.classroomConnected = false,
    this.lastSyncAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool classroomConnected;
  final DateTime? lastSyncAt;

  GoogleAccountProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? classroomConnected,
    DateTime? lastSyncAt,
    bool clearLastSync = false,
  }) =>
      GoogleAccountProfile(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        classroomConnected: classroomConnected ?? this.classroomConnected,
        lastSyncAt: clearLastSync ? null : lastSyncAt ?? this.lastSyncAt,
      );

  Map<String, Object?> toMap() => {
        'singleton_id': 1,
        'google_user_id': id,
        'email': email,
        'display_name': displayName,
        'photo_url': photoUrl,
        'classroom_connected': classroomConnected ? 1 : 0,
        'last_sync_at': lastSyncAt?.toIso8601String(),
      };

  factory GoogleAccountProfile.fromMap(Map<String, Object?> map) =>
      GoogleAccountProfile(
        id: (map['google_user_id'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        displayName: (map['display_name'] as String?) ?? '',
        photoUrl: (map['photo_url'] as String?) ?? '',
        classroomConnected: ((map['classroom_connected'] as int?) ?? 0) == 1,
        lastSyncAt: DateTime.tryParse((map['last_sync_at'] as String?) ?? ''),
      );
}

class ClassroomCourse {
  const ClassroomCourse({
    required this.id,
    required this.name,
    this.section = '',
    this.state = '',
    this.alternateLink = '',
  });

  final String id;
  final String name;
  final String section;
  final String state;
  final String alternateLink;

  factory ClassroomCourse.fromJson(Map<String, dynamic> json) => ClassroomCourse(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        section: '${json['section'] ?? ''}',
        state: '${json['courseState'] ?? ''}',
        alternateLink: '${json['alternateLink'] ?? ''}',
      );
}

class ClassroomCourseLink {
  const ClassroomCourseLink({
    required this.googleUserId,
    required this.courseId,
    required this.subjectId,
    required this.courseName,
    this.courseState = '',
    this.alternateLink = '',
    this.lastSyncedAt,
  });

  final String googleUserId;
  final String courseId;
  final int subjectId;
  final String courseName;
  final String courseState;
  final String alternateLink;
  final DateTime? lastSyncedAt;

  Map<String, Object?> toMap() => {
        'google_user_id': googleUserId,
        'classroom_course_id': courseId,
        'subject_id': subjectId,
        'classroom_name': courseName,
        'course_state': courseState,
        'alternate_link': alternateLink,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
      };

  factory ClassroomCourseLink.fromMap(Map<String, Object?> map) => ClassroomCourseLink(
        googleUserId: (map['google_user_id'] as String?) ?? '',
        courseId: (map['classroom_course_id'] as String?) ?? '',
        subjectId: map['subject_id'] as int,
        courseName: (map['classroom_name'] as String?) ?? '',
        courseState: (map['course_state'] as String?) ?? '',
        alternateLink: (map['alternate_link'] as String?) ?? '',
        lastSyncedAt: DateTime.tryParse((map['last_synced_at'] as String?) ?? ''),
      );
}

class ClassroomCourseWork {
  const ClassroomCourseWork({
    required this.courseId,
    required this.id,
    required this.title,
    this.description = '',
    this.alternateLink = '',
    this.workType = '',
    this.updateTime,
    this.dueAt,
  });

  final String courseId;
  final String id;
  final String title;
  final String description;
  final String alternateLink;
  final String workType;
  final DateTime? updateTime;
  final DateTime? dueAt;

  factory ClassroomCourseWork.fromJson(Map<String, dynamic> json) {
    DateTime? dueAt;
    final rawDate = json['dueDate'];
    if (rawDate is Map<String, dynamic>) {
      final year = (rawDate['year'] as num?)?.toInt();
      final month = (rawDate['month'] as num?)?.toInt();
      final day = (rawDate['day'] as num?)?.toInt();
      if (year != null && month != null && day != null) {
        final rawTime = json['dueTime'];
        var hour = 23;
        var minute = 59;
        var second = 0;
        if (rawTime is Map<String, dynamic>) {
          hour = (rawTime['hours'] as num?)?.toInt() ?? hour;
          minute = (rawTime['minutes'] as num?)?.toInt() ?? minute;
          second = (rawTime['seconds'] as num?)?.toInt() ?? second;
        }
        dueAt = DateTime.utc(year, month, day, hour, minute, second).toLocal();
      }
    }
    return ClassroomCourseWork(
      courseId: '${json['courseId'] ?? ''}',
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      description: '${json['description'] ?? ''}',
      alternateLink: '${json['alternateLink'] ?? ''}',
      workType: '${json['workType'] ?? ''}',
      updateTime: DateTime.tryParse('${json['updateTime'] ?? ''}'),
      dueAt: dueAt,
    );
  }
}

class ClassroomSubmission {
  const ClassroomSubmission({
    required this.courseWorkId,
    this.state = '',
    this.late = false,
    this.assignedGrade,
  });

  final String courseWorkId;
  final String state;
  final bool late;
  final double? assignedGrade;

  bool get submitted => state == 'TURNED_IN' || state == 'RETURNED';

  factory ClassroomSubmission.fromJson(Map<String, dynamic> json) => ClassroomSubmission(
        courseWorkId: '${json['courseWorkId'] ?? ''}',
        state: '${json['state'] ?? ''}',
        late: json['late'] == true,
        assignedGrade: (json['assignedGrade'] as num?)?.toDouble(),
      );
}

class ClassroomTaskLink {
  const ClassroomTaskLink({
    required this.googleUserId,
    required this.courseId,
    required this.courseWorkId,
    required this.taskId,
    this.submissionState = '',
    this.alternateLink = '',
    this.updatedAt,
  });

  final String googleUserId;
  final String courseId;
  final String courseWorkId;
  final int taskId;
  final String submissionState;
  final String alternateLink;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() => {
        'google_user_id': googleUserId,
        'classroom_course_id': courseId,
        'classroom_coursework_id': courseWorkId,
        'task_id': taskId,
        'submission_state': submissionState,
        'alternate_link': alternateLink,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory ClassroomTaskLink.fromMap(Map<String, Object?> map) => ClassroomTaskLink(
        googleUserId: (map['google_user_id'] as String?) ?? '',
        courseId: (map['classroom_course_id'] as String?) ?? '',
        courseWorkId: (map['classroom_coursework_id'] as String?) ?? '',
        taskId: map['task_id'] as int,
        submissionState: (map['submission_state'] as String?) ?? '',
        alternateLink: (map['alternate_link'] as String?) ?? '',
        updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      );
}

class ClassroomSyncReport {
  const ClassroomSyncReport({
    required this.created,
    required this.updated,
    required this.completed,
    required this.skippedWithoutDueDate,
    required this.courses,
  });

  final int created;
  final int updated;
  final int completed;
  final int skippedWithoutDueDate;
  final int courses;

  int get changed => created + updated + completed;
}
