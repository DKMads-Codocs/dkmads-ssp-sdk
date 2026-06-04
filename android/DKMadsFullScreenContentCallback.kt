package com.dkmads.ssp

/** Unified fullscreen callbacks (interstitial, rewarded). */
interface DKMadsFullScreenContentCallback {
    fun onAdShowedFullScreenContent() {}
    fun onAdDismissedFullScreenContent() {}
    fun onAdFailedToShowFullScreenContent(message: String) {}
    fun onAdImpression() {}
    fun onAdClicked() {}
}

interface DKMadsFullScreenPresenting {
    val adUnitId: String
    val responseInfo: DKMadsResponseInfo?
}
