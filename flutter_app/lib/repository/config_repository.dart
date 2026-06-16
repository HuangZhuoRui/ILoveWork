import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../domain/work_config.dart';

/// 管理用户配置的存取，并负责将数据桥接至系统的原生小组件
class ConfigRepository {
  static const String _configKey = 'work_config';
  // 与原生通信的 App Group (iOS/macOS) 和 Widget 名称
  static const String _appGroupId = 'group.com.suseoaa.ilovework'; // 根据你实际的 Apple Developer App Group ID 调整
  static const String _macOsWidgetName = 'ILoveWorkWidget';
  static const String _androidWidgetName = 'ILoveWorkWidgetProvider';

  late SharedPreferences _prefs;
  WorkConfig _currentConfig = WorkConfig();

  WorkConfig get currentConfig => _currentConfig;

  /// 初始化并加载本地配置
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // 初始化 HomeWidget 配置
    await HomeWidget.setAppGroupId(_appGroupId);

    final configJson = _prefs.getString(_configKey);
    if (configJson != null) {
      try {
        _currentConfig = WorkConfig.fromJson(configJson);
      } catch (e) {
        // 如果解析失败，使用默认配置
        _currentConfig = WorkConfig();
      }
    } else {
      _currentConfig = WorkConfig();
    }
  }

  /// 保存配置并同步给原生小组件
  Future<void> saveConfig(WorkConfig config) async {
    _currentConfig = config;
    final jsonStr = config.toJson();
    
    // 1. 保存到 Flutter 的 SharedPreferences
    await _prefs.setString(_configKey, jsonStr);

    // 2. 桥接数据到原生的 SharedStorage (App Group / Android SharedPreferences)
    // 原生层需要通过读取 key 为 "widget_work_config" 的字符串来解析配置
    await HomeWidget.saveWidgetData<String>('widget_work_config', jsonStr);

    // 3. 通知原生层主动刷新小组件 Timeline/UI
    try {
      await HomeWidget.updateWidget(
        iOSName: _macOsWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (e) {
      // 在一些不支持小组件的环境下可能会报错，忽略即可
    }
  }
}
