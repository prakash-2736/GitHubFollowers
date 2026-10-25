
import SwiftUI
import UIKit

struct SearchView: UIViewControllerRepresentable {

    func makeUIViewController(
        context: Context
    ) -> UINavigationController {
        let searchVC = SearchViewController()
        let navigationController = UINavigationController(
            rootViewController: searchVC
        )

        return navigationController
    }

    func updateUIViewController(
        _ uiViewController: UINavigationController,
        context: Context
    ) {
        // No updates needed yet.
    }
}
