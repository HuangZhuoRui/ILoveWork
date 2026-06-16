import 'dart:convert';

/// 工作模式
enum WorkMode {
  doubleOff, // 双休
  singleOff, // 单休
  bigSmallWeek, // 大小周
  custom, // 自定义调休
  noRest // 无休
}

/// 工作配置模型
class WorkConfig {
  final double monthlySalary; // 月薪
  final WorkMode workMode; // 工作模式
  final int workStartHour; // 上班时间-小时
  final int workStartMinute; // 上班时间-分钟
  final int workEndHour; // 下班时间-小时
  final int workEndMinute; // 下班时间-分钟
  final int lunchStartHour; // 午休开始-小时
  final int lunchStartMinute; // 午休开始-分钟
  final int lunchEndHour; // 午休结束-小时
  final int lunchEndMinute; // 午休结束-分钟
  final List<int> customWorkDays; // 自定义工作日 (1-7, 1为周一)
  final List<String> statutoryHolidays; // 法定节假日 (YYYY-MM-DD)
  final List<String> statutoryMakeupDays; // 法定补班日 (YYYY-MM-DD)
  final bool isRestDayPaid; // 休息日是否带薪
  final int payday; // 发薪日 (1-31)
  final double workHoursPerDay; // 每日工作时长

  WorkConfig({
    this.monthlySalary = 10000.0,
    this.workMode = WorkMode.doubleOff,
    this.workStartHour = 9,
    this.workStartMinute = 0,
    this.workEndHour = 18,
    this.workEndMinute = 0,
    this.lunchStartHour = 12,
    this.lunchStartMinute = 0,
    this.lunchEndHour = 13,
    this.lunchEndMinute = 30,
    this.customWorkDays = const [1, 2, 3, 4, 5],
    this.statutoryHolidays = const [],
    this.statutoryMakeupDays = const [],
    this.isRestDayPaid = false,
    this.payday = 10,
    this.workHoursPerDay = 9.0,
  });

  /// 转换为 JSON Map (为了方便与原生交互和本地存储)
  Map<String, dynamic> toMap() {
    return {
      'monthlySalary': monthlySalary,
      'workMode': workMode.index,
      'workStartHour': workStartHour,
      'workStartMinute': workStartMinute,
      'workEndHour': workEndHour,
      'workEndMinute': workEndMinute,
      'lunchStartHour': lunchStartHour,
      'lunchStartMinute': lunchStartMinute,
      'lunchEndHour': lunchEndHour,
      'lunchEndMinute': lunchEndMinute,
      'customWorkDays': customWorkDays,
      'statutoryHolidays': statutoryHolidays,
      'statutoryMakeupDays': statutoryMakeupDays,
      'isRestDayPaid': isRestDayPaid,
      'payday': payday,
      'workHoursPerDay': workHoursPerDay,
    };
  }

  /// 序列化为 JSON 字符串，供 shared_preferences 或原生小组件读取
  String toJson() => json.encode(toMap());

  /// 从 JSON Map 解析
  factory WorkConfig.fromMap(Map<String, dynamic> map) {
    return WorkConfig(
      monthlySalary: (map['monthlySalary'] as num?)?.toDouble() ?? 10000.0,
      workMode: WorkMode.values[map['workMode'] as int? ?? 0],
      workStartHour: map['workStartHour'] as int? ?? 9,
      workStartMinute: map['workStartMinute'] as int? ?? 0,
      workEndHour: map['workEndHour'] as int? ?? 18,
      workEndMinute: map['workEndMinute'] as int? ?? 0,
      lunchStartHour: map['lunchStartHour'] as int? ?? 12,
      lunchStartMinute: map['lunchStartMinute'] as int? ?? 0,
      lunchEndHour: map['lunchEndHour'] as int? ?? 13,
      lunchEndMinute: map['lunchEndMinute'] as int? ?? 30,
      customWorkDays: List<int>.from(map['customWorkDays'] ?? [1, 2, 3, 4, 5]),
      statutoryHolidays: List<String>.from(map['statutoryHolidays'] ?? []),
      statutoryMakeupDays: List<String>.from(map['statutoryMakeupDays'] ?? []),
      isRestDayPaid: map['isRestDayPaid'] as bool? ?? false,
      payday: map['payday'] as int? ?? 10,
      workHoursPerDay: (map['workHoursPerDay'] as num?)?.toDouble() ?? 9.0,
    );
  }

  /// 从 JSON 字符串解析
  factory WorkConfig.fromJson(String source) => WorkConfig.fromMap(json.decode(source));

  /// 拷贝出一个新的实例用于更新属性
  WorkConfig copyWith({
    double? monthlySalary,
    WorkMode? workMode,
    int? workStartHour,
    int? workStartMinute,
    int? workEndHour,
    int? workEndMinute,
    int? lunchStartHour,
    int? lunchStartMinute,
    int? lunchEndHour,
    int? lunchEndMinute,
    List<int>? customWorkDays,
    List<String>? statutoryHolidays,
    List<String>? statutoryMakeupDays,
    bool? isRestDayPaid,
    int? payday,
    double? workHoursPerDay,
  }) {
    return WorkConfig(
      monthlySalary: monthlySalary ?? this.monthlySalary,
      workMode: workMode ?? this.workMode,
      workStartHour: workStartHour ?? this.workStartHour,
      workStartMinute: workStartMinute ?? this.workStartMinute,
      workEndHour: workEndHour ?? this.workEndHour,
      workEndMinute: workEndMinute ?? this.workEndMinute,
      lunchStartHour: lunchStartHour ?? this.lunchStartHour,
      lunchStartMinute: lunchStartMinute ?? this.lunchStartMinute,
      lunchEndHour: lunchEndHour ?? this.lunchEndHour,
      lunchEndMinute: lunchEndMinute ?? this.lunchEndMinute,
      customWorkDays: customWorkDays ?? this.customWorkDays,
      statutoryHolidays: statutoryHolidays ?? this.statutoryHolidays,
      statutoryMakeupDays: statutoryMakeupDays ?? this.statutoryMakeupDays,
      isRestDayPaid: isRestDayPaid ?? this.isRestDayPaid,
      payday: payday ?? this.payday,
      workHoursPerDay: workHoursPerDay ?? this.workHoursPerDay,
    );
  }
}
