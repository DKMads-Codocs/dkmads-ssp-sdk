import Flutter
import UIKit

final class DkmadsInstreamPlatformView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let loader: DKMadsInstreamAdsLoader
  private let viewId: Int64
  private let onEvent: (Int64, String, [String: Any]) -> Void

  init(
    frame: CGRect,
    viewId: Int64,
    messenger: FlutterBinaryMessenger,
    onEvent: @escaping (Int64, String, [String: Any]) -> Void
  ) {
    self.viewId = viewId
    self.onEvent = onEvent
    container.frame = frame
    container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.isHidden = true
    loader = DKMadsInstreamAdsLoader(
      adContainer: container,
      onPauseContent: { onEvent(viewId, "pause_content", [:]) },
      onResumeContent: { onEvent(viewId, "resume_content", [:]) }
    )
    super.init()
    InstreamPlatformRegistry.shared.put(viewId: viewId, view: self)
    loader.delegate = self
  }

  func view() -> UIView { container }

  func requestAds(adUnitId: String, width: Int, height: Int, placementContext: String?) {
    loader.requestAds(
      adUnitID: adUnitId,
      contentPosition: placementContext,
      adSize: CGSize(width: width, height: height)
    )
  }

  func destroyLoader() {
    loader.destroy()
    InstreamPlatformRegistry.shared.remove(viewId: viewId)
  }

  deinit {
    destroyLoader()
  }
}

extension DkmadsInstreamPlatformView: DKMadsInstreamAdsLoaderDelegate {
  func instreamAdsLoaderDidStartAd(_ loader: DKMadsInstreamAdsLoader) {
    onEvent(viewId, "ad_started", [:])
  }

  func instreamAdsLoaderDidFinishAd(_ loader: DKMadsInstreamAdsLoader) {
    onEvent(viewId, "ad_finished", [:])
  }

  func instreamAdsLoader(_ loader: DKMadsInstreamAdsLoader, didFailWithError error: Error) {
    onEvent(viewId, "ad_failed", ["message": error.localizedDescription])
  }
}

final class DkmadsInstreamViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let onEvent: (Int64, String, [String: Any]) -> Void

  init(messenger: FlutterBinaryMessenger, onEvent: @escaping (Int64, String, [String: Any]) -> Void) {
    self.messenger = messenger
    self.onEvent = onEvent
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    DkmadsInstreamPlatformView(frame: frame, viewId: viewId, messenger: messenger, onEvent: onEvent)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class InstreamPlatformRegistry {
  static let shared = InstreamPlatformRegistry()
  private var views: [Int64: DkmadsInstreamPlatformView] = [:]

  func put(viewId: Int64, view: DkmadsInstreamPlatformView) {
    views[viewId] = view
  }

  func remove(viewId: Int64) {
    views.removeValue(forKey: viewId)
  }

  func get(viewId: Int64) -> DkmadsInstreamPlatformView? {
    views[viewId]
  }
}
