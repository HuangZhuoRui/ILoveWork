package com.suseoaa.ilovework.reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.suseoaa.ilovework.domain.ConfigRepository
import com.suseoaa.ilovework.domain.createSettings
import java.util.Calendar

object ReminderScheduler {

    fun scheduleReminders(context: Context) {
        val repository = ConfigRepository(createSettings())
        val config = repository.getWorkConfig()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Check exact alarm permission on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                // Cannot schedule exact alarms, fallback to inexact or do nothing.
                // For simplicity, if we don't have permission, we still try, but it might crash or throw exception.
                // We'll catch it just in case.
            }
        }

        try {
            scheduleAlarm(
                context = context,
                alarmManager = alarmManager,
                hour = config.lunchStartHour,
                minute = config.lunchStartMinute,
                action = ReminderReceiver.ACTION_LUNCH_BREAK,
                requestCode = 2001
            )

            scheduleAlarm(
                context = context,
                alarmManager = alarmManager,
                hour = config.workEndHour,
                minute = config.workEndMinute,
                action = ReminderReceiver.ACTION_OFF_WORK,
                requestCode = 2002
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun scheduleAlarm(
        context: Context,
        alarmManager: AlarmManager,
        hour: Int,
        minute: Int,
        action: String,
        requestCode: Int
    ) {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            this.action = action
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // If time has passed today, schedule for tomorrow
        if (target.before(Calendar.getInstance())) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                target.timeInMillis,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                target.timeInMillis,
                pendingIntent
            )
        }
    }
}
