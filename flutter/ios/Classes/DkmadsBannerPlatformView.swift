import Flutter
import UIKit

final class DkmadsBannerPlatformView: NSObject, FlutterPlatformView {
  private let banner: DKMadsBannerAdView

  init(frame: CGRect, viewId: Int64, args: [String: Any]?) {
    let adUnitId = args?["adUnitId"] as? String ?? ""
    let w = (args?["width"] as? NSNumber)?.doubleValue ?? Double(frame.width)
    let h = (args?["height"] as? NSNumber)?.doubleValue ?? Double(frame.height)
    let width = w > 0 ? w : 300
    let height = h > 0 ? h : 250
    banner = DKMadsBannerAdView(adUnitID: adUnitId, adSize: CGSize(width: width, height: height))
    banner.translatesAutoresizingMaskIntoConstraints = false
    super.init()
    if frame.width > 0, frame.height > 0 {
      banner.setAdSize(frame.size)
    }
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
