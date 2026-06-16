import 'work_config.dart';

/// 当天类型
enum DayType {
  workday, // 工作日
  restPaid, // 带薪休息日
  restUnpaid // 无薪休息日
}

/// 实时薪资状态模型
class SalaryState {
  final double dailySalary; // 日薪
  final double earnedSalary; // 今日已赚
  final bool isWorking; // 当前是否处于工作时间段
  final DayType dayType; // 当天类型
  final double hourlyWage; // 时薪
  final int secondsUntilOffWork; // 距离下班还有多少秒

  SalaryState({
    required this.dailySalary,
    required this.earnedSalary,
    required this.isWorking,
    required this.dayType,
    this.hourlyWage = 0.0,
    this.secondsUntilOffWork = 0,
  });
}

/// 核心薪资计算器
class SalaryCalculator {
  /// 计算当前状态
  static SalaryState calculate({
    required DateTime currentDateTime,
    required WorkConfig config,
    DayType? dayTypeOverride,
  }) {
    // 1. 判断当天类型
    final dayType = dayTypeOverride ?? _getDayType(currentDateTime, config);
    if (dayType == DayType.restUnpaid) {
      // 无薪休息日，一切为0
      return SalaryState(
        dailySalary: 0.0,
        earnedSalary: 0.0,
        isWorking: false,
        dayType: dayType,
        hourlyWage: 0.0,
        secondsUntilOffWork: 0,
      );
    }

    // 2. 将配置的时间转换为基于当天零点的分钟数，方便计算
    final currentMinutes = currentDateTime.hour * 60 + currentDateTime.minute;
    final currentSeconds = currentMinutes * 60 + currentDateTime.second;

    final startSeconds = config.workStartHour * 3600 + config.workStartMinute * 60;
    final endSeconds = config.workEndHour * 3600 + config.workEndMinute * 60;
    final lunchStartSeconds = config.lunchStartHour * 3600 + config.lunchStartMinute * 60;
    final lunchEndSeconds = config.lunchEndHour * 3600 + config.lunchEndMinute * 60;

    // 3. 计算每日总工作秒数
    final totalWorkSeconds = _calculateValidWorkSeconds(
      currentSeconds: endSeconds,
      start: startSeconds,
      end: endSeconds,
      lunchStart: lunchStartSeconds,
      lunchEnd: lunchEndSeconds,
    );

    // 4. 计算当前已工作秒数
    final elapsedWorkSeconds = _calculateValidWorkSeconds(
      currentSeconds: currentSeconds,
      start: startSeconds,
      end: endSeconds,
      lunchStart: lunchStartSeconds,
      lunchEnd: lunchEndSeconds,
    );

    // 5. 计算薪资 (按月均 21.75 天计算日薪)
    final dailySalary = config.monthlySalary / 21.75;
    final salaryPerSecond = totalWorkSeconds > 0 ? dailySalary / totalWorkSeconds : 0.0;
    final earnedSalary = elapsedWorkSeconds * salaryPerSecond;

    // 6. 判断当前是否正在工作（如果今天是带薪休息日，则不计为“正在工作中”，虽然工资会涨）
    bool isWorking = false;
    if (dayType != DayType.restPaid) {
      isWorking = currentSeconds >= startSeconds && 
                  currentSeconds <= endSeconds && 
                  !(currentSeconds >= lunchStartSeconds && currentSeconds < lunchEndSeconds);
    }

    final hourlyWage = totalWorkSeconds > 0 ? dailySalary / (totalWorkSeconds / 3600.0) : 0.0;
    final secondsUntilOffWork = currentSeconds < endSeconds ? endSeconds - currentSeconds : 0;

    return SalaryState(
      dailySalary: dailySalary,
      earnedSalary: dayType == DayType.restPaid ? dailySalary : earnedSalary, // 如果是带薪休息日，直接拿全天工资
      isWorking: isWorking,
      dayType: dayType,
      hourlyWage: hourlyWage,
      secondsUntilOffWork: secondsUntilOffWork,
    );
  }

  /// 获取某天的属性（工作日/休息日等）
  static DayType _getDayType(DateTime date, WorkConfig config) {
    if (config.workMode == WorkMode.noRest) {
      return DayType.workday;
    }

    final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 法定补班最高优先级
    if (config.statutoryMakeupDays.contains(dateString)) {
      return DayType.workday;
    }

    // 法定节假日次之
    if (config.statutoryHolidays.contains(dateString)) {
      return DayType.restPaid;
    }

    // 常规排班
    final dow = date.weekday; // 1=Mon, 7=Sun
    bool isWorkday = false;
    
    switch (config.workMode) {
      case WorkMode.doubleOff:
        isWorkday = dow != DateTime.saturday && dow != DateTime.sunday;
        break;
      case WorkMode.singleOff:
        isWorkday = dow != DateTime.sunday;
        break;
      case WorkMode.bigSmallWeek:
        // 通过计算纪元周数判断大小周，偶数周双休，奇数周单休
        final epochDays = date.millisecondsSinceEpoch ~/ 86400000;
        final isEvenWeek = (epochDays ~/ 7) % 2 == 0;
        if (isEvenWeek) {
          isWorkday = dow != DateTime.saturday && dow != DateTime.sunday;
        } else {
          isWorkday = dow != DateTime.sunday;
        }
        break;
      case WorkMode.custom:
        isWorkday = config.customWorkDays.contains(dow);
        break;
      case WorkMode.noRest:
        isWorkday = true;
        break;
    }

    if (isWorkday) {
      return DayType.workday;
    } else {
      return config.isRestDayPaid ? DayType.restPaid : DayType.restUnpaid;
    }
  }

  /// 计算有效工作秒数（扣除午休）
  static int _calculateValidWorkSeconds({
    required int currentSeconds,
    required int start,
    required int end,
    required int lunchStart,
    required int lunchEnd,
  }) {
    if (currentSeconds <= start) return 0;

    final actualCurrent = currentSeconds > end ? end : currentSeconds;
    final totalElapsed = actualCurrent - start;

    int lunchElapsed = 0;
    if (actualCurrent > lunchStart) {
      final actualLunchEnd = actualCurrent > lunchEnd ? lunchEnd : actualCurrent;
      lunchElapsed = actualLunchEnd - lunchStart;
    }

    final validSeconds = totalElapsed - lunchElapsed;
    return validSeconds > 0 ? validSeconds : 0;
  }
}
