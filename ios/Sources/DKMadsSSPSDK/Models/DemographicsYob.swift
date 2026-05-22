import Foundation

enum DemographicsYob {
    private static let dobPattern = try? NSRegularExpression(pattern: #"^(\d{4})[-/](\d{2})[-/](\d{2})"#)

    static func yobFromDateOfBirth(_ dob: String?) -> Int? {
        guard let dob, !dob.isEmpty else { return nil }
        let trimmed = dob.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = trimmed as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = dobPattern?.firstMatch(in: trimmed, range: range),
              match.numberOfRanges > 1,
              let yearRange = Range(match.range(at: 1), in: trimmed) else { return nil }
        let y = Int(trimmed[yearRange]) ?? 0
        let current = Calendar.current.component(.year, from: Date())
        guard y >= 1900, y <= current else { return nil }
        return y
    }

    static func resolveYob(yob: Int?, dateOfBirth: String?) -> Int? {
        if let fromDob = yobFromDateOfBirth(dateOfBirth) { return fromDob }
        guard let yob else { return nil }
        let current = Calendar.current.component(.year, from: Date())
        guard yob >= 1900, yob <= current else { return nil }
        return yob
    }
}
