import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/work_config.dart';
import '../state/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _salaryController;
  late WorkConfig _draftConfig;

  @override
  void initState() {
    super.initState();
    // 拷贝一份当前的配置用于草稿编辑
    _draftConfig = context.read<AppState>().config.copyWith();
    _salaryController = TextEditingController(text: _draftConfig.monthlySalary.toInt().toString());
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({
    required BuildContext context,
    required int initialHour,
    required int initialMinute,
    required void Function(TimeOfDay) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );
    if (picked != null) {
      setState(() {
        onPicked(picked);
      });
    }
  }

  Future<void> _saveConfig() async {
    final salaryStr = _salaryController.text;
    final salary = double.tryParse(salaryStr) ?? 0.0;
    
    _draftConfig = _draftConfig.copyWith(monthlySalary: salary);

    // 将更新后的配置应用到全局状态
    await context.read<AppState>().updateConfig(_draftConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存，原生小组件与通知已同步更新')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('打工配置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 月薪设置
          _buildSectionTitle(theme, '💰 薪资设定'),
          const SizedBox(height: 16),
          TextField(
            controller: _salaryController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '你的月薪 (元)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.cardColor,
            ),
          ),
          const SizedBox(height: 32),

          // 上下班时间设置
          _buildSectionTitle(theme, '⏱ 时间设定'),
          const SizedBox(height: 16),
          _buildTimeTile(
            title: '上班时间',
            hour: _draftConfig.workStartHour,
            minute: _draftConfig.workStartMinute,
            onTap: () => _pickTime(
              context: context,
              initialHour: _draftConfig.workStartHour,
              initialMinute: _draftConfig.workStartMinute,
              onPicked: (t) => _draftConfig = _draftConfig.copyWith(workStartHour: t.hour, workStartMinute: t.minute),
            ),
          ),
          _buildTimeTile(
            title: '下班时间',
            hour: _draftConfig.workEndHour,
            minute: _draftConfig.workEndMinute,
            onTap: () => _pickTime(
              context: context,
              initialHour: _draftConfig.workEndHour,
              initialMinute: _draftConfig.workEndMinute,
              onPicked: (t) => _draftConfig = _draftConfig.copyWith(workEndHour: t.hour, workEndMinute: t.minute),
            ),
          ),
          _buildTimeTile(
            title: '午休开始时间',
            hour: _draftConfig.lunchStartHour,
            minute: _draftConfig.lunchStartMinute,
            onTap: () => _pickTime(
              context: context,
              initialHour: _draftConfig.lunchStartHour,
              initialMinute: _draftConfig.lunchStartMinute,
              onPicked: (t) => _draftConfig = _draftConfig.copyWith(lunchStartHour: t.hour, lunchStartMinute: t.minute),
            ),
          ),
          _buildTimeTile(
            title: '午休结束时间',
            hour: _draftConfig.lunchEndHour,
            minute: _draftConfig.lunchEndMinute,
            onTap: () => _pickTime(
              context: context,
              initialHour: _draftConfig.lunchEndHour,
              initialMinute: _draftConfig.lunchEndMinute,
              onPicked: (t) => _draftConfig = _draftConfig.copyWith(lunchEndHour: t.hour, lunchEndMinute: t.minute),
            ),
          ),
          const SizedBox(height: 32),

          // 排班模式设置
          _buildSectionTitle(theme, '📅 排班模式'),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: ButtonTheme(
                alignedDropdown: true,
                child: DropdownButton<WorkMode>(
                  isExpanded: true,
                  value: _draftConfig.workMode,
                  items: WorkMode.values.map((mode) {
                    return DropdownMenuItem<WorkMode>(
                      value: mode,
                      child: Text(_getWorkModeString(mode)),
                    );
                  }).toList(),
                  onChanged: (mode) {
                    if (mode != null) {
                      setState(() {
                        _draftConfig = _draftConfig.copyWith(workMode: mode);
                      });
                    }
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _saveConfig,
            child: const Text('保存配置', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTimeTile({required String title, required int hour, required int minute, required VoidCallback onTap}) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        onTap: onTap,
      ),
    );
  }

  String _getWorkModeString(WorkMode mode) {
    switch (mode) {
      case WorkMode.doubleOff: return '周末双休';
      case WorkMode.singleOff: return '单休 (周日休)';
      case WorkMode.bigSmallWeek: return '大小周';
      case WorkMode.custom: return '自定义调休';
      case WorkMode.noRest: return '全年无休 (狠人)';
    }
  }
}
