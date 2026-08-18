import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';

Future<void> markAttendanceWithFeedback(
  BuildContext context,
  AppState state,
  ClassSession session,
  AttendanceStatus status,
) async {
  await state.markAttendance(session, status);
  if (!context.mounted) return;

  // Há aparelhos/ambientes desktop que não oferecem feedback háptico. Isso é
  // opcional e nunca deve impedir a confirmação visual após o dado já ter sido salvo.
  try {
    await HapticFeedback.selectionClick();
  } catch (_) {}

  final count = session.classCount;
  final classesLabel = '$count aula${count == 1 ? '' : 's'}';
  final (icon, message) = switch (status) {
    AttendanceStatus.present => (
        Icons.check_circle_rounded,
        'Presença registrada — $classesLabel contabilizada${count == 1 ? '' : 's'}.',
      ),
    AttendanceStatus.absent => (
        Icons.cancel_rounded,
        'Falta registrada — $classesLabel contabilizada${count == 1 ? '' : 's'}.',
      ),
    AttendanceStatus.cancelled => (
        Icons.event_busy_rounded,
        'Aula marcada como cancelada.',
      ),
    AttendanceStatus.pending => (
        Icons.schedule_rounded,
        'Presença voltou para pendente.',
      ),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
