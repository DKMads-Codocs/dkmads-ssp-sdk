import Foundation

/// SDK entry point: `DKMadsMobileAds.shared.start(...)` — call once at app launch.
@objc public final class DKMadsMobileAds: NSObject {
    @objc public static let shared = DKMadsMobileAds()

    private override init() {
        super.init()
    }

    @objc public func start(with config: SSPSDKConfig, completion: ((Error?) -> Void)? = nil) {
        SSPSDK.shared.initialize(with: config)
        DispatchQueue.main.async {
            completion?(nil)
        }
    }

    @objc public var isInitialized: Bool {
        SSPSDK.shared.isSDKInitialized
    }

    @objc public func setApplicationMuted(_ muted: Bool) {
        // Reserved for future audio ad controls.
        if configDebug {
            print("[DKMads SSP] setApplicationMuted(\(muted))")
        }
    }

    @objc public var canRequestAds: Bool {
        SSPSDK.shared.canRequestAds()
    }

    private var configDebug: Bool {
        SSPSDK.shared.isDebugEnabled
    }
}

/// Publisher-facing ad request (placement, key-values, optional overrides).
@objc public final class DKMadsAdRequest: NSObject {
    @objc public var placementCode: String?
    @objc public var placementContext: String?
    @objc public var keyValues: [String: Any] = [:]

    @objc public override init() {
        super.init()
    }
}
