package com.suseoaa.ilovework.reminder

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.suseoaa.ilovework.MainActivity

class ReminderReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_OFF_WORK = "com.suseoaa.ilovework.ACTION_OFF_WORK"
        const val ACTION_LUNCH_BREAK = "com.suseoaa.ilovework.ACTION_LUNCH_BREAK"
        const val CHANNEL_ID = "ilovework_reminders"
        
        fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val name = "工作提醒"
                val descriptionText = "下班与午休提醒"
                val importance = NotificationManager.IMPORTANCE_HIGH
                val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                    description = descriptionText
                }
                val notificationManager: NotificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        
        createChannel(context)

        // Check permission for Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                return
            }
        }

        val title = when (action) {
            ACTION_OFF_WORK -> "下班啦！"
            ACTION_LUNCH_BREAK -> "午休时间到！"
            else -> return
        }
        
        val content = when (action) {
            ACTION_OFF_WORK -> "别卷了，快溜！"
            ACTION_LUNCH_BREAK -> "吃点好的，好好休息！"
            else -> return
        }
        
        val notificationId = when (action) {
            ACTION_OFF_WORK -> 1001
            ACTION_LUNCH_BREAK -> 1002
            else -> 1000
        }

        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            context, 0, openAppIntent, PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        with(NotificationManagerCompat.from(context)) {
            notify(notificationId, builder.build())
        }
        
        // Also schedule tomorrow's reminders
        ReminderScheduler.scheduleReminders(context)
    }
}
