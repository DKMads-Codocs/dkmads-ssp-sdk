import Foundation
import UIKit
import AVFoundation

@objc public protocol DKMadsVideoAdControllerDelegate: AnyObject {
    @objc optional func videoAdControllerDidLoad(_ controller: DKMadsVideoAdController)
    @objc optional func videoAdController(_ controller: DKMadsVideoAdController, didFailWithError error: Error)
    @objc optional func videoAdController(_ controller: DKMadsVideoAdController, didEmitEvent eventName: String, payload: [String: Any])
}

/// Loads a video ad and attaches quartile / skip / viewability telemetry to your `AVPlayer`.
@objc public final class DKMadsVideoAdController: NSObject {
    @objc public weak var delegate: DKMadsVideoAdControllerDelegate?
    @objc public let adUnitID: String
    @objc public private(set) var responseInfo: DKMadsResponseInfo?
    @objc public private(set) var loadedAd: Ad?
    @objc public private(set) var isAttached: Bool = false

    public init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    public func load(
        size: CGSize = CGSize(width: 640, height: 360),
        request: DKMadsAdRequest? = nil,
        completion: ((Result<AdResponse, Error>) -> Void)? = nil
    ) {
        detach()
        SSPSDK.shared.loadAd(
            code: adUnitID,
            format: .video,
            sizes: [size],
            placementCode: request?.placementCode,
            placementContext: request?.placementContext,
            keyValues: request?.keyValues ?? [:]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                self.responseInfo = response.responseInfo
                if response.success, let ad = response.ad {
                    self.loadedAd = ad
                    self.delegate?.videoAdControllerDidLoad?(self)
                } else {
                    let err = NSError(
                        domain: "DKMadsSSPSDK",
                        code: 204,
                        userInfo: [NSLocalizedDescriptionKey: response.reason ?? "no_fill"]
                    )
                    self.delegate?.videoAdController?(self, didFailWithError: err)
                }
                completion?(result)
            case .failure(let error):
                self.delegate?.videoAdController?(self, didFailWithError: error)
                completion?(.failure(error))
            }
        }
    }

    public func attach(
        player: AVPlayer,
        containerView: UIView,
        skippable: Bool? = nil
    ) {
        detach()
        isAttached = true
        let creativeId = loadedAd?.id
        SSPSDK.shared.trackVideoLifecycle(
            adUnitId: adUnitID,
            campaignId: nil,
            creativeId: creativeId,
            player: player,
            containerView: containerView,
            skippable: skippable
        ) { [weak self] event, payload in
            guard let self else { return }
            self.delegate?.videoAdController?(self, didEmitEvent: event, payload: payload)
        }
    }

    @objc public func detach() {
        if isAttached {
            SSPSDK.shared.stopVideoLifecycleTracking(adUnitId: adUnitID)
            isAttached = false
        }
    }

    deinit {
        detach()
    }
}
