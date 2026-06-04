import UIKit

/// Ad size helpers (aligned with anchored adaptive banner patterns in major mobile SDKs).
@objc public final class DKMadsAdSize: NSObject {
    @objc public let width: CGFloat
    @objc public let height: CGFloat

    @objc public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    @objc public var cgSize: CGSize { CGSize(width: width, height: height) }

    @objc public static func banner300x250() -> DKMadsAdSize {
        DKMadsAdSize(width: 300, height: 250)
    }

    @objc public static func banner320x50() -> DKMadsAdSize {
        DKMadsAdSize(width: 320, height: 50)
    }

    @objc public static func interstitial320x480() -> DKMadsAdSize {
        DKMadsAdSize(width: 320, height: 480)
    }

    /// Width in points; height follows ~6.4:1 anchored banner ratio (clamped 50–15% of short side).
    @objc public static func anchoredAdaptiveBanner(width: CGFloat, in container: UIView) -> DKMadsAdSize {
        let w = max(50, width)
        let shortSide = min(container.bounds.width, container.bounds.height)
        let maxH = max(50, shortSide * 0.15)
        let ratioH = w / 6.4
        let h = min(max(50, ratioH), maxH)
        return DKMadsAdSize(width: w, height: h)
    }

    @objc public static func anchoredAdaptiveBanner(in container: UIView) -> DKMadsAdSize {
        let w = max(50, container.bounds.width)
        return anchoredAdaptiveBanner(width: w, in: container)
    }
}
