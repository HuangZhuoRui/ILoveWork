import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../domain/work_config.dart';

/// 定时通知服务，基于 Flutter 推荐的最佳实践（利用原生系统的 AlarmManager/UNUserNotificationCenter）
class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int _getOffWorkId = 1001;
  static const int _lunchId = 1002;

  Future<void> init() async {
    // 初始化时区数据
    tz.initializeTimeZones();
    // 默认使用本地时区
    tz.setLocalLocation(tz.local);

    // 初始化安卓配置 (需要确保在 android/app/src/main/res/drawable/ 有相应的 icon)
    // 这里默认使用 Flutter 生成的 app_icon，如果没有则填 '@mipmap/ic_launcher'
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // 初始化 macOS/iOS 配置 (需要申请权限)
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  /// 调度每日的上下班和午休提醒
  Future<void> scheduleAlarms(WorkConfig config) async {
    // 先取消旧的定时器
    await _flutterLocalNotificationsPlugin.cancelAll();

    final now = DateTime.now();

    // 调度下班提醒
    final offWorkTime = DateTime(now.year, now.month, now.day, config.workEndHour, config.workEndMinute);
    await _scheduleDailyNotification(
      id: _getOffWorkId,
      title: '🎉 下班啦！',
      body: '赚钱时间结束，赶紧跑路！',
      time: offWorkTime,
    );

    // 调度午休提醒
    final lunchTime = DateTime(now.year, now.month, now.day, config.lunchStartHour, config.lunchStartMinute);
    await _scheduleDailyNotification(
      id: _lunchId,
      title: '🍱 午休时间',
      body: '该去吃饭休息啦，保护好革命本钱。',
      time: lunchTime,
    );
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required DateTime time,
  }) async {
    // 将 DateTime 转为 tz.TZDateTime
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(time, tz.local);
    // 如果时间已经过了，则调度到明天
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'ilovework_channel', // channel id
          '打卡提醒', // channel name
          channelDescription: '下班及午休提醒',
          importance: Importance.max,
          priority: Priority.high,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // 绕过安卓的 Doze 休眠模式，确保准时
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 每天重复
    );
  }
}
