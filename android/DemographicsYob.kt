package com.dkmads.ssp

/** Shared DOB → YOB for bid signals and FPD (aligns with server/lib/targeting-signals.js). */
internal object DemographicsYob {
    private val dobPattern = Regex("""^(\d{4})[-/](\d{2})[-/](\d{2})""")

    fun yobFromDateOfBirth(dob: String?): Int? {
        if (dob.isNullOrBlank()) return null
        val m = dobPattern.find(dob.trim()) ?: return null
        val y = m.groupValues[1].toIntOrNull() ?: return null
        val current = java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)
        if (y in 1900..current) return y
        return null
    }

    fun resolveYob(yob: Int?, dateOfBirth: String?): Int? {
        yobFromDateOfBirth(dateOfBirth)?.let { return it }
        val current = java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)
        if (yob != null && yob in 1900..current) return yob
        return null
    }
}
