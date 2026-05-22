import Foundation

/// Structured publisher targeting for bid `signals` and optional FPD sync.
public struct TargetingSignals {
    public var userPid: String?
    public var devicePid: String?
    public var gender: String?
    public var age: Int?
    /// ISO `YYYY-MM-DD` (optional; server stores YOB only).
    public var dateOfBirth: String?
    public var yob: Int?
    public var geoCountry: String?
    public var geoRegion: String?
    public var interests: [String]
    public var keywords: [String]
    public var segments: [String]
    public var connectionType: String?
    public var contentCategory: String?
    public var pageType: String?

    public init(
        userPid: String? = nil,
        devicePid: String? = nil,
        gender: String? = nil,
        age: Int? = nil,
        dateOfBirth: String? = nil,
        yob: Int? = nil,
        geoCountry: String? = nil,
        geoRegion: String? = nil,
        interests: [String] = [],
        keywords: [String] = [],
        segments: [String] = [],
        connectionType: String? = nil,
        contentCategory: String? = nil,
        pageType: String? = nil
    ) {
        self.userPid = userPid
        self.devicePid = devicePid
        self.gender = gender
        self.age = age
        self.dateOfBirth = dateOfBirth
        self.yob = yob
        self.geoCountry = geoCountry
        self.geoRegion = geoRegion
        self.interests = interests
        self.keywords = keywords
        self.segments = segments
        self.connectionType = connectionType
        self.contentCategory = contentCategory
        self.pageType = pageType
    }

    public func toUserData() -> UserData {
        var data: UserData = [:]
        if let userPid, !userPid.isEmpty { data["user_pid"] = userPid }
        if let devicePid, !devicePid.isEmpty { data["device_pid"] = devicePid }
        if let gender, !gender.isEmpty { data["gender"] = gender }
        if let age { data["age"] = age }
        if let resolved = DemographicsYob.resolveYob(yob: yob, dateOfBirth: dateOfBirth) {
            data["yob"] = resolved
        } else if let dateOfBirth, !dateOfBirth.isEmpty {
            data["date_of_birth"] = dateOfBirth
        }
        if let geoCountry, !geoCountry.isEmpty { data["geo_country"] = geoCountry }
        if let geoRegion, !geoRegion.isEmpty { data["geo_region"] = geoRegion }
        if let connectionType, !connectionType.isEmpty { data["connection_type"] = connectionType }
        if !segments.isEmpty { data["segments"] = segments }
        return data
    }

    public func toSignalsDictionary() -> [String: Any] {
        var signals = toUserData()
        if !interests.isEmpty || !keywords.isEmpty {
            var interestObj: [String: Any] = [:]
            if !interests.isEmpty { interestObj["tags"] = interests }
            if !keywords.isEmpty { interestObj["keywords"] = keywords }
            signals["interests"] = interestObj
        }
        if !keywords.isEmpty { signals["keywords"] = keywords }
        if let contentCategory, !contentCategory.isEmpty { signals["content_category"] = contentCategory }
        if let pageType, !pageType.isEmpty { signals["page_type"] = pageType }
        return signals
    }

    public func toFirstPartyPayload(os: String, appBundle: String? = nil) -> [String: Any] {
        var payload: [String: Any] = ["os": os]
        if let devicePid, !devicePid.isEmpty { payload["device_pid"] = devicePid }
        if let userPid, !userPid.isEmpty { payload["user_pid"] = userPid }
        if let appBundle, !appBundle.isEmpty { payload["app_bundle"] = appBundle }
        if !interests.isEmpty || !keywords.isEmpty {
            payload["interests"] = [
                "tags": interests,
                "keywords": keywords,
            ]
        }
        var meta: [String: Any] = [:]
        if let geoCountry, !geoCountry.isEmpty { meta["geo_country"] = geoCountry }
        var demo: [String: Any] = [:]
        if let resolved = DemographicsYob.resolveYob(yob: yob, dateOfBirth: dateOfBirth) {
            demo["yob"] = resolved
        }
        if let gender, !gender.isEmpty { demo["gender"] = gender }
        if !demo.isEmpty { meta["demographics"] = demo }
        if !meta.isEmpty { payload["metadata"] = meta }
        return payload
    }
}
