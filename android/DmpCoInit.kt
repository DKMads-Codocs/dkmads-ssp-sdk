package com.dkmads.ssp

import android.content.Context

/**
 * Optional DMP SDK co-init when [Config.dmpAppKey] is set (Phase 5).
 * Uses reflection so SSP does not hard-depend on the DMP Android artifact.
 */
internal object DmpCoInit {
    private const val DMP_CLASS = "com.dkmads.dmp.DMP"
    private const val DMP_CONFIG_CLASS = "com.dkmads.dmp.DMPInitConfig"
    private const val DEFAULT_API_HOST = "https://ingest.dmp.dkmads.com"

    fun coInit(context: Context, config: Config): Boolean {
        val appKey = config.dmpAppKey?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        return try {
            val dmpClass = Class.forName(DMP_CLASS)
            val configClass = Class.forName(DMP_CONFIG_CLASS)
            val apiHost = config.dmpApiHost?.trim()?.takeIf { it.isNotEmpty() } ?: DEFAULT_API_HOST
            val dmpConfig = configClass.getConstructor(
                String::class.java,
                String::class.java,
                String::class.java,
                String::class.java,
                java.lang.Long.TYPE,
                Integer.TYPE,
                java.lang.Boolean.TYPE,
                java.lang.Boolean.TYPE,
            ).newInstance(appKey, null, null, apiHost, 10_000L, 20, true, config.debug)
            val initMethod = dmpClass.getMethod(
                "init",
                Context::class.java,
                configClass,
                kotlin.jvm.functions.Function1::class.java,
            )
            initMethod.invoke(null, context.applicationContext, dmpConfig, null)
            linkFromDmpClass(dmpClass, config.debug)
        } catch (_: ClassNotFoundException) {
            if (config.debug) {
                android.util.Log.w("DKMads SSP", "DMP SDK not on classpath — linking from storage only")
            }
            SSPSDK.linkDmpIdentity()
        } catch (e: Throwable) {
            if (config.debug) {
                android.util.Log.w("DKMads SSP", "DMP co-init failed: ${e.message}")
            }
            SSPSDK.linkDmpIdentity()
        }
    }

    private fun linkFromDmpClass(dmpClass: Class<*>, debug: Boolean): Boolean {
        return try {
            val identity = dmpClass.getMethod("getSharedIdentity").invoke(null) as? Map<*, *>
            val devicePid = identity?.get("devicePid") as? String
            val userPid = identity?.get("userPid") as? String
            val linked = if (!devicePid.isNullOrBlank()) {
                SSPSDK.linkDmpIdentity(devicePid, userPid)
            } else {
                SSPSDK.linkDmpIdentity()
            }
            if (debug) {
                android.util.Log.d("DKMads SSP", "DMP co-init linked=$linked")
            }
            linked
        } catch (e: Throwable) {
            if (debug) {
                android.util.Log.w("DKMads SSP", "DMP identity read failed: ${e.message}")
            }
            SSPSDK.linkDmpIdentity()
        }
    }
}
