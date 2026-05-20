import UIKit
import DKMadsSSPSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let integrationKey = ProcessInfo.processInfo.environment["DKMADS_INTEGRATION_KEY"] ?? "YOUR_INTEGRATION_KEY"
        let config = SSPSDKConfig(integrationKey: integrationKey)
        config.baseURL = "https://ssp.dkmads.com"
        config.debug = true
        DKMadsMobileAds.shared.start(with: config)
        return true
    }
}
