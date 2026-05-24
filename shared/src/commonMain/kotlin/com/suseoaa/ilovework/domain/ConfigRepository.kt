package com.suseoaa.ilovework.domain

import com.russhwolf.settings.Settings

class ConfigRepository(private val settings: Settings) {
    
    fun getWorkConfig(): WorkConfig {
        val defaultCustomWorkDays = setOf(1, 2, 3, 4, 5)
        val customDaysStr = settings.getString("customWorkDays", defaultCustomWorkDays.joinToString(","))
        val customWorkDays = if (customDaysStr.isBlank()) emptySet() else customDaysStr.split(",").mapNotNull { it.toIntOrNull() }.toSet()
        
        val holidaysStr = settings.getString("statutoryHolidays", "")
        val holidays = if (holidaysStr.isBlank()) emptySet() else holidaysStr.split(",").toSet()

        val makeupDaysStr = settings.getString("statutoryMakeupDays", "")
        val makeupDays = if (makeupDaysStr.isBlank()) emptySet() else makeupDaysStr.split(",").toSet()

        return WorkConfig(
            monthlySalary = settings.getDouble("monthlySalary", 10000.0),
            workMode = WorkMode.valueOf(settings.getString("workMode", WorkMode.DOUBLE_OFF.name)),
            workStartHour = settings.getInt("workStartHour", 9),
            workStartMinute = settings.getInt("workStartMinute", 0),
            workEndHour = settings.getInt("workEndHour", 18),
            workEndMinute = settings.getInt("workEndMinute", 0),
            lunchStartHour = settings.getInt("lunchStartHour", 12),
            lunchStartMinute = settings.getInt("lunchStartMinute", 0),
            lunchEndHour = settings.getInt("lunchEndHour", 13),
            lunchEndMinute = settings.getInt("lunchEndMinute", 30),
            customWorkDays = customWorkDays,
            statutoryHolidays = holidays,
            statutoryMakeupDays = makeupDays,
            isRestDayPaid = settings.getBoolean("isRestDayPaid", false),
            oaUserName = settings.getString("oaUserName", "黄卓睿"),
            oaAccessToken = settings.getString("oaAccessToken", ""),
            oaConnected = settings.getBoolean("oaConnected", false),
            workHoursPerDay = settings.getDouble("workHoursPerDay", 9.0),
            enableAutoOASync = settings.getBoolean("enableAutoOASync", true),
            lastOASyncDate = settings.getString("lastOASyncDate", ""),
            todayClockInTime = settings.getString("todayClockInTime", "")
        )
    }

    fun saveWorkConfig(config: WorkConfig) {
        settings.putDouble("monthlySalary", config.monthlySalary)
        settings.putString("workMode", config.workMode.name)
        settings.putInt("workStartHour", config.workStartHour)
        settings.putInt("workStartMinute", config.workStartMinute)
        settings.putInt("workEndHour", config.workEndHour)
        settings.putInt("workEndMinute", config.workEndMinute)
        settings.putInt("lunchStartHour", config.lunchStartHour)
        settings.putInt("lunchStartMinute", config.lunchStartMinute)
        settings.putInt("lunchEndHour", config.lunchEndHour)
        settings.putInt("lunchEndMinute", config.lunchEndMinute)
        settings.putString("customWorkDays", config.customWorkDays.joinToString(","))
        settings.putString("statutoryHolidays", config.statutoryHolidays.joinToString(","))
        settings.putString("statutoryMakeupDays", config.statutoryMakeupDays.joinToString(","))
        settings.putBoolean("isRestDayPaid", config.isRestDayPaid)
        settings.putString("oaUserName", config.oaUserName)
        settings.putString("oaAccessToken", config.oaAccessToken)
        settings.putBoolean("oaConnected", config.oaConnected)
        settings.putDouble("workHoursPerDay", config.workHoursPerDay)
        settings.putBoolean("enableAutoOASync", config.enableAutoOASync)
        settings.putString("lastOASyncDate", config.lastOASyncDate)
        settings.putString("todayClockInTime", config.todayClockInTime)
    }
}
