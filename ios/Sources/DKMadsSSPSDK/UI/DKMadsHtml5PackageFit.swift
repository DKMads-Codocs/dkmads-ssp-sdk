import CoreGraphics
import Foundation

/// Outer scale/letterbox for hosted HTML5 packages in fullscreen (interstitial / app open).
/// Does not mutate creative DOM — sizes the WebView to package pixels, then scales to fit.
enum DKMadsHtml5PackageFit {
    /// Bid / IAB package size; interstitial HTML5 defaults to 320×480 when missing.
    static func packageSize(for ad: Ad, defaultWidth: CGFloat = 320, defaultHeight: CGFloat = 480) -> CGSize {
        let w = ad.slotW > 0 ? CGFloat(ad.slotW) : (ad.width > 0 ? CGFloat(ad.width) : defaultWidth)
        let h = ad.slotH > 0 ? CGFloat(ad.slotH) : (ad.height > 0 ? CGFloat(ad.height) : defaultHeight)
        return CGSize(width: max(1, w), height: max(1, h))
    }

    /// Uniform scale so `package` fits inside `container` (contain / letterbox).
    static func containScale(package: CGSize, container: CGSize) -> CGFloat {
        guard package.width > 0, package.height > 0, container.width > 0, container.height > 0 else { return 1 }
        return min(container.width / package.width, container.height / package.height)
    }
}
