package com.dkmads.ssp.sample

import android.os.Bundle
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.dkmads.ssp.Config
import com.dkmads.ssp.DKMadsAdInspector
import com.dkmads.ssp.DKMadsBannerAdView
import com.dkmads.ssp.DKMadsInterstitialAd
import com.dkmads.ssp.DKMadsResponseInfo
import com.dkmads.ssp.SSPSDK

/**
 * Drop into any app module for quickstart testing.
 * Set BuildConfig or replace placeholders with your dashboard values.
 */
class MainActivity : AppCompatActivity() {
    private lateinit var status: TextView
    private lateinit var bannerSlot: FrameLayout
    private var interstitial: DKMadsInterstitialAd? = null

    private val integrationKey = "YOUR_INTEGRATION_KEY"
    private val bannerAdUnitId = "YOUR_BANNER_AD_UNIT_UUID"
    private val interstitialAdUnitId = "YOUR_INTERSTITIAL_AD_UNIT_UUID"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }
        status = TextView(this).apply {
            textSize = 12f
            typeface = android.graphics.Typeface.MONOSPACE
        }
        bannerSlot = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                280,
            )
        }
        root.addView(status)
        root.addView(bannerSlot)
        root.addView(Button(this).apply {
            text = "1. Initialize SDK"
            setOnClickListener { initializeSdk() }
        })
        root.addView(Button(this).apply {
            text = "2. Load banner"
            setOnClickListener { loadBanner() }
        })
        root.addView(Button(this).apply {
            text = "3. Load & show interstitial"
            setOnClickListener { loadInterstitial() }
        })
        root.addView(Button(this).apply {
            text = "Ad Inspector"
            setOnClickListener { DKMadsAdInspector.present(this@MainActivity) }
        })
        setContentView(root)
        log("Replace integration key and ad unit UUIDs, then tap Initialize.")
    }

    private fun log(msg: String) {
        status.text = msg
    }

    private fun initializeSdk() {
        SSPSDK.initialize(
            applicationContext,
            Config(
                integrationKey = integrationKey,
                debug = true,
                baseUrl = "https://ssp.dkmads.com",
            ),
        )
        log("SDK initialized (debug on).")
    }

    private fun loadBanner() {
        bannerSlot.removeAllViews()
        val banner = DKMadsBannerAdView(this, adUnitId = bannerAdUnitId).apply {
            setAdSize(300, 250)
            listener = object : DKMadsBannerAdView.Listener {
                override fun onAdLoaded(view: DKMadsBannerAdView, ad: com.dkmads.ssp.Ad, responseInfo: DKMadsResponseInfo) {
                    log("Banner loaded.\n${responseInfo.summary}")
                }
                override fun onAdFailed(view: DKMadsBannerAdView, message: String, responseInfo: DKMadsResponseInfo?) {
                    log("Banner failed: $message")
                }
            }
        }
        bannerSlot.addView(banner)
        banner.load()
        log("Loading banner…")
    }

    private fun loadInterstitial() {
        interstitial = DKMadsInterstitialAd(interstitialAdUnitId).apply {
            listener = object : DKMadsInterstitialAd.Listener {
                override fun onAdLoaded(interstitial: DKMadsInterstitialAd, ad: com.dkmads.ssp.Ad, responseInfo: DKMadsResponseInfo) {
                    log("Interstitial loaded — showing.")
                    interstitial.show(this@MainActivity)
                }
                override fun onAdDismissed(interstitial: DKMadsInterstitialAd) {
                    log("Interstitial dismissed.\n${SSPSDK.lastBidDiagnostics?.summaryText ?: ""}")
                }
                override fun onAdFailed(interstitial: DKMadsInterstitialAd, message: String, responseInfo: DKMadsResponseInfo?) {
                    log("Interstitial failed: $message")
                }
            }
        }
        interstitial?.load(this)
        log("Loading interstitial…")
    }
}
