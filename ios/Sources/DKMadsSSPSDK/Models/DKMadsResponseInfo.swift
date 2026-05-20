import Foundation

/// Debug metadata for fill diagnostics (`reason`, `request_id`, `dsp`, `price`).
@objc public final class DKMadsResponseInfo: NSObject {
    @objc public let reason: String?
    @objc public let requestId: String?
    @objc public let dsp: String?
    @objc public let price: NSNumber?
    @objc public let loaded: Bool
    @objc public let latencyMs: NSNumber?

    public init(reason: String?, requestId: String?, dsp: String?, price: Double?, loaded: Bool, latencyMs: Int? = nil) {
        self.reason = reason
        self.requestId = requestId
        self.dsp = dsp
        self.price = price.map { NSNumber(value: $0) }
        self.loaded = loaded
        self.latencyMs = latencyMs.map { NSNumber(value: $0) }
    }

    public static func from(response: AdResponse) -> DKMadsResponseInfo {
        DKMadsResponseInfo(
            reason: response.reason,
            requestId: response.requestId,
            dsp: response.dsp,
            price: response.price?.doubleValue,
            loaded: response.success,
            latencyMs: response.latencyMs
        )
    }

    @objc public var summary: String {
        [
            "loaded=\(loaded)",
            reason.map { "reason=\($0)" },
            requestId.map { "request_id=\($0)" },
            dsp.map { "dsp=\($0)" },
            price.map { "price=\($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

@objc public class AdResponse: NSObject {
    @objc public let success: Bool
    @objc public let ad: Ad?
    @objc public let reason: String?
    @objc public let requestId: String?
    @objc public let dsp: String?
    @objc public let price: NSNumber?
    @objc public let responseInfo: DKMadsResponseInfo
    public let latencyMs: Int?

    public init(
        success: Bool,
        ad: Ad? = nil,
        reason: String? = nil,
        requestId: String? = nil,
        dsp: String? = nil,
        price: Double? = nil,
        latencyMs: Int? = nil
    ) {
        self.success = success
        self.ad = ad
        self.reason = reason
        self.requestId = requestId
        self.dsp = dsp
        self.price = price.map { NSNumber(value: $0) }
        self.latencyMs = latencyMs
        self.responseInfo = DKMadsResponseInfo(
            reason: reason,
            requestId: requestId,
            dsp: dsp,
            price: price,
            loaded: success,
            latencyMs: latencyMs
        )
    }
}
