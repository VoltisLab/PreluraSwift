import Foundation
import SwiftUI
import Combine

@MainActor
class SellViewModel: ObservableObject {
    @Published var isSubmitting: Bool = false
    @Published var submissionSuccess: Bool = false
    
    func submitListing(
        title: String,
        description: String,
        price: Double,
        brand: String,
        condition: String,
        size: String,
        categoryId: String?,
        categoryName: String?,
        images: [UIImage]
    ) {
        isSubmitting = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // In a real app, upload images and create listing
            self.isSubmitting = false
            self.submissionSuccess = true
            
            // Reset after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.submissionSuccess = false
            }
        }
    }
}
