package com.example.talk

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighestRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        preferHighestRefreshRate()
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
}
