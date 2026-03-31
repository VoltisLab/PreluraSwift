import SwiftUI

extension View {
    /// Apply Prelura standard modal-sheet surface color.
    @ViewBuilder
    func preluraModalSheetBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(Theme.Colors.modalSheetBackground)
        } else {
            self
        }
    }
}
