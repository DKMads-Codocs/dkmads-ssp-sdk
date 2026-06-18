package com.dkmads.ssp

import org.json.JSONObject

data class DKMadsNativeAdAssets(
    val headline: String? = null,
    val body: String? = null,
    val callToAction: String? = null,
    val advertiser: String? = null,
    val iconUrl: String? = null,
    val imageUrl: String? = null,
    val clickUrl: String? = null,
    /** App/store assets (OpenRTB Native data assets): rating 0–5, price, downloads, likes. */
    val rating: String? = null,
    val price: String? = null,
    val downloads: String? = null,
    val likes: String? = null,
) {
    companion object {
        fun from(ad: Ad): DKMadsNativeAdAssets = ad.nativeAssets ?: DKMadsNativeAdAssets(
            headline = null,
            body = null,
            callToAction = ad.ctaLabel.takeIf { it.isNotBlank() },
            advertiser = null,
            iconUrl = null,
            imageUrl = ad.creativeUrl.takeIf { it.isNotBlank() },
            clickUrl = ad.clickUrl.takeIf { it.isNotBlank() },
        )

        /** Server-provided structured native assets (`winner.native_assets`). */
        fun fromNativeAssets(json: JSONObject): DKMadsNativeAdAssets {
            fun str(key: String): String? = json.optString(key).takeIf { it.isNotBlank() }
            return DKMadsNativeAdAssets(
                headline = str("headline"),
                body = str("body") ?: str("description"),
                callToAction = str("cta") ?: str("cta_label"),
                advertiser = str("advertiser"),
                iconUrl = str("icon_url"),
                imageUrl = str("image_url"),
                clickUrl = str("click_url"),
                rating = str("rating"),
                price = str("price") ?: str("saleprice"),
                downloads = str("downloads"),
                likes = str("likes"),
            )
        }

        fun fromWinner(json: JSONObject): DKMadsNativeAdAssets {
            json.optJSONObject("native_assets")?.let { return fromNativeAssets(it) }
            val meta = json.optJSONObject("meta")
            fun str(vararg keys: String): String? {
                for (key in keys) {
                    val v = json.optString(key).ifBlank { meta?.optString(key).orEmpty().orEmpty() }
                    if (v.isNotBlank()) return v
                }
                return null
            }
            return DKMadsNativeAdAssets(
                headline = str("headline", "native_title", "title"),
                body = str("body", "native_body", "description"),
                callToAction = str("cta_label", "call_to_action", "native_cta"),
                advertiser = str("advertiser", "sponsored_by", "brand"),
                iconUrl = str("icon_url", "native_icon_url"),
                imageUrl = str("image_url", "native_image_url") ?: json.optString("creativeUrl").takeIf { it.isNotBlank() },
                clickUrl = str("click_url", "clickUrl"),
                rating = str("rating"),
                price = str("price", "saleprice"),
                downloads = str("downloads"),
                likes = str("likes"),
            )
        }
    }
}
