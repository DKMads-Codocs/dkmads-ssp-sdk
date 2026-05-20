package com.dkmads.ssp

import android.content.Context

/** Cross-property platform id issued by SSP (`X-DKMads-Platform-Uid` on bid/events). */
internal object PlatformIdentity {
    private const val PREFS = "dkmads_ssp_identity"
    private const val KEY_PLATFORM_UID = "platform_uid"

    fun get(context: Context): String? {
        return context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_PLATFORM_UID, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
    }

    fun saveFromHeader(context: Context, headerValue: String?) {
        val uid = headerValue?.trim()?.takeIf { it.isNotEmpty() } ?: return
        context.applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PLATFORM_UID, uid.take(128))
            .apply()
    }
}
