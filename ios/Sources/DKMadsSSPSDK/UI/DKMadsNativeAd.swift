import Foundation

@objc public protocol DKMadsNativeAdDelegate: AnyObject {
    @objc optional func nativeAdDidReceiveAd(_ ad: DKMadsNativeAd)
    @objc optional func nativeAd(_ ad: DKMadsNativeAd, didFailToReceiveAdWithError error: Error)
}

/// Loads native format and exposes [DKMadsNativeAdAssets] for custom layouts. Optional: [DKMadsNativeAdView] for default render.
@objc(DKMadsNativeAd)
public final class DKMadsNativeAd: NSObject {
    @objc public weak var delegate: DKMadsNativeAdDelegate?
    @objc public let adUnitID: String
    @objc public private(set) var assets: DKMadsNativeAdAssets?
    @objc public private(set) var loadedAd: Ad?
    @objc public private(set) var responseInfo: DKMadsResponseInfo?

    @objc public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public static func load(
        adUnitID: String,
        sizes: [CGSize] = [CGSize(width: 320, height: 50)],
        request: DKMadsAdRequest? = nil,
        completion: @escaping (DKMadsNativeAd?, Error?) -> Void
    ) {
        DKMadsNativeAd(adUnitID: adUnitID).load(sizes: sizes, request: request, completion: completion)
    }

    public func load(
        sizes: [CGSize] = [CGSize(width: 320, height: 50)],
        request: DKMadsAdRequest? = nil,
        completion: @escaping (DKMadsNativeAd?, Error?) -> Void
    ) {
        guard SSPSDK.shared.isSDKInitialized else {
            completion(nil, DKMadsAdError.notInitialized.nsError())
            return
        }
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .native,
            sizes: sizes,
            placementCode: request?.placementCode,
            placementContext: request?.placementContext,
            keyValues: request?.keyValues ?? [:]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.responseInfo = response.responseInfo
                guard response.success, let ad = response.ad, ad.hasFill else {
                    let err = DKMadsAdError.noFill.nsError()
                    self.delegate?.nativeAd?(self, didFailToReceiveAdWithError: err)
                    completion(nil, err)
                    return
                }
                self.loadedAd = ad
                self.assets = ad.nativeAssets
                self.delegate?.nativeAdDidReceiveAd?(self)
                completion(self, nil)
            case .failure(let error):
                self.delegate?.nativeAd?(self, didFailToReceiveAdWithError: error)
                completion(nil, error)
            }
        }
    }
}
