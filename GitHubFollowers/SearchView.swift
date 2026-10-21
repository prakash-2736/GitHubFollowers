
import SwiftUI
import UIKit

struct SearchView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> SearchViewController {
        SearchViewController()
    }

    func updateUIViewController(
        _ uiViewController: SearchViewController,
        context: Context
    ) {
        // No updates needed yet.
    }
}
