import SwiftUI

extension View {
    /// Frosted / liquid-glass style sheet (matches toolbar glass materials).
    @ViewBuilder
    func wearhouseGlassModalSheetBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(.regularMaterial)
        } else {
            self
        }
    }
}
