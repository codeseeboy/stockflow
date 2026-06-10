import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android system notifications (status-bar, Swiggy/Zomato style) for
/// admin broadcasts arriving in real time. No-op on web.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // Plugin unavailable (e.g. desktop) — in-app banners still work.
    }
  }

  static Future<void> show(String title, String body) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'stockflow_updates',
          'Order updates',
          channelDescription: 'Order window openings, stock and order status updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      );
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (_) {}
  }
}
