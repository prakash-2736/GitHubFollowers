
import UIKit
import SwiftUI

enum AppTheme {

    // Backgrounds
    static let background = UIColor.systemBackground
    static let secondaryBackground = UIColor.secondarySystemBackground

    // Text
    static let primaryText = UIColor.label
    static let secondaryText = UIColor.secondaryLabel

    // UI elements
    static let accent = UIColor.systemIndigo
    static let separator = UIColor.separator

    // SwiftUI colors using the same adaptive UIKit colors
    static let swiftUIBackground = Color(uiColor: background)
    static let swiftUISecondaryBackground = Color(uiColor: secondaryBackground)
    static let swiftUIPrimaryText = Color(uiColor: primaryText)
    static let swiftUISecondaryText = Color(uiColor: secondaryText)
    static let swiftUIAccent = Color(uiColor: accent)
}
