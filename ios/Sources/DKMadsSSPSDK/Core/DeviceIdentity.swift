import Foundation

enum DeviceIdentity {
    private static let key = "dkmads_device_pid"

    static func getOrCreateDevicePid() -> String {
        if let existing = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return existing
        }
        let created = "dkmads_\(UUID().uuidString)"
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}
