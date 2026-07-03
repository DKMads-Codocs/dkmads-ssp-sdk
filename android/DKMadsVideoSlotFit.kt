package com.dkmads.ssp

object DKMadsVideoSlotFit {
    fun normalize(raw: String?): String {
        val s = raw?.trim()?.lowercase().orEmpty()
        return when (s) {
            "contain", "cover", "exact", "contain_blur" -> s
            else -> "contain"
        }
    }

    fun isContainBlur(raw: String?): Boolean = normalize(raw) == "contain_blur"

    fun playerStageSize(containerWidth: Int, containerHeight: Int, bidWidth: Int, bidHeight: Int): Pair<Int, Int> {
        if (containerWidth > 0 && containerHeight > 0) return containerWidth to containerHeight
        if (bidWidth > 0 && bidHeight > 0) return bidWidth to bidHeight
        return 16 to 9
    }

    fun admIncludesBlurStage(adm: String?): Boolean {
        val lower = adm?.lowercase().orEmpty()
        return lower.contains("dkmads-slot-fit-blur")
            || lower.contains("data-dkmads-slot-fit=\"contain_blur\"")
            || lower.contains("dkmads-video-blur-stack")
    }
}
