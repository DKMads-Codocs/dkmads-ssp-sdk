package com.dkmads.ssp.flutter

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.dkmads.ssp.DKMadsInstreamAdsLoader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class DkmadsInstreamViewFactory(
  private val messenger: BinaryMessenger,
  private val events: (Int, String, Map<String, Any?>) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = args as? Map<String, Any?> ?: emptyMap()
    return DkmadsInstreamPlatformView(context, viewId, events, params)
  }
}

class DkmadsInstreamPlatformView(
  context: Context,
  private val viewId: Int,
  private val events: (Int, String, Map<String, Any?>) -> Unit,
  @Suppress("UNUSED_PARAMETER") creationParams: Map<String, Any?>,
) : PlatformView {
  private val container = FrameLayout(context)
  private val loader: DKMadsInstreamAdsLoader

  init {
    InstreamPlatformRegistry.put(viewId, this)
    loader = DKMadsInstreamAdsLoader(
      container,
      onPauseContent = { emit("pause_content") },
      onResumeContent = { emit("resume_content") },
    ).apply {
      listener = object : DKMadsInstreamAdsLoader.Listener {
        override fun onAdStarted(loader: DKMadsInstreamAdsLoader) {
          emit("ad_started")
        }

        override fun onAdFinished(loader: DKMadsInstreamAdsLoader) {
          emit("ad_finished")
        }

        override fun onAdFailed(loader: DKMadsInstreamAdsLoader, message: String) {
          emit("ad_failed", mapOf("message" to message))
        }
      }
    }
  }

  private fun emit(event: String, extra: Map<String, Any?> = emptyMap()) {
    events(viewId, event, extra)
  }

  fun requestAds(adUnitId: String, width: Int, height: Int, placementContext: String?) {
    loader.requestAds(
      adUnitId = adUnitId,
      contentPosition = placementContext,
      width = width,
      height = height,
    )
  }

  fun destroyLoader() {
    loader.destroy()
    InstreamPlatformRegistry.remove(viewId)
  }

  override fun getView(): View = container

  override fun dispose() {
    destroyLoader()
  }
}

object InstreamPlatformRegistry {
  private val views = mutableMapOf<Int, DkmadsInstreamPlatformView>()

  fun put(id: Int, view: DkmadsInstreamPlatformView) {
    views[id] = view
  }

  fun remove(id: Int) {
    views.remove(id)
  }

  fun get(id: Int): DkmadsInstreamPlatformView? = views[id]
}
