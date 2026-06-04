import Flutter
import UIKit

final class DkmadsBannerPlatformView: NSObject, FlutterPlatformView {
  private let banner: DKMadsBannerAdView

  init(frame: CGRect, viewId: Int64, args: [String: Any]?) {
    let adUnitId = args?["adUnitId"] as? String ?? ""
    let w = (args?["width"] as? NSNumber)?.doubleValue ?? 300
    let h = (args?["height"] as? NSNumber)?.doubleValue ?? 250
    banner = DKMadsBannerAdView(adUnitID: adUnitId, adSize: CGSize(width: w, height: h))
    banner.frame = frame
    super.init()
    if let auto = args?["autoLoad"] as? Bool, auto {
      banner.load()
    }
  }

  func view() -> UIView { banner }
}

final class DkmadsBannerViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any] ?? [:]
    return DkmadsBannerPlatformView(frame: frame, viewId: viewId, args: params)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
