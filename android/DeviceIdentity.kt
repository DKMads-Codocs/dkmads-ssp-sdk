package com.dkmads.ssp

import android.content.Context
import java.util.UUID

/**
 * Stable pseudonymous device id for reach / frequency (stored locally, not hardware ID).
 */
internal object DeviceIdentity {
    private const val PREFS = "dkmads_ssp_identity"
    private const val KEY_DEVICE_PID = "device_pid"

    fun getOrCreateDevicePid(context: Context): String {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_DEVICE_PID, null)?.trim()
        if (!existing.isNullOrEmpty()) return existing
        val created = "dkmads_${UUID.randomUUID()}"
        prefs.edit().putString(KEY_DEVICE_PID, created).apply()
        return created
    }
}
