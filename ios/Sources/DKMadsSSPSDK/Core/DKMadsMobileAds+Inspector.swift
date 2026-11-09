import UIKit

extension DKMadsMobileAds {
    @objc public func presentAdInspector(from viewController: UIViewController) {
        guard SSPSDK.shared.isDebugEnabled else {
            print("[DKMads SSP] Ad Inspector requires debug=true in SSPSDKConfig")
            return
        }
        DKMadsAdInspectorUI.present(from: viewController)
    }
}
