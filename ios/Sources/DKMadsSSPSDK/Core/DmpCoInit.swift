import Foundation

#if canImport(DKMadsDMP)
import DKMadsDMP
#endif

/// Optional DMP SDK co-init when `SSPSDKConfig.dmpAppKey` is set (Phase 5).
enum DmpCoInit {
    static func coInit(config: SSPSDKConfig, link: @escaping (String?, String?) -> Bool) {
        guard let rawKey = config.dmpAppKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawKey.isEmpty else { return }

        #if canImport(DKMadsDMP)
        let apiHost = config.dmpApiHost?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dmpConfig = DMPInitConfig(
            appKey: rawKey,
            apiHost: (apiHost?.isEmpty == false ? apiHost : nil) ?? "https://ingest.dmp.dkmads.com",
            debug: config.debug
        )
        Task {
            do {
                try await DMP.init(dmpConfig)
                let identity = DMP.getSharedIdentity()
                _ = link(identity.devicePid, identity.userPid)
            } catch {
                _ = link(nil, nil)
            }
        }
        #else
        _ = link(nil, nil)
        #endif
    }
}
