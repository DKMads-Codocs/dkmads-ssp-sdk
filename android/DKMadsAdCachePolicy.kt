package com.dkmads.ssp

import java.util.Date
import java.util.concurrent.TimeUnit

/** In-memory ad cache TTL aligned with [sdk/spec/video-lifecycle-v1.md]. */
object DKMadsAdCachePolicy {
    val FULLSCREEN_MAX_AGE_MS = TimeUnit.HOURS.toMillis(4)
    val INLINE_MAX_AGE_MS = TimeUnit.HOURS.toMillis(1)

    fun maxAgeMs(format: AdFormat): Long = when (format) {
        AdFormat.BANNER, AdFormat.NATIVE -> INLINE_MAX_AGE_MS
        else -> FULLSCREEN_MAX_AGE_MS
    }

    fun isExpired(loadedAt: Date?, format: AdFormat, now: Date = Date()): Boolean {
        if (loadedAt == null) return true
        return now.time - loadedAt.time > maxAgeMs(format)
    }
}
