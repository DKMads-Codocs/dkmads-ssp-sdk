import Foundation

/// Last bid request/response snapshot for Ad Inspector and publisher support.
@objc public final class DKMadsBidDiagnostics: NSObject {
    @objc public let adUnitId: String?
    @objc public let format: String?
    @objc public let reason: String?
    @objc public let requestId: String?
    @objc public let dsp: String?
    @objc public let price: NSNumber?
    @objc public let latencyMs: NSNumber?
    @objc public let refreshIntervalSec: NSNumber?
    @objc public let loaded: Bool
    @objc public let recordedAt: Date
    @objc public let errorMessage: String?

    public init(
        adUnitId: String?,
        format: String?,
        reason: String?,
        requestId: String?,
        dsp: String?,
        price: Double?,
        latencyMs: Int?,
        refreshIntervalSec: Int?,
        loaded: Bool,
        errorMessage: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.adUnitId = adUnitId
        self.format = format
        self.reason = reason
        self.requestId = requestId
        self.dsp = dsp
        self.price = price.map { NSNumber(value: $0) }
        self.latencyMs = latencyMs.map { NSNumber(value: $0) }
        self.refreshIntervalSec = refreshIntervalSec.map { NSNumber(value: $0) }
        self.loaded = loaded
        self.errorMessage = errorMessage
        self.recordedAt = recordedAt
    }

    @objc public var summaryText: String {
        var lines: [String] = [
            "DKMads Ad Inspector",
            "SDK \(SDK_VERSION)",
            "recorded: \(ISO8601DateFormatter().string(from: recordedAt))",
            "---",
        ]
        if let adUnitId, !adUnitId.isEmpty { lines.append("ad_unit_id: \(adUnitId)") }
        if let format, !format.isEmpty { lines.append("format: \(format)") }
        lines.append("loaded: \(loaded)")
        if let reason { lines.append("reason: \(reason)") }
        if let requestId { lines.append("request_id: \(requestId)") }
        if let dsp { lines.append("dsp: \(dsp)") }
        if let price { lines.append("price: \(price)") }
        if let latencyMs { lines.append("latency_ms: \(latencyMs)") }
        if let refreshIntervalSec { lines.append("refresh_interval_sec: \(refreshIntervalSec)") }
        if let errorMessage, !errorMessage.isEmpty { lines.append("error: \(errorMessage)") }
        return lines.joined(separator: "\n")
    }

    @objc public var detailedText: String {
        var lines = [summaryText, "---", troubleshootingHint]
        if let errorMessage, !errorMessage.isEmpty {
            lines.append("---")
            lines.append("last_error: \(errorMessage)")
        }
        return lines.joined(separator: "\n")
    }

    @objc public var troubleshootingHint: String {
        DKMadsBidDiagnostics.hint(for: reason, loaded: loaded)
    }

    @objc public static func hint(for reason: String?, loaded: Bool) -> String {
        let r = (reason ?? "").lowercased()
        if loaded { return "Fill OK — render winner.adm or image_url/video_url in your view." }
        switch r {
        case "no_tiers": return "Fix: Save property waterfall in dashboard (Demand → Waterfall)."
        case "no_bids", "no_fill": return "Fix: Active campaign + creative matching format/size; check floor price."
        case "consent_required", "consent_blocked": return "Fix: Call setConsent / CMP before load; check canRequestAds()."
        case "rate_limited": return "Fix: Reduce request frequency or increase refresh interval (≥30s)."
        default: return "Fix: curl bid with debug:true using your integration key and ad unit UUID."
        }
    }
}
