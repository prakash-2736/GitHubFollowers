
import UIKit

extension UIViewController {

    func showAppAlert(
        title: String,
        message: String,
        buttonTitle: String = "OK",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: buttonTitle, style: .cancel)
        )

        if let actionTitle, let action {
            alert.addAction(
                UIAlertAction(title: actionTitle, style: .default) { _ in
                    action()
                }
            )
        }

        present(alert, animated: true)
    }
}
