import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 영상 생성용 포그라운드 서비스(백그라운드 유지) + 완료 로컬 알림
class Notify {
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dubbingo_render',
        channelName: '영상 만들기',
        channelDescription: '영상 생성 진행 상태',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  /// 알림 권한 요청(Android 13+)
  static Future<void> requestPermission() async {
    final p = await FlutterForegroundTask.checkNotificationPermission();
    if (p != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// 렌더 시작 — 포그라운드 서비스 켜기(백그라운드/화면잠금에도 유지)
  static Future<void> startRender() => FlutterForegroundTask.startService(
    serviceTypes: [ForegroundServiceTypes.dataSync],
    notificationTitle: '영상 만드는 중',
    notificationText: '0%',
  );

  static Future<void> updateRender(int pct) =>
      FlutterForegroundTask.updateService(
        notificationTitle: '영상 만드는 중',
        notificationText: '$pct%',
      );

  static Future<void> stopRender() => FlutterForegroundTask.stopService();

  /// 완료 알림(서비스 종료 후에도 남는 일반 알림, 탭하면 앱 열림)
  static Future<void> renderDone() async {
    await _local.show(
      id: 1001,
      title: '🎬 영상이 완성됐어요!',
      body: '탭해서 확인하세요',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'dubbingo_done',
          '영상 완성',
          channelDescription: '영상 생성 완료 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
