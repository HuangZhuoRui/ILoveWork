import 'package:flutter/material.dart';
import '../domain/work_config.dart';
import '../repository/config_repository.dart';
import '../services/notification_service.dart';

/// 管理全局状态，并将配置更改通知给 UI
class AppState extends ChangeNotifier {
  final ConfigRepository _repository;
  final NotificationService _notificationService;

  AppState(this._repository, this._notificationService);

  WorkConfig get config => _repository.currentConfig;

  /// 更新配置并触发相关副作用（持久化、更新小组件、重新调度通知、更新UI）
  Future<void> updateConfig(WorkConfig newConfig) async {
    await _repository.saveConfig(newConfig);
    await _notificationService.scheduleAlarms(newConfig);
    notifyListeners();
  }
}
