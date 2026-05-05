package com.example.talk

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Display
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingKeepAliveStartResult: MethodChannel.Result? = null
    private var pendingRealtimeSecretaryStartResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "talk/keep_alive_service",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKeepAliveService" -> startKeepAliveService(result)
                "stopKeepAliveService" -> {
                    stopService(Intent(this, TalkKeepAliveService::class.java))
                    result.success(null)
                }
                "isKeepAliveServiceRunning" -> {
                    result.success(TalkKeepAliveService.isRunning)
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        val realtimeSecretaryChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "talk/realtime_secretary",
        )
        TalkRealtimeSecretaryService.setFlutterChannel(realtimeSecretaryChannel)
        realtimeSecretaryChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startRealtimeSecretaryService" -> startRealtimeSecretaryService(result)
                "stopRealtimeSecretaryService" -> {
                    TalkRealtimeSecretaryService.shutdownEngine()
                    stopService(Intent(this, TalkRealtimeSecretaryService::class.java))
                    result.success(null)
                }
                "isRealtimeSecretaryServiceRunning" -> {
                    result.success(TalkRealtimeSecretaryService.isRunning)
                }
                "testRealtimeSecretaryConfig" -> {
                    runCatching {
                        TalkRealtimeSecretaryService.testConfig(
                            this,
                            call.arguments as Map<*, *>,
                        )
                    }.onSuccess {
                        result.success(null)
                    }.onFailure {
                        result.error("REALTIME_SECRETARY_TEST_FAILED", it.message, null)
                    }
                }
                "startRealtimeSecretaryWakeSession" -> {
                    runCatching {
                        @Suppress("UNCHECKED_CAST")
                        TalkRealtimeSecretaryService.startWakeSession(
                            this,
                            call.arguments as Map<*, *>,
                        )
                    }.onSuccess {
                        result.success(null)
                    }.onFailure {
                        result.error("REALTIME_SECRETARY_SESSION_FAILED", it.message, null)
                    }
                }
                "sendRealtimeSecretaryContextTextQuery" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<String, Any?>
                    TalkRealtimeSecretaryService.sendContextTextQuery(
                        args?.get("text") as? String ?: "",
                    )
                    result.success(null)
                }
                "speakVoiceAnnouncementTextQuery" -> {
                    runCatching {
                        @Suppress("UNCHECKED_CAST")
                        TalkRealtimeSecretaryService.speakVoiceAnnouncementTextQuery(
                            this,
                            call.arguments as Map<*, *>,
                        )
                    }.onSuccess {
                        result.success(null)
                    }.onFailure {
                        result.error("VOICE_ANNOUNCEMENT_REALTIME_FAILED", it.message, null)
                    }
                }
                "stopRealtimeSecretarySession" -> {
                    TalkRealtimeSecretaryService.stopCurrentSession()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_REALTIME_SECRETARY_PERMISSIONS) {
            val result = pendingRealtimeSecretaryStartResult ?: return
            pendingRealtimeSecretaryStartResult = null
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (granted) {
                runCatching {
                    startRealtimeSecretaryServiceIntent()
                }.onSuccess {
                    result.success(null)
                }.onFailure {
                    result.error("REALTIME_SECRETARY_START_FAILED", it.message, null)
                }
            } else {
                result.error(
                    "REALTIME_SECRETARY_PERMISSION_DENIED",
                    "需要通知和麦克风权限才能启用实时语音秘书。",
                    null,
                )
            }
            return
        }

        if (requestCode != REQUEST_POST_NOTIFICATIONS) return

        val result = pendingKeepAliveStartResult ?: return
        pendingKeepAliveStartResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            runCatching {
                startKeepAliveServiceIntent()
            }.onSuccess {
                result.success(null)
            }.onFailure {
                result.error("KEEP_ALIVE_START_FAILED", it.message, null)
            }
        } else {
            result.error(
                "POST_NOTIFICATIONS_DENIED",
                "需要通知权限才能显示常驻监听通知。",
                null,
            )
        }
    }

    override fun onResume() {
        super.onResume()
        preferHighestRefreshRate()
    }

    private fun startKeepAliveService(result: MethodChannel.Result) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingKeepAliveStartResult?.error(
                "POST_NOTIFICATIONS_PENDING",
                "已有通知权限请求正在处理。",
                null,
            )
            pendingKeepAliveStartResult = result
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_POST_NOTIFICATIONS,
            )
            return
        }

        runCatching {
            startKeepAliveServiceIntent()
        }.onSuccess {
            result.success(null)
        }.onFailure {
            result.error("KEEP_ALIVE_START_FAILED", it.message, null)
        }
    }

    private fun startKeepAliveServiceIntent() {
        val intent = Intent(this, TalkKeepAliveService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun startRealtimeSecretaryService(result: MethodChannel.Result) {
        val permissions = mutableListOf<String>()
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions.add(Manifest.permission.RECORD_AUDIO)
        }

        if (permissions.isNotEmpty()) {
            pendingRealtimeSecretaryStartResult?.error(
                "REALTIME_SECRETARY_PERMISSION_PENDING",
                "已有实时语音秘书权限请求正在处理。",
                null,
            )
            pendingRealtimeSecretaryStartResult = result
            requestPermissions(
                permissions.toTypedArray(),
                REQUEST_REALTIME_SECRETARY_PERMISSIONS,
            )
            return
        }

        runCatching {
            startRealtimeSecretaryServiceIntent()
        }.onSuccess {
            result.success(null)
        }.onFailure {
            result.error("REALTIME_SECRETARY_START_FAILED", it.message, null)
        }
    }

    private fun startRealtimeSecretaryServiceIntent() {
        val intent = Intent(this, TalkRealtimeSecretaryService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun openBatteryOptimizationSettings() {
        val packageUri = Uri.parse("package:$packageName")
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = packageUri
            }
        } else {
            Intent(Settings.ACTION_SETTINGS)
        }
        startActivity(intent)
    }

    private fun preferHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        @Suppress("DEPRECATION")
        val display = windowManager.defaultDisplay ?: return
        val currentMode = display.mode ?: return
        val bestMode = display.supportedModes
            .filter {
                it.physicalWidth == currentMode.physicalWidth &&
                    it.physicalHeight == currentMode.physicalHeight
            }
            .maxByOrNull(Display.Mode::getRefreshRate)
            ?: return

        if (bestMode.modeId == currentMode.modeId) return
        val params = window.attributes
        params.preferredDisplayModeId = bestMode.modeId
        window.attributes = params
    }

    companion object {
        private const val REQUEST_POST_NOTIFICATIONS = 9001
        private const val REQUEST_REALTIME_SECRETARY_PERMISSIONS = 9002
    }
}
