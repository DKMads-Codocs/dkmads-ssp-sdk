import Foundation

/// Cross-property platform id from SSP (`X-DKMads-Platform-Uid` on bid/events).
enum PlatformIdentity {
    private static let key = "dkmads_platform_uid"

    static func get() -> String? {
        let v = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (v?.isEmpty == false) ? v : nil
    }

    static func saveFromHeader(_ value: String?) {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
        UserDefaults.standard.set(String(raw.prefix(128)), forKey: key)
    }
}
