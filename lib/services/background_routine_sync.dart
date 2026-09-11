import '../data/app_database.dart';
import 'notification_service.dart';

class BackgroundRoutineSync {
  BackgroundRoutineSync._();
  static final BackgroundRoutineSync instance = BackgroundRoutineSync._();

  final AppDatabase _db = AppDatabase.instance;

  Future<bool> consumePendingChange() async {
    final marker = await _db.getSetting(NotificationService.backgroundRoutineActionKey);
    if (marker == null || marker.trim().isEmpty) return false;
    await _db.setSetting(NotificationService.backgroundRoutineActionKey, '');
    return true;
  }
}
