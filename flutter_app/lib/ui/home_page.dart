import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/salary_calculator.dart';
import '../domain/work_config.dart';
import '../state/app_state.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _timer;
  late SalaryState _salaryState;

  @override
  void initState() {
    super.initState();
    // 初始计算一次
    _updateSalary();
    // 开启高频定时器，每秒刷新一次工资跳动
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateSalary();
    });
  }

  void _updateSalary() {
    if (!mounted) return;
    final config = context.read<AppState>().config;
    setState(() {
      _salaryState = SalaryCalculator.calculate(
        currentDateTime: DateTime.now(),
        config: config,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 Config 的变化（如果用户从设置页返回，config 可能变了）
    context.watch<AppState>();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我爱上班', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ).then((_) {
                // 设置返回后立刻刷新一次
                _updateSalary();
              });
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                '今日已赚 (元)',
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 薪资跳动数字
              _buildSalaryDisplay(theme),
              const SizedBox(height: 40),
              
              // 状态与倒计时卡片
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusRow(theme, '当前状态', _getStatusText()),
                      const Divider(height: 32),
                      _buildStatusRow(theme, '日薪基数', '¥ ${_salaryState.dailySalary.toStringAsFixed(2)}'),
                      const Divider(height: 32),
                      _buildCountdownRow(theme),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryDisplay(ThemeData theme) {
    final int part = _salaryState.earnedSalary.truncate();
    final double decimal = _salaryState.earnedSalary - part;
    final decimalStr = decimal.toStringAsFixed(6).substring(2); // 取小数点后6位

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '¥ $part.',
            style: theme.textTheme.displayLarge?.copyWith(fontSize: 64),
          ),
          TextSpan(
            text: decimalStr,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 32,
              color: theme.textTheme.displayLarge?.color?.withOpacity(0.5),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  String _getStatusText() {
    if (_salaryState.dayType == DayType.restUnpaid) return '🛌 无薪休息日';
    if (_salaryState.dayType == DayType.restPaid) return '🎉 带薪休息日 (躺赚中)';
    if (_salaryState.isWorking) return '💻 努力搬砖中';
    
    // 如果是工作日但不在工作时间
    if (_salaryState.secondsUntilOffWork == 0) return '🍻 已下班';
    return '🍱 休息时间';
  }

  Widget _buildStatusRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16)),
        Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCountdownRow(ThemeData theme) {
    int totalSeconds = _salaryState.secondsUntilOffWork;
    if (totalSeconds <= 0 || _salaryState.dayType != DayType.workday) {
      return _buildStatusRow(theme, '下班倒计时', '--:--:--');
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    final timeStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('下班倒计时', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16)),
        Text(
          timeStr, 
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 24, 
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()], // 等宽数字，防止跳动
          ),
        ),
      ],
    );
  }
}
