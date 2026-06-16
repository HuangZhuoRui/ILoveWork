import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'repository/config_repository.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'ui/theme.dart';
import 'ui/home_page.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务与配置仓库
  final notificationService = NotificationService();
  await notificationService.init();

  final configRepository = ConfigRepository();
  await configRepository.init();

  // 每次启动时，基于最新的配置重新注册一次通知调度
  await notificationService.scheduleAlarms(configRepository.currentConfig);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(configRepository, notificationService),
      child: const ILoveWorkApp(),
    ),
  );
}

class ILoveWorkApp extends StatelessWidget {
  const ILoveWorkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我爱上班',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // 自动跟随系统白/暗色模式
      home: const HomePage(),
    );
  }
}
