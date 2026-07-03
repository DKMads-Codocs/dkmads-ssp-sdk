import CoreGraphics
import Foundation

/// How video creatives fit the player / placement container (parity with web `video_slot_fit`).
enum DKMadsVideoSlotFit {
    static func normalize(_ raw: String?) -> String {
        let s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s == "contain" || s == "cover" || s == "exact" || s == "contain_blur" { return s }
        return "contain"
    }

    static func isContainBlur(_ raw: String?) -> Bool {
        normalize(raw) == "contain_blur"
    }

    /// Player frame aspect for blur-fill instream (placement bounds), not creative slot pixels.
    static func playerStageSize(containerBounds: CGSize, bidSize: CGSize) -> CGSize {
        if containerBounds.width > 0, containerBounds.height > 0 { return containerBounds }
        if bidSize.width > 0, bidSize.height > 0 { return bidSize }
        return CGSize(width: 16, height: 9)
    }

    static func admIncludesBlurStage(_ adm: String?) -> Bool {
        let lower = (adm ?? "").lowercased()
        return lower.contains("dkmads-slot-fit-blur")
            || lower.contains("data-dkmads-slot-fit=\"contain_blur\"")
            || lower.contains("dkmads-video-blur-stack")
    }
}
