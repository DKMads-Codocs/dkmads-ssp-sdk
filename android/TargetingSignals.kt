package com.dkmads.ssp

/**
 * Structured publisher targeting payload for bid `signals` and optional FPD sync.
 * Field names align with server/lib/targeting-signals.js and docs/TARGETING_SIGNALS.md.
 */
data class TargetingSignals(
    val userPid: String? = null,
    val devicePid: String? = null,
    val gender: String? = null,
    val age: Int? = null,
    /** ISO date `YYYY-MM-DD` (optional; server stores YOB only). */
    val dateOfBirth: String? = null,
    val yob: Int? = null,
    val geoCountry: String? = null,
    val geoRegion: String? = null,
    val interests: List<String> = emptyList(),
    val keywords: List<String> = emptyList(),
    val segments: List<String> = emptyList(),
    val connectionType: String? = null,
    val contentCategory: String? = null,
    val pageType: String? = null,
) {
    fun toUserDataMap(): Map<String, Any> {
        val out = mutableMapOf<String, Any>()
        userPid?.let { out["user_pid"] = it }
        devicePid?.let { out["device_pid"] = it }
        gender?.let { out["gender"] = it }
        age?.let { out["age"] = it }
        val resolvedYob = DemographicsYob.resolveYob(yob, dateOfBirth)
        if (resolvedYob == null && !dateOfBirth.isNullOrBlank()) {
            out["date_of_birth"] = dateOfBirth.trim()
        } else if (resolvedYob != null) {
            out["yob"] = resolvedYob
        }
        geoCountry?.let { out["geo_country"] = it }
        geoRegion?.let { out["geo_region"] = it }
        connectionType?.let { out["connection_type"] = it }
        if (segments.isNotEmpty()) out["segments"] = segments
        return out
    }

    fun toSignalsMap(): Map<String, Any> {
        val base = toUserDataMap().toMutableMap()
        if (interests.isNotEmpty() || keywords.isNotEmpty()) {
            val interestObj = mutableMapOf<String, Any>()
            if (interests.isNotEmpty()) interestObj["tags"] = interests
            if (keywords.isNotEmpty()) interestObj["keywords"] = keywords
            base["interests"] = interestObj
        }
        if (keywords.isNotEmpty()) base["keywords"] = keywords
        contentCategory?.let { base["content_category"] = it }
        pageType?.let { base["page_type"] = it }
        return base
    }

    fun toFirstPartyPayload(os: String, appBundle: String? = null): Map<String, Any> {
        val payload = mutableMapOf<String, Any>(
            "device_pid" to (devicePid ?: ""),
            "os" to os,
        )
        userPid?.let { payload["user_pid"] = it }
        appBundle?.let { payload["app_bundle"] = it }
        if (interests.isNotEmpty() || keywords.isNotEmpty()) {
            payload["interests"] = mapOf(
                "tags" to interests,
                "keywords" to keywords,
            ).filterValues { (it as? List<*>)?.isNotEmpty() == true }
        }
        val meta = mutableMapOf<String, Any>()
        geoCountry?.let { meta["geo_country"] = it }
        val demo = mutableMapOf<String, Any>()
        DemographicsYob.resolveYob(yob, dateOfBirth)?.let { demo["yob"] = it }
        gender?.let { demo["gender"] = it }
        if (demo.isNotEmpty()) meta["demographics"] = demo
        if (meta.isNotEmpty()) payload["metadata"] = meta
        return payload.filterValues { it != "" }
    }
}
