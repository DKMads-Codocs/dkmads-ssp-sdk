package com.dkmads.ssp

import android.content.Context

/**
 * Read IAB TCF / USP / GPP strings from CMP SDK storage (Sourcepoint, OneTrust, in-app CMP, etc.).
 * Explicit [SSPSDK.setConsent] values take precedence over CMP when non-blank.
 */
data class CmpSnapshot(
    val tcfString: String? = null,
    val gdprApplies: Boolean? = null,
    val uspString: String? = null,
    val gppString: String? = null,
    val gppSid: String? = null,
)

internal object CmpConsent {
    private val tcfKeys = listOf("IABTCF_TCString", "IABTCF_ConsentString")
    private val gdprKeys = listOf("IABTCF_gdprApplies")
    private val uspKeys = listOf("IABUSPrivacy_String")
    private val gppStringKeys = listOf("IABGPP_GppString", "IABGPP_HDR_GppString")
    private val gppSidKeys = listOf("IABGPP_SID", "IABGPP_SectionId")

    fun readSnapshot(context: Context): CmpSnapshot {
        val app = context.applicationContext
        val prefNames = listOf(
            "IABTCF",
            "${app.packageName}_preferences",
            "${app.packageName}.preferences",
            "com.google.android.gms.measurement.prefs",
        )
        var tcf: String? = null
        var gdpr: Boolean? = null
        var usp: String? = null
        var gpp: String? = null
        var sid: String? = null
        for (name in prefNames) {
            try {
                val prefs = app.getSharedPreferences(name, Context.MODE_PRIVATE)
                if (tcf.isNullOrBlank()) tcf = firstString(prefs, tcfKeys)
                if (gdpr == null) gdpr = firstGdpr(prefs)
                if (usp.isNullOrBlank()) usp = firstString(prefs, uspKeys)
                if (gpp.isNullOrBlank()) gpp = firstString(prefs, gppStringKeys)
                if (sid.isNullOrBlank()) sid = firstString(prefs, gppSidKeys)
            } catch (_: Throwable) {
                /* optional CMP */
            }
        }
        return CmpSnapshot(
            tcfString = tcf?.trim()?.takeIf { it.isNotEmpty() },
            gdprApplies = gdpr,
            uspString = usp?.trim()?.takeIf { it.isNotEmpty() },
            gppString = gpp?.trim()?.takeIf { it.isNotEmpty() },
            gppSid = sid?.trim()?.takeIf { it.isNotEmpty() },
        )
    }

    fun mergeInto(existing: ConsentState, snap: CmpSnapshot): ConsentState {
        return ConsentState(
            gdpr = existing.gdpr || (snap.gdprApplies == true),
            ccpa = existing.ccpa || !snap.uspString.isNullOrBlank(),
            consentString = existing.consentString?.trim()?.takeIf { it.isNotEmpty() } ?: snap.tcfString,
            gppString = existing.gppString?.trim()?.takeIf { it.isNotEmpty() } ?: snap.gppString,
            gppSid = existing.gppSid?.trim()?.takeIf { it.isNotEmpty() } ?: snap.gppSid,
            usPrivacyString = existing.usPrivacyString?.trim()?.takeIf { it.isNotEmpty() } ?: snap.uspString,
        )
    }

    fun hasMinimalConsent(state: ConsentState): Boolean {
        if (!state.consentString.isNullOrBlank()) return true
        if (state.resolvedUsPrivacyString() != null) return true
        if (!state.gppString.isNullOrBlank()) return true
        return false
    }

    /** @deprecated use [readSnapshot] */
    fun readUspString(context: Context): String? = readSnapshot(context).uspString

    private fun firstString(prefs: android.content.SharedPreferences, keys: List<String>): String? {
        for (key in keys) {
            val v = prefs.getString(key, null)?.trim()
            if (!v.isNullOrEmpty()) return v
        }
        return null
    }

    private fun firstGdpr(prefs: android.content.SharedPreferences): Boolean? {
        for (key in gdprKeys) {
            if (!prefs.contains(key)) continue
            return prefs.getInt(key, 0) == 1
        }
        return null
    }
}
