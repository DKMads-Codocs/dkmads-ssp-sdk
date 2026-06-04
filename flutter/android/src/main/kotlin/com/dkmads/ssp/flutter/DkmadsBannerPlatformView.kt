package com.dkmads.ssp.flutter

import android.content.Context
import android.view.View
import com.dkmads.ssp.DKMadsBannerAdView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class DkmadsBannerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = args as? Map<String, Any?> ?: emptyMap()
    return DkmadsBannerPlatformView(context, params)
  }
}

class DkmadsBannerPlatformView(
  context: Context,
  params: Map<String, Any?>,
) : PlatformView {
  private val banner = DKMadsBannerAdView(
    context = context,
    adUnitId = params["adUnitId"] as? String ?: "",
    adWidth = (params["width"] as? Number)?.toInt() ?: 300,
    adHeight = (params["height"] as? Number)?.toInt() ?: 250,
  )

  init {
    if (params["autoLoad"] == true) {
      banner.load()
    }
  }

  override fun getView(): View = banner

  override fun dispose() {
    banner.destroy()
  }
}
