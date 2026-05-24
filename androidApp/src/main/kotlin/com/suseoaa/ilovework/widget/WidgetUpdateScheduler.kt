package com.suseoaa.ilovework.widget

import android.content.Context
import androidx.work.*
import com.suseoaa.ilovework.domain.ConfigRepository
import com.suseoaa.ilovework.domain.createSettings
import java.util.Calendar
import java.util.concurrent.TimeUnit

object WidgetUpdateScheduler {
    private const val PERIODIC_WORK_NAME = "WidgetPeriodicRefresh"

    fun startPeriodicRefresh(context: Context) {
        val workRequest = PeriodicWorkRequestBuilder<WidgetUpdateWorker>(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().build())
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            workRequest
        )
        
        scheduleKeyNodes(context)
    }

    fun scheduleKeyNodes(context: Context) {
        val repository = ConfigRepository(createSettings())
        val config = repository.getWorkConfig()
        
        val nodes = listOf(
            Pair(config.workStartHour, config.workStartMinute),
            Pair(config.workEndHour, config.workEndMinute),
            Pair(config.lunchStartHour, config.lunchStartMinute),
            Pair(config.lunchEndHour, config.lunchEndMinute)
        )
        
        val workManager = WorkManager.getInstance(context)
        val now = Calendar.getInstance()
        
        nodes.forEachIndexed { index, (hour, minute) ->
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // If the time has already passed today, schedule for tomorrow
            if (target.before(now)) {
                target.add(Calendar.DAY_OF_YEAR, 1)
            }
            
            val delayMillis = target.timeInMillis - now.timeInMillis
            
            val request = OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
                .setInitialDelay(delayMillis, TimeUnit.MILLISECONDS)
                .build()
                
            workManager.enqueueUniqueWork(
                "WidgetKeyNode_$index",
                ExistingWorkPolicy.REPLACE,
                request
            )
        }
    }
}
