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
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
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
    }
}
