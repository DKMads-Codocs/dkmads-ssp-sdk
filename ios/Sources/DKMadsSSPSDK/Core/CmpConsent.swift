import Foundation

/// IAB CMP storage (UMP / TCF / USP / GPP) — same keys as Android `CmpConsent.kt`.
struct CmpSnapshot {
    var tcfString: String?
    var gdprApplies: Bool?
    var uspString: String?
    var gppString: String?
    var gppSid: String?
}

enum CmpConsent {
    private static let tcfKeys = ["IABTCF_TCString", "IABTCF_ConsentString"]
    private static let gdprKeys = ["IABTCF_gdprApplies"]
    private static let uspKeys = ["IABUSPrivacy_String"]
    private static let gppStringKeys = ["IABGPP_GppString", "IABGPP_HDR_GppString"]
    private static let gppSidKeys = ["IABGPP_SID", "IABGPP_SectionId"]

    static func readSnapshot() -> CmpSnapshot {
        let defaults = UserDefaults.standard
        let tcf = firstNonEmpty(defaults, keys: tcfKeys)
        let gdprRaw = firstInt(defaults, keys: gdprKeys)
        let gdpr: Bool? = gdprRaw.map { $0 == 1 }
        return CmpSnapshot(
            tcfString: tcf,
            gdprApplies: gdpr,
            uspString: firstNonEmpty(defaults, keys: uspKeys),
            gppString: firstNonEmpty(defaults, keys: gppStringKeys),
            gppSid: firstNonEmpty(defaults, keys: gppSidKeys)
        )
    }

    static func merge(into existing: ConsentData) -> ConsentData {
        let snap = readSnapshot()
        var out = existing
        if (out.consentString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let tcf = snap.tcfString, !tcf.isEmpty {
            out.consentString = tcf
        }
        if let gdpr = snap.gdprApplies { out.gdpr = out.gdpr || gdpr }
        if (out.usPrivacyString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let usp = snap.uspString, !usp.isEmpty {
            out.usPrivacyString = usp
            out.ccpa = out.ccpa || true
        }
        if (out.gppString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let gpp = snap.gppString, !gpp.isEmpty {
            out.gppString = gpp
        }
        if (out.gppSid ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let sid = snap.gppSid, !sid.isEmpty {
            out.gppSid = sid
        }
        if out.attStatus == nil {
            out.attStatus = AdvertisingIdentifiers.attStatus()
        }
        return out
    }

    static func hasMinimalConsent(_ consent: ConsentData) -> Bool {
        if !(consent.consentString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if consent.resolvedUsPrivacyString() != nil { return true }
        if !(consent.gppString ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return false
    }

    private static func firstNonEmpty(_ defaults: UserDefaults, keys: [String]) -> String? {
        for key in keys {
            let v = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !v.isEmpty { return v }
        }
        return nil
    }

    private static func firstInt(_ defaults: UserDefaults, keys: [String]) -> Int? {
        for key in keys {
            if defaults.object(forKey: key) != nil {
                return defaults.integer(forKey: key)
            }
        }
        return nil
    }
}
