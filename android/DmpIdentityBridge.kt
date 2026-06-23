package com.dkmads.ssp

import android.content.Context

/**
 * Reads device_pid written by the DMP Android SDK so SSP can share the same lookup key at bid time.
 */
internal object DmpIdentityBridge {
    private const val DMP_PREFS = "dkmads_dmp"
    private const val DMP_DEVICE_PID_KEY = "dkmads_dmp_device_pid"
    private const val DMP_DEVICE_PID_LEGACY_KEY = "device_pid"

    fun readDevicePid(context: Context): String? {
        val prefs = context.applicationContext.getSharedPreferences(DMP_PREFS, Context.MODE_PRIVATE)
        return prefs.getString(DMP_DEVICE_PID_KEY, null)?.trim()?.takeIf { it.isNotEmpty() }
            ?: prefs.getString(DMP_DEVICE_PID_LEGACY_KEY, null)?.trim()?.takeIf { it.isNotEmpty() }
    }
}
