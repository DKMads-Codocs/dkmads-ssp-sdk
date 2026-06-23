import Foundation

enum DmpIdentityBridge {
    private static let dmpDevicePidKey = "dkmads_dmp_device_pid"

    static func readDevicePid() -> String? {
        let existing = UserDefaults.standard.string(forKey: dmpDevicePidKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return existing?.isEmpty == false ? existing : nil
    }
}
