import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Android : icône par défaut
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS : permissions
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialisation globale
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (kDebugMode) {
          print('Notification tapée : ${response.payload}');
        }
      },
    );

    // Permission Android 13+ (ignore automatiquement sur <13)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl =
      _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        if (kDebugMode) {
          print("Permission notifications Android (13+) : $granted");
        }
      }
    }

    // Création du channel Android (obligatoire Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'default_channel',
      'Notifications',
      description: 'Canal pour les notifications de l\'application',
      importance: Importance.max,
    );

    final androidPlugin =
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  // Afficher notification
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Notifications',
      channelDescription: 'Canal pour les notifications de l\'application',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
