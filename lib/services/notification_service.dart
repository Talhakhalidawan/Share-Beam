import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/models.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _msgActionCtrl = StreamController<Map<String, String>>.broadcast();
  static final _persistCtrl = StreamController<String?>.broadcast();

  static Stream<Map<String, String>> get messageActionStream => _msgActionCtrl.stream;
  static Stream<String?> get persistentActionStream => _persistCtrl.stream;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');

    await _plugin.initialize(
      InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
        linux: linux,
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        'sharebeam_messages',
        'Messages',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        'sharebeam_persistent',
        'Quick Send',
        importance: Importance.low,
      ),
    );

    if (!kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS)) {
      await androidPlugin?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static void _onResponse(NotificationResponse response) {
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotificationAction) {
      if (response.actionId == 'copy_text') {
        _msgActionCtrl.add({'action': 'copy_text', 'payload': response.payload ?? ''});
      } else if (response.actionId == 'save_image') {
        _msgActionCtrl.add({'action': 'save_image', 'payload': response.payload ?? ''});
      } else if (response.actionId == 'send_quick') {
        _persistCtrl.add(response.input);
      } else if (response.actionId == 'disable_persistent') {
        _persistCtrl.add(null);
      }
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    _onResponse(response);
  }

  static Future<void> showMessageNotification(
    SharePayload payload, {
    String? localPath,
  }) async {
    final isText = payload.type == FileTransferType.text;
    final isImage = payload.type == FileTransferType.image;

    final androidActions = <AndroidNotificationAction>[];
    if (isText) {
      androidActions.add(
        const AndroidNotificationAction('copy_text', 'Copy', showsUserInterface: false),
      );
    } else if (isImage && localPath != null) {
      androidActions.add(
        const AndroidNotificationAction('save_image', 'Save', showsUserInterface: false),
      );
    }

    final androidDetails = AndroidNotificationDetails(
      'sharebeam_messages',
      'Messages',
      channelDescription: 'New ShareBeam messages',
      importance: Importance.high,
      priority: Priority.high,
      actions: androidActions,
      styleInformation: (isImage && localPath != null)
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(localPath),
              hideExpandedLargeIcon: true,
            )
          : null,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    await _plugin.show(
      payload.id.hashCode,
      payload.senderName,
      isText ? (payload.data ?? 'New message') : 'Sent ${payload.fileName}',
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
        linux: linuxDetails,
      ),
      payload: jsonEncode(payload.toJson()),
    );
  }

  static Future<void> showPersistentNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'sharebeam_persistent',
      'Quick Send',
      channelDescription: 'Quickly send a message',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'send_quick',
          'Send',
          inputs: [AndroidNotificationActionInput(label: 'Type a message...')],
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'disable_persistent',
          'Disable',
          showsUserInterface: false,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();

    await _plugin.show(
      99999,
      'ShareBeam Quick Send',
      'Tap to send a message instantly',
      const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
        linux: linuxDetails,
      ),
    );
  }

  static Future<void> cancelPersistent() async {
    await _plugin.cancel(99999);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}