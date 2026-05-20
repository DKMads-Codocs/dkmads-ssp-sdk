package com.dkmads.ssp

import android.content.Context

/**
 * GAID when Play Services ads identifier is available and user has not limited ad tracking.
 */
internal object AdvertisingIds {
    fun getGaid(context: Context): String? {
        return try {
            val clazz = Class.forName("com.google.android.gms.ads.identifier.AdvertisingIdClient")
            val getInfo = clazz.getMethod("getAdvertisingIdInfo", Context::class.java)
            val info = getInfo.invoke(null, context.applicationContext) ?: return null
            val limited = info.javaClass.getMethod("isLimitAdTrackingEnabled").invoke(info) as? Boolean ?: true
            if (limited) return null
            val id = info.javaClass.getMethod("getId").invoke(info) as? String
            id?.trim()?.takeIf { it.isNotEmpty() }
        } catch (_: Throwable) {
            null
        }
    }
}
