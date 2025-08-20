import SwiftUI

extension View {
    func a11yLabel(_ text: String) -> some View { accessibilityLabel(Text(text)) }
    func a11yHint(_ text: String) -> some View { accessibilityHint(Text(text)) }
}

