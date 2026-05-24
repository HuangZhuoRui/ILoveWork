package com.suseoaa.ilovework.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.suseoaa.ilovework.domain.OaSyncService
import com.suseoaa.ilovework.domain.WorkMode
import com.suseoaa.ilovework.mvi.SettingsIntent
import com.suseoaa.ilovework.mvi.SettingsViewModel
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(viewModel: SettingsViewModel) {
    val state by viewModel.state.collectAsState()
    val coroutineScope = rememberCoroutineScope()

    var callbackUrl by remember { mutableStateOf("") }
    var codeVerifier by remember { mutableStateOf("") }
    var syncStatusMessage by remember { mutableStateOf("") }
    var syncIsError by remember { mutableStateOf(false) }
    var isProcessing by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "打工人配置",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )

        // Salary
        CardItem {
            Text("月薪设置", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = if (state.monthlySalary == state.monthlySalary.toLong().toDouble())
                    state.monthlySalary.toLong().toString()
                else state.monthlySalary.toString(),
                onValueChange = { v ->
                    v.toDoubleOrNull()?.let { viewModel.dispatch(SettingsIntent.UpdateSalary(it)) }
                },
                label = { Text("月薪（元）") },
                modifier = Modifier.fillMaxWidth()
            )
        }

        // Work Mode
        CardItem {
            Text("工作模式", style = MaterialTheme.typography.titleMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WorkMode.values().forEach { mode ->
                    FilterChip(
                        selected = state.workMode == mode,
                        onClick = { viewModel.dispatch(SettingsIntent.UpdateWorkMode(mode)) },
                        label = {
                            Text(when (mode) {
                                WorkMode.DOUBLE_OFF -> "双休"
                                WorkMode.SINGLE_OFF -> "单休"
                                WorkMode.BIG_SMALL_WEEK -> "大小周"
                                WorkMode.CUSTOM -> "自定义"
                                WorkMode.NO_REST -> "不休"
                            })
                        }
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Checkbox(
                    checked = state.isRestDayPaid,
                    onCheckedChange = { viewModel.dispatch(SettingsIntent.UpdateIsRestDayPaid(it)) }
                )
                Text("休息日是否带薪 (开启后，周末等休息日也会按秒赚钱)", style = MaterialTheme.typography.bodyMedium)
            }
        }

        // Work Hours
        CardItem {
            Text("上班时间", style = MaterialTheme.typography.titleMedium)
            TimePickerRow("上班", state.workStartHour, state.workStartMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateWorkStart(h, m))
            }
            TimePickerRow("下班", state.workEndHour, state.workEndMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateWorkEnd(h, m))
            }
        }

        // Lunch Hours
        CardItem {
            Text("午休时间", style = MaterialTheme.typography.titleMedium)
            TimePickerRow("开始", state.lunchStartHour, state.lunchStartMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateLunchStart(h, m))
            }
            TimePickerRow("结束", state.lunchEndHour, state.lunchEndMinute) { h, m ->
                viewModel.dispatch(SettingsIntent.UpdateLunchEnd(h, m))
            }
        }

        // OA Attendance Sync Panel
        CardItem {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("OA 考勤时间同步", style = MaterialTheme.typography.titleMedium)
                
                // Status Indicator dot
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(if (state.oaConnected) Color(0xFF4CAF50) else Color(0xFFF44336))
                    )
                    Text(
                        text = if (state.oaConnected) "已授权" else "未授权",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = if (state.oaConnected) Color(0xFF4CAF50) else Color(0xFFF44336)
                    )
                }
            }

            OutlinedTextField(
                value = state.oaUserName,
                onValueChange = { viewModel.dispatch(SettingsIntent.UpdateOaUserName(it)) },
                label = { Text("OA 用户名") },
                modifier = Modifier.fillMaxWidth()
            )

            if (!state.oaConnected) {
                // Connection Flow
                Button(
                    onClick = {
                        val session = OaSyncService.generateAuthSession()
                        codeVerifier = session.codeVerifier
                        OaSyncService.openBrowser(session.authUrl)
                        syncStatusMessage = "已自动打开默认浏览器完成授权。授权完成后，请复制地址栏中的回调 URL 并粘贴在下方。"
                        syncIsError = false
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("1. 获取授权链接并打开浏览器")
                }

                OutlinedTextField(
                    value = callbackUrl,
                    onValueChange = { callbackUrl = it },
                    label = { Text("2. 粘贴授权回调 URL") },
                    placeholder = { Text("http://localhost:10010/callback?code=...") },
                    modifier = Modifier.fillMaxWidth()
                )

                Button(
                    onClick = {
                        val codeRegex = """[?&]code=([^&]+)""".toRegex()
                        val match = codeRegex.find(callbackUrl)
                        val code = match?.groupValues?.get(1) ?: if (!callbackUrl.contains("=") && !callbackUrl.contains("/")) callbackUrl.trim() else null

                        if (code.isNullOrBlank()) {
                            syncStatusMessage = "错误：无效的回调 URL，请确保复制了完整的重定向链接！"
                            syncIsError = true
                        } else {
                            isProcessing = true
                            syncStatusMessage = "正在通过 OA 系统交换访问令牌..."
                            syncIsError = false
                            coroutineScope.launch {
                                val token = OaSyncService.exchangeToken(code, codeVerifier)
                                isProcessing = false
                                if (token != null) {
                                    viewModel.dispatch(SettingsIntent.ConnectOa(token))
                                    viewModel.dispatch(SettingsIntent.SaveConfig)
                                    syncStatusMessage = "授权并连接 OA 成功！"
                                    syncIsError = false
                                    callbackUrl = ""
                                } else {
                                    syncStatusMessage = "错误：令牌交换失败，请确认授权码是否过期，或重新获取授权链接！"
                                    syncIsError = true
                                }
                            }
                        }
                    },
                    enabled = callbackUrl.isNotBlank() && !isProcessing,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("3. 确认授权并连接")
                }
            } else {
                // Synced Flow
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Button(
                        onClick = {
                            isProcessing = true
                            syncStatusMessage = "正在从 OA 系统拉取最近的打卡数据..."
                            syncIsError = false
                            coroutineScope.launch {
                                val result = OaSyncService.syncClockInTimes(state.oaAccessToken, state.oaUserName)
                                isProcessing = false
                                if (result != null) {
                                    viewModel.dispatch(
                                        SettingsIntent.SyncOaTimes(
                                            startHour = result.startHour,
                                            startMin = result.startMinute,
                                            endHour = result.endHour ?: 18,
                                            endMin = result.endMinute ?: 0
                                        )
                                    )
                                    viewModel.dispatch(SettingsIntent.SaveConfig)
                                    val endStr = if (result.endHour != null) {
                                        val h = result.endHour.toString().padStart(2, '0')
                                        val m = result.endMinute!!.toString().padStart(2, '0')
                                        "，下班时间同步为 $h:$m"
                                    } else "，今天尚未打卡下班"
                                    
                                    val startStr = "${result.startHour.toString().padStart(2, '0')}:${result.startMinute.toString().padStart(2, '0')}"
                                    
                                    syncStatusMessage = "🔄 同步成功！检测到最新考勤日期：${result.date}\n上班时间自动同步为 $startStr$endStr"
                                    syncIsError = false
                                } else {
                                    syncStatusMessage = "同步失败：近7天内未检测到有效的打卡记录，或者您的授权凭证已过期！"
                                    syncIsError = true
                                }
                            }
                        },
                        enabled = !isProcessing,
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("🔄 自动同步打卡时间")
                    }

                    OutlinedButton(
                        onClick = {
                            viewModel.dispatch(SettingsIntent.DisconnectOa)
                            viewModel.dispatch(SettingsIntent.SaveConfig)
                            syncStatusMessage = "已断开与 OA 的授权连接"
                            syncIsError = false
                        },
                        modifier = Modifier.wrapContentWidth()
                    ) {
                        Text("断开连接", color = MaterialTheme.colorScheme.error)
                    }
                }
            }

            if (isProcessing) {
                LinearProgressIndicator(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    color = MaterialTheme.colorScheme.primary
                )
            }

            if (syncStatusMessage.isNotBlank()) {
                Text(
                    text = syncStatusMessage,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (syncIsError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }

        Button(
            onClick = { viewModel.dispatch(SettingsIntent.SaveConfig) },
            modifier = Modifier.fillMaxWidth().height(52.dp)
        ) {
            Text(if (state.isSaved) "✓ 已保存" else "保存配置")
        }
    }
}

@Composable
private fun CardItem(content: @Composable ColumnScope.() -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().shadow(6.dp, RoundedCornerShape(16.dp)),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content
        )
    }
}

@Composable
private fun TimePickerRow(label: String, hour: Int, minute: Int, onChanged: (Int, Int) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(label, modifier = Modifier.width(40.dp))
        OutlinedTextField(
            value = hour.toString().padStart(2, '0'),
            onValueChange = { onChanged(it.toIntOrNull() ?: hour, minute) },
            label = { Text("时") },
            modifier = Modifier.weight(1f)
        )
        Text(":")
        OutlinedTextField(
            value = minute.toString().padStart(2, '0'),
            onValueChange = { onChanged(hour, it.toIntOrNull() ?: minute) },
            label = { Text("分") },
            modifier = Modifier.weight(1f)
        )
    }
}
