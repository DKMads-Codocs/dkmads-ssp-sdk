import UIKit

@objc public final class DKMadsAdInspectorUI: NSObject {
    @objc public static func present(from viewController: UIViewController) {
        let inspector = DKMadsAdInspectorViewController()
        let nav = UINavigationController(rootViewController: inspector)
        nav.modalPresentationStyle = .formSheet
        if #available(iOS 15.0, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
        }
        viewController.present(nav, animated: true)
    }
}
