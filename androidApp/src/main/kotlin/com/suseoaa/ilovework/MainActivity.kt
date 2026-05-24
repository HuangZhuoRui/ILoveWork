package com.suseoaa.ilovework

import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.suseoaa.ilovework.domain.ConfigRepository
import com.suseoaa.ilovework.domain.createSettings
import com.suseoaa.ilovework.mvi.SettingsViewModel
import com.suseoaa.ilovework.reminder.ReminderScheduler
import com.suseoaa.ilovework.ui.AppTheme
import com.suseoaa.ilovework.ui.SettingsScreen
import com.suseoaa.ilovework.widget.SalaryWidgetReceiver
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            ReminderScheduler.scheduleReminders(this)
        }
    }

    @OptIn(DelicateCoroutinesApi::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        val repository = ConfigRepository(createSettings())
        val viewModel = SettingsViewModel(repository)
        
        com.suseoaa.ilovework.widget.WidgetUpdateScheduler.startPeriodicRefresh(this)
        ReminderScheduler.scheduleReminders(this)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissionLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            AppTheme {
                SettingsScreen(
                    viewModel = viewModel,
                    onAddWidgetClick = {
                        GlobalScope.launch {
                            GlanceAppWidgetManager(this@MainActivity).requestPinGlanceAppWidget(
                                receiver = SalaryWidgetReceiver::class.java
                            )
                        }
                    }
                )
            }
        }
    }
}