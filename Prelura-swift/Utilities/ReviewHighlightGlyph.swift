import Foundation

/// SF Symbol names for review “What went well?” tags (stored strings match `LeaveOrderFeedbackSheet` / `L10n` en + el).
enum ReviewHighlightGlyph {
    static func sfSymbol(forStoredTag raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch t {
        // Buyer → seller
        case "Fast delivery", "Γρήγορη παράδοση":
            return "shippingbox.fill"
        case "Item as described", "Όπως στην περιγραφή":
            return "doc.text.magnifyingglass"
        case "Great communication", "Άριστη επικοινωνία":
            return "bubble.left.and.bubble.right.fill"
        case "Well packaged", "Προσεγμένη συσκευασία":
            return "archivebox.fill"
        case "Accurate photos", "Ακριβείς φωτογραφίες":
            return "camera.fill"
        case "Would buy again", "Θα ξαναγόραζα":
            return "cart.fill"
        // Seller → buyer
        case "Quick payment", "Γρήγορη πληρωμή":
            return "banknote.fill"
        case "Smooth transaction", "Ομαλή συναλλαγή":
            return "arrow.left.arrow.right.circle.fill"
        case "Polite and friendly", "Ευγενικός και φιλικός":
            return "hand.wave.fill"
        case "Would sell again", "Θα ξαναπουλούσα":
            return "arrow.triangle.2.circlepath.circle.fill"
        case "Easy to work with", "Εύκολη συνεργασία":
            return "person.2.fill"
        default:
            return "checkmark.circle"
        }
    }
}
