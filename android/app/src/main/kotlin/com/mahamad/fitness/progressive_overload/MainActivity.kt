package com.mahamad.fitness.progressive_overload

import android.content.pm.PackageManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "fitness_app/health_connect"
    private val historyPermission = "android.permission.health.READ_HEALTH_DATA_HISTORY"
    private var pendingHistoryResult: MethodChannel.Result? = null

    private val historyPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            pendingHistoryResult?.success(granted)
            pendingHistoryResult = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureHistoryPermission" -> ensureHistoryPermission(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureHistoryPermission(result: MethodChannel.Result) {
        if (pendingHistoryResult != null) {
            result.error("history_in_progress", "History permission request already running", null)
            return
        }

        val granted = ContextCompat.checkSelfPermission(
            this,
            historyPermission,
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            result.success(true)
            return
        }

        pendingHistoryResult = result
        historyPermissionLauncher.launch(historyPermission)
    }
}
