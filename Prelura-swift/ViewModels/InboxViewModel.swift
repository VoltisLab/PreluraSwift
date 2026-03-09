import Foundation
import SwiftUI
import Combine

@MainActor
class InboxViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading: Bool = false
    
    init() {
        loadMessages()
    }
    
    func loadMessages() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.messages = Message.sampleMessages
            self.isLoading = false
        }
    }
}
