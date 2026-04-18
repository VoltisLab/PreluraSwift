//
//  Localization.swift
//  Prelura-swift
//
//  In-app language: English (en) or Greek (el). When "el" is selected, UI strings use Greek.
//

import Foundation

/// UserDefaults key for selected app language: "en" | "el"
let kAppLanguage = "app_language"

/// Valid app language codes. Stored value is normalized to one of these to avoid crashes when device language or storage changes.
private let kValidAppLanguages = ["en", "el"]

enum L10n {

    /// Returns the localized string for the current app language. English uses the key as text; Greek uses translations.
    static func string(_ key: String) -> String {
        let lang = validatedAppLanguage()
        if lang == "el" {
            return greek[key] ?? key
        }
        return key
    }

    /// Current language code for conditional logic if needed. Always "en" or "el".
    static var currentLanguage: String {
        validatedAppLanguage()
    }

    /// Returns stored app language if valid; otherwise "en". Persists correction to avoid repeat crashes after device language change.
    static func validatedAppLanguage() -> String {
        let raw = UserDefaults.standard.string(forKey: kAppLanguage) ?? "en"
        if kValidAppLanguages.contains(raw) { return raw }
        UserDefaults.standard.set("en", forKey: kAppLanguage)
        return "en"
    }

    static var isGreek: Bool { currentLanguage == "el" }

    private static let greek: [String: String] = [
        // Tab bar
        "Home": "Αρχική",
        "Discover": "Ανακάλυψη",
        "Sell": "Πώληση",
        "Inbox": "Εισερχόμενα",
        "Profile": "Προφίλ",
        "Options": "Επιλογές",
        "Edit listing": "Επεξεργασία αγγελίας",
        "Share": "Κοινοποίηση",
        "Mark as sold": "Σημείωση ως πωλημένο",
        "Sold": "Πωλήθηκε",
        "Delete listing": "Διαγραφή αγγελίας",
        "Copy to a new listing": "Αντιγραφή σε νέα αγγελία",
        "Report listing": "Αναφορά αγγελίας",
        "Copy link": "Αντιγραφή συνδέσμου",
        "Error": "Σφάλμα",
        "Delete listing?": "Διαγραφή αγγελίας;",
        "Mark as sold?": "Σημείωση ως πωλημένο;",

        // Menu – profile drawer
        "Shop Value": "Αξία Καταστήματος",
        "Dashboard": "Πίνακας Ελέγχου",
        "Seller Dashboard": "Πίνακας πωλητή",
        "Shop Categories": "Κατηγορίες Καταστήματος",
        "Orders": "Παραγγελίες",
        "Order details": "Λεπτομέρειες παραγγελίας",
        "Problem reported": "Αναφέρθηκε πρόβλημα",
        "You already reported a problem for this order. You cannot submit another report while it is open.": "Έχετε ήδη αναφέρει πρόβλημα για αυτή την παραγγελία. Δεν μπορείτε να υποβάλετε νέα αναφορά όσο είναι ανοιχτή.",
        "View report details": "Προβολή λεπτομερειών αναφοράς",
        "On hold — under review": "Σε αναμονή — υπό έλεγχο",
        "This order is on hold until the report is resolved.": "Η παραγγελία είναι σε αναμονή μέχρι να επιλυθεί η αναφορά.",
        "Type": "Τύπος",
        "Resolved": "Επιλύθηκε",
        "Declined": "Απορρίφθηκε",
        "Leave a review": "Αφήστε κριτική",
        "You can leave a review once your order has been delivered.": "Μπορείτε να αφήσετε κριτική αφού παραδοθεί η παραγγελία σας.",
        "You can't leave a review while a problem report is open.": "Δεν μπορείτε να αφήσετε κριτική ενώ υπάρχει ανοιχτή αναφορά προβλήματος.",
        "We couldn't read this order's ID. Open it from My orders or pull to refresh.": "Δεν ήταν δυνατή η ανάγνωση του αναγνωριστικού της παραγγελίας. Ανοίξτε τη από τις Παραγγελίες μου ή τραβήξτε προς τα κάτω για ανανέωση.",
        "The seller is shown above, but we still need their account ID from the server to submit a review. Pull to refresh or open from My orders.": "Ο πωλητής εμφανίζεται παραπάνω, αλλά χρειαζόμαστε ακόμα το αναγνωριστικό λογαριασμού του από τον διακομιστή για την υποβολή κριτικής. Τραβήξτε για ανανέωση ή ανοίξτε από τις Παραγγελίες μου.",
        "Thanks! Your review was submitted.": "Ευχαριστούμε! Η κριτική σας υποβλήθηκε.",
        "You and the other party have both left reviews for this order.": "Εσείς και το άλλο μέρος έχετε αφήσει κριτική για αυτή την παραγγελία.",
        "You left a positive feedback.": "Αφήσατε θετική ανατροφοδότηση.",
        "You left a neutral feedback.": "Αφήσατε ουδέτερη ανατροφοδότηση.",
        "You left a negative feedback.": "Αφήσατε αρνητική ανατροφοδότηση.",
        "%@ left a positive feedback.": "%@ άφησε θετική ανατροφοδότηση.",
        "%@ left a neutral feedback.": "%@ άφησε ουδέτερη ανατροφοδότηση.",
        "%@ left a negative feedback.": "%@ άφησε αρνητική ανατροφοδότηση.",
        "You left a feedback.": "Αφήσατε ανατροφοδότηση.",
        "%@ left a feedback.": "%@ άφησε ανατροφοδότηση.",
        "Left a feedback.": "Αφέθηκε ανατροφοδότηση.",
        "You made a sale! 🎉": "Έκανες πώληση! 🎉",
        "%@ sent you an offer.": "Ο χρήστης %@ σάς έστειλε προσφορά.",
        "%@ likes your item.": "Ο χρήστης %@ έκανε like στο αντικείμενό σας.",
        "An item you liked has sold. Here are similar listings to explore.": "Ένα αντικείμενο που σάς άρεσε πωλήθηκε. Δείτε παρόμοιες αγγελίες για να εξερευνήσετε.",
        "Rating": "Βαθμολογία",
        "What went well?": "Τι πήγε καλά;",
        "Comment (optional)": "Σχόλιο (προαιρετικό)",
        "Fast delivery": "Γρήγορη παράδοση",
        "Item as described": "Όπως στην περιγραφή",
        "Great communication": "Άριστη επικοινωνία",
        "Well packaged": "Προσεγμένη συσκευασία",
        "Accurate photos": "Ακριβείς φωτογραφίες",
        "Would buy again": "Θα ξαναγόραζα",
        "Quick payment": "Γρήγορη πληρωμή",
        "Smooth transaction": "Ομαλή συναλλαγή",
        "Polite and friendly": "Ευγενικός και φιλικός",
        "Would sell again": "Θα ξαναπουλούσα",
        "Easy to work with": "Εύκολη συνεργασία",
        "Tap to rate": "Πατήστε για βαθμολογία",
        "Very poor": "Πολύ κακή",
        "Poor": "Κακή",
        "Below average": "Κάτω του μέσου όρου",
        "Fair": "Μέτρια",
        "Okay": "Αρκετά καλή",
        "Good": "Καλή",
        "Very good": "Πολύ καλή",
        "Great": "Υπέροχη",
        "Excellent": "Εξαιρετική",
        "Perfect": "Τέλεια",
        "Submit": "Υποβολή",
        "Select item": "Επιλογή προϊόντος",
        "Which item is your issue about? Choose one to continue.": "Ποιο προϊόν αφορά το πρόβλημά σας; Επιλέξτε ένα για να συνεχίσετε.",
        "Favourites": "Αγαπημένα",
        "Shop tools": "Εργαλεία Καταστήματος",
        "Background replacer": "Αντικατάσταση Φόντου",
        "Multi-buy Discounts": "Εκπτώσεις πολλαπλών αγορών",
        "Multi-buy discount (%d%%)": "Εκπτωση πολλαπλών αγορών (%d%%)",
        "On": "Ενεργό",
        "Off": "Ανενεργό",
        "Holiday Mode": "Λειτουργία Αργίας",
        "Invite Friend": "Προσκάλεσε Φίλο",
        "Share profile": "Κοινοποίηση προφίλ",
        "Couldn't load profile": "Δεν ήταν δυνατή η φόρτωση του προφίλ",
        "Profile link": "Σύνδεσμος προφίλ",
        "Copy link": "Αντιγραφή συνδέσμου",
        "Link copied": "Ο σύνδεσμος αντιγράφηκε",
        "Sign in to share your profile.": "Συνδεθείτε για να κοινοποιήσετε το προφίλ σας.",
        "Help Centre": "Κέντρο Βοήθειας",
        "About Us": "Σχετικά με εμάς",
        "Admin Dashboard": "Πίνακας Διαχείρισης",
        "Settings": "Ρυθμίσεις",
        "Logout": "Αποσύνδεση",

        // Settings
        "Account Settings": "Ρυθμίσεις Λογαριασμού",
        "Currency": "Νόμισμα",
        "Privacy": "Απόρρητο",
        "Shipping Address": "Διεύθυνση Αποστολής",
        "Appearance": "Εμφάνιση",
        "Profile details": "Στοιχεία προφίλ",
        "Personal details": "Προσωπικά στοιχεία",
        "First name": "Όνομα",
        "Last name": "Επώνυμο",
        "Phone": "Τηλέφωνο",
        "Mobile number": "Αριθμός κινητού",
        "Email address": "Διεύθυνση email",
        "Tap to choose date": "Πατήστε για επιλογή ημερομηνίας",
        "Tap to choose gender": "Πατήστε για επιλογή φύλου",
        "Public username hint": "Φαίνεται στο προφίλ και στους συνδέσμους",
        "Bio hint": "Περιγράψτε το στυλ σας και τι πουλάτε",
        "Location hint": "Π.χ. Λονδίνο, ΗΒ",
        "UK number only (without +44)": "Αριθμός ΗΒ μόνο (χωρίς +44)",
        "Payments": "Πληρωμές",
        "Postage": "Ταχυδρομικά",
        "Security & Privacy": "Ασφάλεια και απόρρητο",
        "Identity verification": "Επαλήθευση ταυτότητας",
        "Admin Actions": "Ενέργειες διαχειριστή",
        "Notifications": "Ειδοποιήσεις",
        "Push notifications": "Ειδοποιήσεις push",
        "Email notifications": "Ειδοποιήσεις email",
        "Log out": "Αποσύνδεση",
        "Cancel": "Ακύρωση",
        "Confirm": "Επιβεβαίωση",
        "Are you sure you want to logout?": "Είστε σίγουροι ότι θέλετε να αποσυνδεθείτε;",

        // Appearance
        "Theme": "Θέμα",
        "Use System Settings": "Χρήση ρυθμίσεων συστήματος",
        "Light": "Φωτεινή",
        "Dark": "Σκούρα",
        "Light and Dark apply to all screens, components, and elements. System follows your device setting.": "Φωτεινή και σκούρα ισχύουν σε όλες τις οθόνες. Το σύστημα ακολουθεί τη ρύθμιση της συσκευής σας.",
        "Primary Logo": "Κύριο λογότυπο",
        "Gradient Logo": "Λογότυπο με ντεγκραντέ",
        "Gradient 3D Logo": "Λογότυπο 3D με ντεγκραντέ",
        "Black Logo": "Μαύρο λογότυπο",
        "You may see a brief iOS confirmation when changing the icon. The new icon appears on the Home Screen and in the app switcher.": "Η αλλαγή εικονιδίου μπορεί να εμφανίσει σύντομη επιβεβαίωση από το iOS. Το νέο εικονίδιο εμφανίζεται στην Αρχική οθόνη και στον εναλλάκτη εφαρμογών.",
        "Your app's language": "Γλώσσα εφαρμογής",
        "Language": "Γλώσσα",
        "Language updated": "Η γλώσσα ενημερώθηκε",
        "The app will use the selected language the next time you open it. Close and reopen the app to see the change.": "Η εφαρμογή θα χρησιμοποιήσει την επιλεγμένη γλώσσα την επόμενη φορά που θα την ανοίξετε. Κλείστε και ανοίξτε ξανά την εφαρμογή για να δείτε την αλλαγή.",
        "English": "Αγγλικά",
        "Greek": "Ελληνικά",
        "Greek displays the app in Greek.": "Η γλώσσα Ελληνικά εμφανίζει την εφαρμογή στα Ελληνικά.",

        // About Us (menu + legal hub)
        "About us": "Σχετικά με εμάς",
        "Terms": "Όροι",
        "Privacy Policy": "Πολιτική απορρήτου",

        // Help Centre
        "Got a burning question?": "Έχετε κάποια ερώτηση;",
        "Frequently asked": "Συχνές ερωτήσεις",
        "More topics": "Περισσότερα θέματα",
        "How can I cancel an existing order": "Πώς μπορώ να ακυρώσω μια υπάρχουσα παραγγελία",
        "How long does a refund normally take?": "Πόσο διαρκεί συνήθως η επιστροφή χρημάτων;",
        "When will I receive my item?": "Πότε θα λάβω το προϊόν μου;",
        "How will I know if my order has been shipped?": "Πώς θα μάθω αν η παραγγελία μου έχει σταλεί;",
        "What's a collection point?": "Τι είναι το σημείο παραλαβής;",
        "Item says \"Delivered\" but I don't have it": "Γράφει \"Παραδόθηκε\" αλλά δεν το έχω λάβει",
        "What's Holiday Mode?": "Τι είναι η λειτουργία αργίας;",
        "How do I earn a trusted seller badge?": "Πώς κερδίζω το σήμα αξιόπιστου πωλητή;",
        "No matching topics": "Δεν βρέθηκαν σχετικά θέματα",
        "Start a conversation": "Ξεκινήστε συνομιλία",
        "e.g. How do I change my profile photo?": "π.χ. Πώς αλλάζω τη φωτογραφία προφίλ μου;",
        "Tap a row for details. Opening a type plays it once.": "Πατήστε μια γραμμή για λεπτομέρειες. Το άνοιγμα ενός τύπου τον αναπαράγει μία φορά.",
        "Impact & selection": "Κραδασμός & επιλογή",
        "Notification feedback": "Ειδοποίηση (haptic)",
        "Haptics": "Απτική ανάδραση",
        "Play again": "Αναπαραγωγή",
        "Where it's used": "Πού χρησιμοποιείται",

        // Menu (navigation)
        "Menu": "Μενού",
        "Accounts": "Λογαριασμοί",
        "Add account": "Προσθήκη λογαριασμού",
        "Active account": "Ενεργός λογαριασμός",
        "Signed in as": "Σύνδεση ως",
        "Current": "Τρέχων",
        "Switch": "Εναλλαγή",
        "Log out all accounts": "Αποσύνδεση όλων των λογαριασμών",
        "Log out all": "Αποσύνδεση όλων",
        "Log out all accounts on this device?": "Αποσύνδεση όλων των λογαριασμών σε αυτή τη συσκευή;",
        "Could not switch account": "Δεν ήταν δυνατή η εναλλαγή λογαριασμού",
        "The forum is not available on this server yet. Deploy the latest backend and run migrations, then try again.":
            "Το φόρουμ δεν είναι διαθέσιμο σε αυτόν τον διακομιστή ακόμα. Αναπτύξτε το πιο πρόσφατο backend και εκτελέστε migrations, μετά δοκιμάστε ξανά.",
        "© WEARHOUSE 2026": "© WEARHOUSE 2026",
        "© Voltis Labs 2026": "© Voltis Labs 2026",
        "Debug": "Εντοπισμός σφαλμάτων",
        "Search debug tools": "Αναζήτηση εργαλείων debug",
        "No matching tools": "Δεν βρέθηκαν εργαλεία",
        "This tool is only available in debug builds.": "Αυτό το εργαλείο είναι διαθέσιμο μόνο σε debug builds.",

        // Home
        "Search items, brands or styles": "Αναζήτηση προϊόντων, εμπορικών σημάτων ή στυλ",
        "All": "Όλα",
        "Women": "Γυναίκες",
        "Men": "Άνδρες",
        "Kids": "Παιδικά",
        "Toddlers": "Νήπια",
        "Girls": "Κορίτσια",
        "Boys": "Αγόρια",

        // Discover
        "Search members": "Αναζήτηση μελών",
        "Search conversations": "Αναζήτηση συνομιλιών",
        "Shop by style": "Επίλεξε στυλ",
        "Explore by style": "Εξερεύνηση ανά στυλ",
        "Feed": "Ροή",
        "Explore communities": "Εξερεύνησε κοινότητες",
        "See all": "Όλα",
        "Get inspired": "Εμπνεύσου",

        // Browse
        "Browse": "Περιήγηση",
        "Sort: ": "Ταξινόμηση: ",
        "No items found": "Δεν βρέθηκαν προϊόντα",
        "Try adjusting your filters": "Δοκιμάστε να αλλάξετε τα φίλτρα",
        "No products found": "Δεν βρέθηκαν προϊόντα",

        // Favourites (Favourites key in Menu section)
        "No favourites yet": "Δεν υπάρχουν αγαπημένα ακόμα",
        "Items you save as favourites will appear here.": "Τα προϊόντα που αποθηκεύετε ως αγαπημένα θα εμφανίζονται εδώ.",
        "No results for \"%@\"": "Δεν βρέθηκαν αποτελέσματα για «%@»",
        "Search favourites": "Αναζήτηση αγαπημένων",
        "Search saved photos": "Αναζήτηση αποθηκευμένων φωτογραφιών",
        "Search saved lookbooks": "Αναζήτηση αποθηκευμένων lookbook",
        "Search lookbook folders": "Αναζήτηση φακέλων lookbook",
        "No lookbook folders yet": "Δεν υπάρχουν φάκελοι lookbook ακόμα",
        "Save looks from the feed — you can organise them into folders.": "Αποθηκεύστε εμφανίσεις από τη ροή — μπορείτε να τις οργανώσετε σε φακέλους.",
        "Save to folder": "Αποθήκευση σε φάκελο",
        "My saves": "Οι αποθηκεύσεις μου",
        "New folder": "Νέος φάκελος",
        "Folder name": "Όνομα φακέλου",
        "You can add the same look to more than one folder.": "Μπορείτε να προσθέσετε την ίδια εμφάνιση σε περισσότερους από έναν φάκελο.",
        "Saved to %@": "Αποθηκεύτηκε στο %@",
        "Remove from folder": "Αφαίρεση από φάκελο",
        "Remove from this folder?": "Αφαίρεση από αυτόν τον φάκελο;",
        "This look will be removed from this folder only.": "Η εμφάνιση θα αφαιρεθεί μόνο από αυτόν τον φάκελο.",
        "Remove selected looks?": "Αφαίρεση επιλεγμένων εμφανίσεων;",
        "These looks will be removed from this folder only.": "Οι εμφανίσεις θα αφαιρεθούν μόνο από αυτόν τον φάκελο.",
        "Delete selected folders?": "Διαγραφή επιλεγμένων φακέλων;",
        "This will delete the selected folders and every look saved inside them. This can't be undone.": "Θα διαγραφούν οι επιλεγμένοι φάκελοι και κάθε εμφάνιση που είναι αποθηκευμένη μέσα τους. Αυτό δεν μπορεί να αναιρεθεί.",
        "Remove": "Αφαίρεση",
        "No saves in this folder": "Δεν υπάρχει αποθήκευση σε αυτόν τον φάκελο",
        "Save looks from the feed into this folder.": "Αποθηκεύστε εμφανίσεις από τη ροή σε αυτόν τον φάκελο.",
        "Lookbook": "Lookbook",
        "Explore Lookbook": "Εξερεύνηση Lookbook",
        "Lookbook settings": "Ρυθμίσεις Lookbook",
        "Lookbook hub settings subtitle": "Προτιμήσεις και επιλογές για το Lookbook.",
        "Lookbook settings footer": "Εδώ θα εμφανίζονται επιλογές που αφορούν τις δημοσιεύσεις και την εμπειρία Lookbook.",
        "Show lookbook shortcuts": "Εμφάνιση συντομεύσεων Lookbook",
        "Hide lookbook shortcuts": "Απόκρυψη συντομεύσεων Lookbook",
        "Swipe this shortcut bar left or right to hide or show the buttons.": "Σύρετε αυτή τη γραμμή συντομεύσεων αριστερά ή δεξιά για να κρύψετε ή να εμφανίσετε τα κουμπιά.",
        "Products": "Προϊόντα",
        "Photos": "Φωτογραφίες",
        "No saved Lookbook photos yet": "Δεν έχετε αποθηκεύσει φωτογραφίες Lookbook ακόμα",
        "Lookbook photos you save from the feed appear here.": "Οι φωτογραφίες Lookbook που αποθηκεύετε από τη ροή εμφανίζονται εδώ.",
        "Remove from favourites": "Αφαίρεση από τα αγαπημένα",
        "Image unavailable": "Η εικόνα δεν είναι διαθέσιμη",
        "Photo": "Φωτογραφία",
        "Lookbook": "Lookbook",
        "No Lookbook posts yet": "Δεν υπάρχουν δημοσιεύσεις Lookbook ακόμα",
        "Create a look from Lookbook — it will show up here.": "Δημιουργήστε ένα look από το Lookbook — θα εμφανιστεί εδώ.",
        "Search": "Αναζήτηση",
        "For You": "Για σένα",
        "People": "Άνθρωποι",
        "Nothing in this feed matches your search.": "Τίποτα σε αυτή την ροή δεν ταιριάζει με την αναζήτησή σας.",
        "No hashtag or people matches in this feed for this search.": "Δεν υπάρχουν hashtag ή άνθρωποι σε αυτή την ροή για αυτή την αναζήτηση.",
        "No people in this feed match your search.": "Κανένας χρήστης σε αυτή την ροή δεν ταιριάζει με την αναζήτησή σας.",
        "No tagged products in this feed match your search.": "Κανένα προϊόν με ετικέτα σε αυτή την ροή δεν ταιριάζει με την αναζήτησή σας.",
        "No hashtags in this feed match your search.": "Κανένα hashtag σε αυτή την ροή δεν ταιριάζει με την αναζήτησή σας.",
        "Lookbook post": "Δημοσίευση Lookbook",
        "Search topics, hashtags, styles…": "Αναζήτηση θεμάτων, hashtag, στυλ…",
        "No looks match your search.": "Δεν ταιριάζει κανένα look με την αναζήτησή σας.",
        "Search this feed by username, hashtag, or product.": "Αναζητήστε σε αυτή τη ροή με όνομα χρήστη, hashtag ή προϊόν.",
        "Search usernames, hashtags & products": "Αναζήτηση ονομάτων χρήστη, hashtag και προϊόντων",
        "Try a username": "Δοκιμάστε όνομα χρήστη",
        "Try a hashtag": "Δοκιμάστε hashtag",
        "Try a product name": "Δοκιμάστε όνομα προϊόντος",
        "Accounts": "Λογαριασμοί",
        "Hashtags": "Hashtag",
        "Looks": "Εμφανίσεις",
        "In this feed": "Σε αυτή τη ροή",
        "Tagged in look": "Επισημασμένο στο look",
        "In %d looks": "Σε %d εμφανίσεις",
        "No comments yet": "Δεν υπάρχουν σχόλια ακόμα",
        "Comments": "Σχόλια",
        "1 Comment": "1 σχόλιο",
        "%d comments": "%d σχόλια",
        "Hide likes": "Απόκρυψη μου αρέσει",
        "Show likes": "Εμφάνιση μου αρέσει",
        "Hide likes count": "Απόκρυψη αριθμού μου αρέσει",
        "Hide all like counts": "Απόκρυψη όλων των αριθμών μου αρέσει",
        "When this is on, like counts are hidden on all lookbook posts. On your own posts, open the more options menu on a post and choose Show likes to show the count for that post only.": "Όταν είναι ενεργό, οι αριθμοί μου αρέσει αποκρύπτονται σε όλες τις δημοσιεύσεις lookbook. Στις δικές σας δημοσιεύσεις, ανοίξτε το μενού περισσότερων επιλογών σε μια δημοσίευση και επιλέξτε «Εμφάνιση μου αρέσει» για να εμφανίσετε τον αριθμό μόνο σε εκείνη τη δημοσίευση.",
        "Scroll": "Κύλιση",
        "Sticky": "Σταθερό",
        "Smooth": "Ομαλό",
        "Scroll: Smooth uses a free-scrolling feed; Sticky snaps each post into place. Fullscreen Lookbook: Smooth pages by post; Sticky uses a looser view-aligned glide.": "Κύλιση: Το Ομαλό έχει ελεύθερη κύλιση στη ροή· το Σταθερό ευθυγραμμίζει κάθε δημοσίευση. Πλήρης οθόνη Lookbook: Το Ομαλό μεταβαίνει ανά δημοσίευση· το Σταθερό έχει πιο χαλαρή στοίχιση.",
        "Add a comment": "Πρόσθεσε σχόλιο",
        "Send": "Αποστολή",
        "Reply": "Απάντηση",
        "Replying to": "Απάντηση σε",
        "Delete this comment?": "Διαγραφή αυτού του σχολίου;",
        "This will remove your comment and any replies under it.": "Θα αφαιρεθεί το σχόλιό σας και τυχόν απαντήσεις κάτω από αυτό.",
        "Lookbook upload": "Μεταφόρτωση Lookbook",
        "Create": "Δημιουργία",
        "Create a post": "Δημιουργία δημοσίευσης",
        "Profile, account, notifications, and more.": "Προφίλ, λογαριασμός, ειδοποιήσεις και άλλα.",
        "Upload photos, crop your look, and share it with followers.": "Ανέβασε φωτογραφίες, κόψε το look σου και μοιράσου το με τους ακόλουθούς σου.",
        "List view": "Προβολή λίστας",
        "Grid view": "Προβολή πλέγματος",
        "Tap to reload": "Πατήστε για επανάφόρτωση",
        "Tag products": "Επισήμανση προϊόντων",
        "Choose product": "Επιλογή προϊόντος",
        "Add new product": "Προσθήκη νέου προϊόντος",
        "Replace product": "Αντικατάσταση προϊόντος",
        "View product": "Προβολή προϊόντος",
        "Remove tag": "Αφαίρεση ετικέτας",
        "Update post": "Ενημέρωση δημοσίευσης",
        "Lookbook edits aren’t supported on this server yet. Deploy the updateLookbookPost API (see docs/lookbooks-backend-spec.md).": "Η επεξεργασία Lookbook δεν υποστηρίζεται ακόμα σε αυτόν τον διακομιστή. Αναπτύξτε το API updateLookbookPost (βλ. docs/lookbooks-backend-spec.md).",
        "Updating tagged products isn’t available on this server yet. Your team can deploy setLookbookProductTags when ready.": "Η ενημέρωση επισημασμένων προϊόντων δεν είναι διαθέσιμη ακόμα. Η ομάδα μπορεί να αναπτύξει το setLookbookProductTags όταν είναι έτοιμη.",

        // Profile (Favourites used from Menu section)
        "Listings": "Αγγελίες",
        "Listing": "Αγγελία",
        "No listings yet": "Δεν υπάρχουν αγγελίες ακόμα",
        "No items match your filters": "Δεν βρέθηκαν προϊόντα με τα φίλτρα σας",
        "Followings": "Ακόλουθοι",
        "Following": "Ακόλουθοι",
        "Followers": "Οπαδοί",
        "Follower": "Οπαδός",
        "Retro": "Ρετρό",
        "This is where to shop vintage finds.": "Εδώ αγοράζετε επιλεγμένα vintage κομμάτια.",
        "Reviews": "Κριτικές",
        "Please choose a star rating.": "Επιλέξτε βαθμολογία αστεριών.",
        "Actions": "Ενέργειες",
        "User actions": "Ενέργειες χρήστη",
        "Platform verified": "Επαλήθευση πλατφόρμας",
        "Blue tick is on for this account.": "Το μπλε σήμα είναι ενεργό για αυτόν τον λογαριασμό.",
        "Blue tick is off for this account.": "Το μπλε σήμα είναι ανενεργό για αυτόν τον λογαριασμό.",
        "Add blue tick": "Προσθήκη μπλε σήματος",
        "Remove blue tick": "Αφαίρεση μπλε σήματος",
        "Email verification": "Επαλήθευση email",
        "Email is verified for this account.": "Το email είναι επαληθευμένο για αυτόν τον λογαριασμό.",
        "Email is not verified for this account.": "Το email δεν είναι επαληθευμένο για αυτόν τον λογαριασμό.",
        "Remove email verification": "Αφαίρεση επαλήθευσης email",
        "Mark email verified": "Σήμανση email ως επαληθευμένο",
        "Profile tier": "Βαθμίδα προφίλ",
        "This account is Pro.": "Αυτός ο λογαριασμός είναι Pro.",
        "This account is Elite.": "Αυτός ο λογαριασμός είναι Elite.",
        "This account is on the standard tier.": "Αυτός ο λογαριασμός είναι στην τυπική βαθμίδα.",
        "Set Pro": "Ορισμός Pro",
        "Set Elite": "Ορισμός Elite",
        "Clear tier": "Εκκαθάριση βαθμίδας",
        "Admin": "Διαχείριση",
        "This account has staff access (Admin Dashboard, Accounts, moderation tools).": "Αυτός ο λογαριασμός έχει πρόσβαση προσωπικού (Πίνακας διαχείρισης, Λογαριασμοί, εργαλεία συντονισμού).",
        "Grant staff access for moderation tools, Accounts switching, and Admin Dashboard.": "Χορηγήστε πρόσβαση προσωπικού για εργαλεία συντονισμού, εναλλαγή λογαριασμών και Πίνακα διαχείρισης.",
        "Remove staff access": "Αφαίρεση πρόσβασης προσωπικού",
        "Grant staff access": "Χορήγηση πρόσβασης προσωπικού",
        "Report user": "Αναφορά χρήστη",
        "Could not resolve this user’s id. Pull to refresh on their profile and try again.": "Δεν ήταν δυνατή η ανάλυση του αναγνωριστικού χρήστη. Τραβήξτε για ανανέωση στο προφίλ του και δοκιμάστε ξανά.",
        "Request failed.": "Το αίτημα απέτυχε.",
        "Remove staff access for this user?": "Αφαίρεση πρόσβασης προσωπικού για αυτόν τον χρήστη;",
        "Grant staff access? This user can use moderation tools.": "Χορήγηση πρόσβασης προσωπικού; Ο χρήστης μπορεί να χρησιμοποιεί εργαλεία συντονισμού.",
        "Members": "Μέλη",
        "Automatic": "Αυτόματες",
        "Location": "Τοποθεσία",
        "N/A": "Μ/Δ",
        "Categories": "Κατηγορίες",
        "item": "προϊόν",
        "items": "προϊόντα",
        "Multi-buy:": "Πολλαπλές αγορές:",
        "View cart": "Δείτε καλάθι",
        "View bag": "Δείτε τσάντα",
        "Shopping bag": "Τσάντα αγορών",
        "Your bag is empty": "Η τσάντα σας είναι άδεια",
        "Add to bag": "Προσθήκη στην τσάντα",
        "Checkout": "Ολοκλήρωση αγοράς",
        "Top brands": "Κορυφαίες μάρκες",
        "Filter": "Φίλτρο",
        "Clear": "Καθαρισμός",
        "Sort": "Ταξινόμηση",
        "Done": "ΟΚ",
        "Condition": "Κατάσταση",
        "Price": "Τιμή",
        "OK": "ΟΚ",

        // Auth
        "Welcome back": "Καλώς ήρθατε πάλι",
        "Username": "Όνομα χρήστη",
        "Enter your username": "Εισάγετε το όνομα χρήστη σας",
        "Incorrect username or password. Use your username (not your email). For seed accounts, the password is the STAGING_SEED_PASSWORD from GitHub Actions — if that secret was changed after users were created, the old password still applies until you reset it.": "Λάθος όνομα χρήστη ή κωδικός. Χρησιμοποιήστε το όνομα χρήστη (όχι το email). Για δοκιμαστικούς λογαριασμούς, ο κωδικός είναι το STAGING_SEED_PASSWORD από το GitHub Actions — αν αλλάξατε αυτό το μυστικό μετά τη δημιουργία των λογαριασμών, ισχύει ακόμα ο παλιός κωδικός μέχρι να τον επαναφέρετε.",
        "Password": "Κωδικός",
        "Enter your password": "Εισάγετε τον κωδικό σας",
        "Forgot password?": "Ξεχάσατε τον κωδικό;",
        "Don't have an account?": "Δεν έχετε λογαριασμό;",
        "Sign up": "Εγγραφή",
        "Login": "Σύνδεση",
        "Continue as guest": "Συνέχεια ως επισκέπτης",
        "You're browsing as guest": "Περιηγείστε ως επισκέπτης",
        "Sign in to see your profile, listings and messages.": "Συνδεθείτε για να δείτε το προφίλ σας, τις αγγελίες και τα μηνύματά σας.",
        "Sign in": "Σύνδεση",

        // Profile sort
        "Relevance": "Συσχέτιση",
        "Newest First": "Νεότερα πρώτα",
        "Price Ascending": "Τιμή αύξουσα",
        "Price Descending": "Τιμή φθίνουσα",
        "Price range": "Εύρος τιμών",
        "Excellent Condition": "Εξαιρετική κατάσταση",
        "Good Condition": "Καλή κατάσταση",
        "Brand New With Tags": "Καινό με ετικέτες",
        "Brand new Without Tags": "Καινό χωρίς ετικέτες",
        "Heavily Used": "Έντονα χρησιμοποιημένο",
        "Apply": "Εφαρμογή",
        "Min. Price": "Ελάχ. τιμή",
        "Max. Price": "Μέγ. τιμή",

        // Sell
        "Sell an item": "Πώληση προϊόντος",
        "Close": "Κλείσιμο",
        "Send to": "Αποστολή σε",
        "Recent": "Πρόσφατα",
        "Search username": "Αναζήτηση ονόματος χρήστη",
        "Search results": "Αποτελέσματα αναζήτησης",
        "No users found": "Δεν βρέθηκαν χρήστες",
        "No recipients yet": "Δεν υπάρχουν παραλήπτες ακόμα",
        "Message someone, get followers, or search by username.": "Στείλτε μήνυμα, αποκτήστε ακόλουθους ή αναζητήστε με όνομα χρήστη.",
        "Sign in to share.": "Συνδεθείτε για κοινοποίηση.",
        "Upload": "Μεταφόρτωση",
        "Upload from drafts": "Μεταφόρτωση από πρόχειρα",
        "Save draft": "Αποθήκευση πρόχειρου",
        "Drafts": "Πρόχειρα",
        "Save draft before exiting?": "Αποθήκευση πρόχειρου πριν την έξοδο;",
        "You have unsaved changes.": "Έχετε μη αποθηκευμένες αλλαγές.",
        "Discard": "Απόρριψη",
        "Select drafts": "Επιλογή προχείρων",
        "Untitled draft": "Πρόχειρο χωρίς τίτλο",
        "Draft saved": "Το πρόχειρο αποθηκεύτηκε",
        "Your listing has been saved as a draft. Open it from the drafts button on Sell.": "Η καταχώρισή σας αποθηκεύτηκε ως πρόχειρο. Ανοίξτε το από το κουμπί προχείρων στην οθόνη Πώλησης.",
        "Listing saved": "Η αγγελία αποθηκεύτηκε",
        "Schedule listing": "Προγραμματισμός δημοσίευσης",
        "Go live on": "Ενεργοποίηση στις",
        "Your post is ready": "Η δημοσίευσή σας είναι έτοιμη",
        "\"%@\" is live. Tap to open your profile and view it.": "Το «%@» είναι ενεργό. Πατήστε για να ανοίξετε το προφίλ σας και να το δείτε.",
        "View": "Προβολή",
        "Listing scheduled": "Προγραμματισμένη αγγελία",
        "Your listing will appear on your profile on %@.": "Η αγγελία σας θα εμφανιστεί στο προφίλ σας στις %@.",
        "Your profile will list this at the date and time below.": "Το προφίλ σας θα εμφανίσει αυτή την αγγελία στην ημερομηνία και ώρα παρακάτω.",
        "When should it appear on your profile?": "Πότε θέλετε να εμφανιστεί στο προφίλ σας;",
        "Post now": "Τώρα",
        "Later": "Αργότερα",
        "Appear on profile": "Εμφάνιση στο προφίλ",
        "Scheduled": "Προγραμματισμένο",
        "Your listing": "Η αγγελία σας",
        "\"%@\" should appear on your profile around this time. Open the app to refresh your shop.": "Το «%@» θα πρέπει να εμφανιστεί στο προφίλ σας περίπου αυτή την ώρα. Ανοίξτε την εφαρμογή για να ανανεώσετε το κατάστημά σας.",
        "Your listing is saved as inactive and hidden from the feed until you activate it from your profile. Wearhouse does not automatically publish at the scheduled time yet. If you allow notifications, we scheduled a reminder for the time you chose.": "Η αγγελία σας αποθηκεύτηκε ως ανενεργή και δεν εμφανίζεται στο feed μέχρι να την ενεργοποιήσετε από το προφίλ σας. Το Wearhouse δεν δημοσιεύει αυτόματα στη προγραμματισμένη ώρα ακόμα. Αν επιτρέψετε ειδοποιήσεις, προγραμματίσαμε υπενθύμιση για την ώρα που επιλέξατε.",
        "Saves as inactive until you activate it from your profile. Wearhouse does not go live automatically at this time yet. If you allow notifications, we add a reminder when this time is reached.": "Αποθηκεύεται ως ανενεργή μέχρι να την ενεργοποιήσετε από το προφίλ σας. Το Wearhouse δεν δημοσιεύεται αυτόματα αυτή τη στιγμή ακόμα. Αν επιτρέψετε ειδοποιήσεις, προσθέτουμε υπενθύμιση όταν φτάσει αυτή η ώρα.",
        "Time to publish your listing": "Ώρα να δημοσιεύσετε την αγγελία σας",
        "\"%@\" is still inactive. Open Profile and activate it to go live.": "Το «%@» είναι ακόμα ανενεργό. Ανοίξτε το Προφίλ και ενεργοποιήστε το για να εμφανιστεί.",
        "Add up to 20 photos": "Προσθήκη έως 20 φωτογραφιών",
        "Add photo": "Προσθήκη φωτογραφίας",
        "Suggest from title": "Πρόταση από τίτλο",
        "Suggest from photo": "Πρόταση από φωτογραφία",
        "Tap to select photos from your gallery": "Αγγίξτε για να επιλέξετε φωτογραφίες από τη συλλογή σας",
        "Choose images from Finder": "Επιλέξτε εικόνες από το Finder",
        "Choose photos from Finder": "Επιλέξτε φωτογραφίες από το Finder",
        "Tap to choose photo": "Αγγίξτε για να επιλέξετε φωτογραφία",
        "Tap to choose photos": "Αγγίξτε για να επιλέξετε φωτογραφίες",
        "Choose a photo from Finder": "Επιλέξτε μια φωτογραφία από το Finder",
        "Item Details": "Στοιχεία προϊόντος",
        "Item Information": "Πληροφορίες προϊόντος",
        "Category": "Κατηγορία",
        "Brand": "Μάρκα",
        "Colours": "Χρώματα",
        "Colour": "Χρώμα",
        "Style": "Στυλ",
        "Additional Details": "Επιπλέον στοιχεία",
        "Measurements (Optional)": "Διαστάσεις (προαιρετικό)",
        "Material (Optional)": "Υλικό (προαιρετικό)",
        "Style (Optional)": "Στυλ (προαιρετικό)",
        "Pricing & Shipping": "Τιμή και αποστολή",
        "Discount Price (Optional)": "Εκπτωτική τιμή (προαιρετικό)",
        "Parcel Size": "Μέγεθος δέματος",
        "The buyer always pays for postage.": "Ο αγοραστής πληρώνει πάντα την αποστολή.",
        "Select Category": "Επιλογή κατηγορίας",
        "Search categories": "Αναζήτηση κατηγοριών",
        "Search shop": "Αναζήτηση καταστήματος",
        "No categories found": "Δεν βρέθηκαν κατηγορίες",
        "Select": "Επιλογή",
        "Selected": "Επιλεγμένο",
        "Select Condition": "Επιλογή κατάστασης",
        "Select Colours": "Επιλογή χρωμάτων",
        "Measurements": "Διαστάσεις",
        "Add measurements like chest, waist, length": "Προσθέστε διαστάσεις π.χ. στήθος, μέση, μήκος",
        "Label": "Ετικέτα",
        "Value": "Τιμή",
        "Add measurement": "Προσθήκη μέτρησης",
        "Custom…": "Προσαρμογή…",
        "Select Material": "Επιλογή υλικού",
        "Select Style": "Επιλογή στυλ",
        "Find a style": "Βρείτε στυλ",
        "Discount: %d%%": "Έκπτωση: %d%%",
        "Please set the price first": "Ορίστε πρώτα την τιμή",
        "Discount Price": "Εκπτωτική τιμή",
        "Sale price": "Τιμή πώλησης",
        "Amount off": "Ποσό έκπτωσης",
        "Optional. Enter the discounted price; the discount % is calculated from the main price.": "Προαιρετικό. Εισάγετε την εκπτωτική τιμή· το % έκπτωσης υπολογίζεται από την κύρια τιμή.",
        "Enter the amount to take off the price (e.g. 13 for £13 off).": "Εισάγετε το ποσό που αφαιρείται από την τιμή (π.χ. 13 για 13 £ έκπτωση).",
        "Listed price": "Τιμή καταλόγου",
        "Final price": "Τελική τιμή",
        "Discount (%)": "Έκπτωση (%)",
        "Edit discount % or sale price; both stay in sync.": "Επεξεργαστείτε % έκπτωσης ή τιμή πώλησης· συγχρονίζονται μεταξύ τους.",
        "Loading brands...": "Φόρτωση μαρκών...",
        "Loading more...": "Φόρτωση περισσότερων...",
        "No brands match your search.": "Δεν βρέθηκαν μάρκες που ταιριάζουν με την αναζήτησή σας.",
        "Try Cart": "Δοκιμαστικό καλάθι",
        "One bag, many sellers": "Ένα καλάθι, πολλοί πωλητές",
        "Try Cart lets you add pieces from different shops into a single bag. Keep browsing—your picks stay with you everywhere on WEARHOUSE.": "Το Δοκιμαστικό καλάθι σάς επιτρέπει να προσθέτετε κομμάτια από διαφορετικά καταστήματα σε ένα καλάθι. Συνεχίστε την περιήγηση—οι επιλογές σας μένουν μαζί σας παντού στο WEARHOUSE.",
        "Save time on every haul": "Εξοικονομήστε χρόνο σε κάθε αγορά",
        "No more jumping seller by seller. Search, tap the bag, and build your haul in one flow—with a running total so you always know where you stand.": "Χωρίς άλματα από πωλητή σε πωλητή. Αναζητήστε, πατήστε το καλάθι και χτίστε την αγορά σας σε μία ροή—με τρέχον σύνολο ώστε να ξέρετε πάντα πού βρίσκεστε.",
        "Shop smarter, checkout clearer": "Ψωνίστε πιο έξυπνα, ταμείο πιο καθαρά",
        "Use Try Cart from Shop All and favourites. Mix brands freely, review your bag anytime, then check out when you are ready—on your terms.": "Χρησιμοποιήστε το Δοκιμαστικό καλάθι από το Shop All και τα αγαπημένα. Αναμείξτε μάρκες ελεύθερα, δείτε το καλάθι σας όποτε θέλετε και ολοκληρώστε όταν είστε έτοιμοι—με τους δικούς σας όρους.",
        "Next": "Επόμενο",
        "Start shopping": "Ξεκινήστε τις αγορές",
        "Skip": "Παράλειψη",
        "Shop All": "Όλα τα προϊόντα",
        "Enter brand name": "Εισάγετε όνομα μάρκας",
        "Tip: similar price range is recommended based on similar items sold on WEARHOUSE.": "Συμβουλή: συνιστάται παρόμοιο εύρος τιμών με βάση παρόμοια αντικείμενα που πωλήθηκαν στο WEARHOUSE.",
        "Similar sold items": "Παρόμοια πωλημένα αντικείμενα",

        // Discover
        "Featured": "Προτεινόμενα",
        "Recently viewed": "Πρόσφατα προβεβλημένα",
        "See All": "Δείτε όλα",
        "Results": "Αποτελέσματα",
        "Brands You Love": "Οι αγαπημένες σας μάρκες",
        "Recommended from your favourite brands": "Προτεινόμενα από τις αγαπημένες σας μάρκες",
        "Top Shops": "Κορυφαία καταστήματα",
        "Buy from trusted and popular vendors": "Αγοράστε από αξιόπιστους και δημοφιλείς πωλητές",
        "Shop Bargains": "Προσφορές",
        "Steals under £15": "Ευκαιρίες κάτω από 15 £",
        "On Sale": "Προσφορά",
        "Discounted items": "Προϊόντα με έκπτωση",

        // Notifications & Chat
        "No notifications": "Δεν υπάρχουν ειδοποιήσεις",
        "Messages": "Μηνύματα",
        "Type a message...": "Πληκτρολογήστε μήνυμα...",
        "Thinking...": "Σκέφτομαι...",
        "Welcome to the chat, I'm Lenny, and I'm here to assist you. Send a message to get started.": "Καλώς ήρθατε στη συνομιλία, είμαι ο Lenny και είμαι εδώ για να σας βοηθήσω. Στείλτε ένα μήνυμα για να ξεκινήσετε.",
        "Hi! What are you looking for? Try something like a dress, jacket, or shoes.": "Γεια! Τι ψάχνετε; Δοκιμάστε π.χ. φόρεμα, ζακέτα ή παπούτσια.",
        "Hello! I can help you find something. Try asking for a colour and item, like red dress or blue shoes.": "Γεια σας! Μπορώ να σας βοηθήσω να βρείτε κάτι. Ζητήστε χρώμα και είδος, π.χ. κόκκινο φόρεμα ή μπλε παπούτσια.",
        "Hey! What would you like to find? For example: black jacket, white trainers, or a green dress.": "Γεια! Τι θα θέλατε να βρείτε; Π.χ. μαύρη ζακέτα, λευκά παπούτσια ή πράσινο φόρεμα.",
        "Hi there! I'm here to help you shop. Try something like navy blazer or pink skirt.": "Γεια σας! Είμαι εδώ για να σας βοηθήσω να ψωνίσετε. Δοκιμάστε π.χ. μπλε μπλεζέ ή ροζ φούστα.",
        "I'm good, thanks! What can I help you find today? Try a colour and item, like red dress or blue shoes.": "Καλά είμαι, ευχαριστώ! Τι μπορώ να σας βρω σήμερα; Δοκιμάστε χρώμα και είδος, π.χ. κόκκινο φόρεμα ή μπλε παπούτσια.",
        "Doing great! What are you looking for? I can help you find dresses, jackets, shoes, and more.": "Τέλεια! Τι ψάχνετε; Μπορώ να βρω φορέματα, ζακέτες, παπούτσια και άλλα.",
        "All good here! What would you like to browse? Try something like green hoodie or beige coat.": "Όλα καλά! Τι θα θέλατε να δείτε; Δοκιμάστε π.χ. πράσινο κοντομάνικο ή μπεζ παλτό.",
        "I'm doing well, thanks for asking! What can I find for you? For example: black jacket or white trainers.": "Καλά είμαι, ευχαριστώ που ρωτήσατε! Τι μπορώ να σας βρω; Π.χ. μαύρη ζακέτα ή λευκά παπούτσια.",
        "Good, thanks! How can I help you shop today? Try asking for an item and colour.": "Καλά, ευχαριστώ! Πώς μπορώ να σας βοηθήσω να ψωνίσετε σήμερα; Ζητήστε ένα είδος και χρώμα.",
        "I don't understand that. I can help you find items by colour, category, or style—try something like \"red dress\" or \"blue shoes\".": "Δεν το καταλαβαίνω. Μπορώ να βοηθήσω να βρείτε προϊόντα κατά χρώμα, κατηγορία ή στυλ—δοκιμάστε π.χ. «κόκκινο φόρεμα» ή «μπλε παπούτσια».",
        "I'm not sure about that. I'm best at finding clothes and accessories—try something like pink skirt or navy blazer.": "Δεν είμαι σίγουρος. Γνωρίζω καλύτερα ρούχα και αξεσουάρ—δοκιμάστε π.χ. ροζ φούστα ή μπλε μπλεζέ.",
        "That's outside what I can help with. I can search for items by colour and type—e.g. green hoodie or beige coat.": "Αυτό δεν μπορώ να το βοηθήσω. Μπορώ να ψάξω προϊόντα κατά χρώμα και είδος—π.χ. πράσινο κοντομάνικο ή μπεζ παλτό.",
        "We don't have size %@ in these results, but here are some options you might like.": "Δεν έχουμε μέγεθος %@ σε αυτά τα αποτελέσματα, αλλά ορίστε μερικές επιλογές που μπορεί να σας αρέσουν.",

        // Auth (extra)
        "Create Account": "Δημιουργία λογαριασμού",
        "Join WEARHOUSE today": "Γίνε μέλος του WEARHOUSE σήμερα",
        "Email": "Email",
        "First Name": "Όνομα",
        "Last Name": "Επώνυμο",
        "Confirm Password": "Επιβεβαίωση κωδικού",
        "Forgot Password": "Ξεχάσατε τον κωδικό;",
        "Enter the email address associated with your account and we'll send you a link to reset your password.": "Εισάγετε το email του λογαριασμού σας και θα σας στείλουμε σύνδεσμο για επαναφορά κωδικού.",
        "Check your email": "Ελέγξτε το email σας",
        "We've sent a 6-digit code to %@. Enter it on the next screen to set a new password.": "Στείλαμε 6ψήφιο κωδικό στο %@. Εισάγετέ τον στην επόμενη οθόνη για νέο κωδικό.",
        "Enter code": "Εισάγετε κωδικό",
        "Send reset link": "Αποστολή συνδέσμου επαναφοράς",
        "Enter your email": "Εισάγετε το email σας",

        // Item detail
        "Member's items": "Προϊόντα μέλους",
        "Similar items": "Παρόμοια προϊόντα",
        "Shop bundles": "Αγορές σε πακέτα",
        "Shop Multibuy": "Πολυαγορά καταστήματος",
        "multibuy": "πολυαγορά",
        "Save on postage": "Εξοικονομήστε στην αποστολή",
        "No member items available yet": "Δεν υπάρχουν ακόμα προϊόντα μέλους",
        "No similar items available yet": "Δεν υπάρχουν ακόμα παρόμοια προϊόντα",
        "Your offer": "Η προσφορά σας",
        "Message (optional)": "Μήνυμα (προαιρετικό)",
        "Send an offer": "Αποστολή προσφοράς",

        // Holiday Mode (seller away)
        "Note: Turning on Holiday Mode will hide your items from all catalogues": "Σημείωση: Η ενεργοποίηση της λειτουργίας αργίας θα αποκρύψει τα προϊόντα σας από όλους τους καταλόγους",
        "Holiday Mode is on": "Η λειτουργία αργίας είναι ενεργή",
        "This member is on holiday": "Αυτό το μέλος είναι σε λειτουργία αργίας",

        // Shop value
        "Current shop value": "Τρέχουσα αξία καταστήματος",
        "active listings": "ενεργές αγγελίες",
        "Balance": "Υπόλοιπο",
        "Pending %@": "Εκκρεμεί %@",
        "This month": "Αυτό το μήνα",
        "Total earnings": "Συνολικά κέρδη",
        "Lifetime": "Συνολικά (πάντα)",
        "transactions completed": "ολοκληρωμένες συναλλαγές",
        "Transactions completed": "Ολοκληρωμένες συναλλαγές",
        "Help": "Βοήθεια",
        "Status": "Κατάσταση",
        "Seller": "Πωλητής",
        "Buyer": "Αγοραστής",
        "Other party": "Άλλο μέρος",
        "Items": "Προϊόντα",
        "Summary": "Σύνοψη",
        "Total": "Σύνολο",
        "Pending orders": "Εκκρεμείς παραγγελίες",
        "Earnings & balance": "Κέρδη και υπόλοιπο",
        "Withdraw": "Ανάληψη",
        "Back": "Πίσω",
        "Continue": "Συνέχεια",
        "Continue with one item": "Συνέχεια με 1 προϊόν",
        "Continue with %d items": "Συνέχεια με %d προϊόντα",
        "Add Items": "Προσθήκη προϊόντων",
        "Brands": "Μάρκες",
        "Search and tap a brand to add it.": "Αναζητήστε και πατήστε μια μάρκα για να την προσθέσετε.",
        "Please add at least one brand.": "Προσθέστε τουλάχιστον μία μάρκα.",
        "List a mystery box": "Δημιουργία κουτιού μυστηρίου",
        "Schedule listing": "Προγραμματισμός αγγελίας",
        "Go live on": "Δημοσίευση στις",
        "Scheduled listing": "Προγραμματισμένη αγγελία",
        "Scheduled publishing isn’t available on the server yet. Your listing will go live immediately after upload.": "Η προγραμματισμένη δημοσίευση δεν είναι ακόμα διαθέσιμη στον διακομιστή. Η αγγελία σας θα εμφανιστεί αμέσως μετά το ανέβασμα.",
        "Your listing will be published automatically at this time.": "Η αγγελία σας θα δημοσιευτεί αυτόματα αυτή την ώρα.",
        "The app cannot send this time to the server yet. You will confirm before upload.": "Η εφαρμογή δεν μπορεί ακόμα να στείλει αυτή την ώρα στον διακομιστή. Θα σας ζητηθεί επιβεβαίωση πριν το ανέβασμα.",
        "Upload now": "Ανέβασμα τώρα",
        "Mystery box": "Κουτί μυστηρίου",
        "Multiple brands": "Πολλαπλές μάρκες",
        "Included in this box": "Περιλαμβάνονται σε αυτό το κουτί",
        "Change": "Αλλαγή",
        "Change listings": "Αλλαγή λιστών",
        "Add": "Προσθήκη",
        "Added": "Προστέθηκε",
        "Mystery box price cannot exceed £100.": "Η τιμή του κουτιού μυστηρίου δεν μπορεί να υπερβαίνει τα £100.",
        "Please enter a price.": "Εισάγετε τιμή.",
        "Select at least one listing to include in your mystery box.": "Επιλέξτε τουλάχιστον μία αγγελία για το κουτί μυστηρίου σας.",
        "Search products": "Αναζήτηση προϊόντων",
        "Box details": "Λεπτομέρειες κουτιού",
        "Box Information": "Πληροφορίες κουτιού",
        "Describe your box": "Περιγράψτε το κουτί σας",
        "e.g. what buyers might receive, sizes, or themes": "π.χ. τι μπορεί να λάβει ο αγοραστής, μεγέθη ή θέματα",
        "Mystery category is not available yet. Try again after the app updates.": "Η κατηγορία Mystery δεν είναι διαθέσιμη ακόμα. Δοκιμάστε ξανά μετά την ενημέρωση της εφαρμογής.",
        "Bank details": "Τραπεζικά στοιχεία",
        "Review withdrawal": "Επιβεβαίωση ανάληψης",
        "How much would you like to withdraw?": "Πόσο θέλετε να αναλήψετε;",
        "Available balance": "Διαθέσιμο υπόλοιπο",
        "Amount cannot exceed available balance.": "Το ποσό δεν μπορεί να υπερβαίνει το διαθέσιμο υπόλοιπο.",
        "Withdrawal requested": "Ανάληψη ζητήθηκε",
        "Your withdrawal of %@ will usually reach your bank within 30 minutes.": "Η ανάληψή σας %@ συνήθως φτάνει στην τράπεζά σας εντός 30 λεπτών.",
        "Withdrawing to account ending in %@": "Ανάληψη σε λογαριασμό που τελειώνει σε %@",
        "You'll add your bank details on the next step.": "Θα προσθέσετε τα τραπεζικά σας στοιχεία στο επόμενο βήμα.",
        "Withdrawals usually reach your bank within 30 minutes.": "Οι αναλήψεις συνήθως φτάνουν στην τράπεζά σας εντός 30 λεπτών.",
        "Account holder": "Δικαιούχος λογαριασμού",
        "Confirm your withdrawal": "Επιβεβαιώστε την ανάληψή σας",
        "Enter your UK bank details. Withdrawals usually reach your bank within 30 minutes.": "Εισάγετε τα στοιχεία της βρετανικής τράπεζάς σας. Οι αναλήψεις συνήθως φτάνουν στην τράπεζά σας εντός 30 λεπτών.",
        "Buyer protection fee": "Τέλος προστασίας αγοραστή",
        "Card ending in %@": "Κάρτα που τελειώνει σε %@",
        "No payment method added": "Δεν προστέθηκε μέθοδος πληρωμής",
        "Add payment method": "Προσθήκη μεθόδου πληρωμής",
        "Payment": "Πληρωμή",
        "This is a secure encryption payment": "Αυτή είναι ασφαλής κρυπτογραφημένη πληρωμή",

        // Reviews
        "No reviews yet": "Δεν υπάρχουν ακόμα κριτικές",
        "No reviews in this category": "Δεν υπάρχουν κριτικές σε αυτή την κατηγορία",
        "Member reviews (%@)": "Κριτικές μελών (%@)",
        "Automatic reviews (%@)": "Αυτόματες κριτικές (%@)",
        "How reviews work": "Πώς λειτουργούν οι κριτικές",

        // Followers / Following (Following key already in Profile section)
        "No followers yet": "Δεν υπάρχουν ακόμα οπαδοί",
        "Not following anyone yet": "Δεν ακολουθείτε ακόμα κανέναν",

        // Settings (extended)
        "Saved": "Αποθηκεύτηκε",
        "Your postage settings have been saved.": "Οι ρυθμίσεις αποστολής σας αποθηκεύτηκαν.",
        "Your bank account has been saved. Payouts will be sent here when delivery is complete and the customer is happy.": "Ο τραπεζικός σας λογαριασμός αποθηκεύτηκε. Οι πληρωμές θα σταλούν εδώ όταν η παράδοση ολοκληρωθεί και ο πελάτης είναι ικανοποιημένος.",
        "Unlock your account": "Ξεκλειδώστε τον λογαριασμό σας",
        "Verify your identity to access all features and build trust with buyers.": "Επαληθεύστε την ταυτότητά σας για πρόσβαση σε όλες τις λειτουργίες και να δημιουργήσετε εμπιστοσύνη με αγοραστές.",
        "Current Password": "Τρέχων κωδικός",
        "New Password": "Νέος κωδικός",
        "Confirm New Password": "Επιβεβαίωση νέου κωδικού",
        "Passwords do not match": "Οι κωδικοί δεν ταιριάζουν",
        "Reset Password": "Επαναφορά κωδικού",
        "Your password has been changed successfully.": "Ο κωδικός σας άλλαξε με επιτυχία.",
        "Pausing your account will hide your profile and listings. You can reactivate later by logging in.": "Η παύση του λογαριασμού θα αποκρύψει το προφίλ και τις αγγελίες σας. Μπορείτε να τον ξαναενεργοποιήσετε συνδεόμενοι.",
        "Pause Account": "Παύση λογαριασμού",
        "Your profile and listings will be hidden until you log in again.": "Το προφίλ και οι αγγελίες σας θα αποκρυφθούν μέχρι να συνδεθείτε ξανά.",
        "Your account has been paused. You will be signed out.": "Ο λογαριασμός σας έχει παυθεί. Θα αποσυνδεθείτε.",
        "Enter your UK bank details. Your information is stored securely and used only for payouts.": "Εισάγετε τα στοιχεία της βρετανικής τράπεζάς σας. Τα στοιχεία σας αποθηκεύονται ασφαλώς και χρησιμοποιούνται μόνο για πληρωμές.",
        "Sort code": "Κωδικός ταξινόμησης",
        "Account number": "Αριθμός λογαριασμού",
        "Account holder name": "Όνομα δικαιούχου",
        "Account label (optional)": "Ετικέτα λογαριασμού (προαιρετικό)",
        "Add Bank Account": "Προσθήκη τραπεζικού λογαριασμού",
        "Address": "Διεύθυνση",
        "Address line 1": "Διεύθυνση γραμμή 1",
        "Address line 2": "Διεύθυνση γραμμή 2",
        "Address line 2 (optional)": "Διεύθυνση γραμμή 2 (προαιρετικό)",
        "City": "Πόλη",
        "State / County": "Νομός / Κομητεία",
        "Country": "Χώρα",
        "Postcode": "Ταχυδρομικός κώδικας",
        "Your shipping address has been updated.": "Η διεύθυνση αποστολής σας ενημερώθηκε.",
        "Your account settings have been updated.": "Οι ρυθμίσεις λογαριασμού σας ενημερώθηκαν.",
        "Date of birth": "Ημερομηνία γέννησης",
        "Gender": "Φύλο",
        "Enter your card details securely. Your payment information is encrypted.": "Εισάγετε τα στοιχεία της κάρτας σας ασφαλώς. Οι πληροφορίες πληρωμής κρυπτογραφούνται.",
        "Card number": "Αριθμός κάρτας",
        "Expiry": "Λήξη",
        "CVV": "CVV",
        "Name on card": "Όνομα στην κάρτα",
        "Add Payment Card": "Προσθήκη κάρτας πληρωμής",
        "Your payment method has been saved.": "Η μέθοδος πληρωμής σας αποθηκεύτηκε.",
        "Deleting your account is permanent. You will lose access to your listings, messages, and data.": "Η διαγραφή του λογαριασμού είναι μόνιμη. Θα χάσετε την πρόσβαση στις αγγελίες, μηνύματα και δεδομένα σας.",
        "Delete Account": "Διαγραφή λογαριασμού",
        "This action cannot be undone. All your data will be permanently removed.": "Αυτή η ενέργεια δεν μπορεί να αναιρεθεί. Όλα τα δεδομένα σας θα αφαιρεθούν μόνιμα.",
        "Delete All Conversations": "Διαγραφή όλων των συνομιλιών",
        "Royal Mail": "Royal Mail",
        "DPD": "DPD",
        "Bio": "Βιογραφικό",
        "No blocked users": "Δεν υπάρχουν αποκλεισμένοι χρήστες",
        "Do you want to unblock %@?": "Θέλετε να ξεμπλοκάρετε τον %@;",
        "Blocklist": "Λίστα αποκλεισμού",
        "Active Payment method": "Ενεργή μέθοδος πληρωμής",
        "Active bank account": "Ενεργός τραπεζικός λογαριασμός",
        "No bank account added": "Δεν προστέθηκε τραπεζικός λογαριασμός",
        "Payouts are sent here when delivery is complete.": "Οι πληρωμές αποστέλλονται εδώ όταν η παράδοση ολοκληρωθεί.",
        "Seen": "Διαβάστηκε",
        "Delete": "Διαγραφή",
        "Delete this post?": "Διαγραφή αυτής της ανάρτησης;",
        "This cannot be undone.": "Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.",
        "More options": "Περισσότερες επιλογές",
        "Analytics": "Αναλυτικά",
        "This card will be removed from your account.": "Αυτή η κάρτα θα αφαιρεθεί από τον λογαριασμό σας.",
        "Remove bank account?": "Αφαίρεση τραπεζικού λογαριασμού;",
        "Payouts will not be sent until you add a bank account again.": "Οι πληρωμές δεν θα αποστέλλονται μέχρι να προσθέσετε ξανά τραπεζικό λογαριασμό.",
        "General": "Γενικά",
        "Notification Settings": "Ρυθμίσεις ειδοποιήσεων",

        // Network / connection errors
        "Unable to connect. Please check your internet connection.": "Αδυναμία σύνδεσης. Ελέγξτε τη σύνδεσή σας στο διαδίκτυο.",
        "Connection timed out. Please try again.": "Λήξη χρόνου σύνδεσης. Δοκιμάστε ξανά.",
        "We couldn't complete a secure connection. Please try again shortly.": "Δεν ήταν δυνατή η ασφαλής σύνδεση. Δοκιμάστε ξανά σε λίγο.",
        "Secure connection": "Ασφαλής σύνδεση",
        "Try again": "Δοκιμάστε ξανά",
        "Pull down to refresh": "Σύρετε προς τα κάτω για ανανέωση",
        "Something went wrong. Please try again.": "Κάτι πήγε στραβά. Δοκιμάστε ξανά.",

        // AI chat – empty results
        "I couldn't find anything matching that. Try different colours or categories.": "Δεν βρήκα τίποτα που να ταιριάζει. Δοκιμάστε άλλα χρώματα ή κατηγορίες.",
        "Do you mean \"%@\"?": "Εννοείτε \"%@\";",
        // AI chat – reply variations (happy event)
        "Happy to help! Here are some options you might like.": "Χαίρομαι να βοηθάω! Ορίστε μερικές επιλογές που μπορεί να σας αρέσουν.",
        "Sounds exciting! Here are some picks for you.": "Ακούγεται συναρπαστικό! Ορίστε μερικές επιλογές για εσάς.",
        "Let's find something great. Here are some options.": "Ας βρούμε κάτι ωραίο. Ορίστε μερικές επιλογές.",
        "Here are some items that could work perfectly.": "Ορίστε μερικά αντικείμενα που μπορεί να ταιριάξουν τέλεια.",
        "Hope you find something you love. Here are some options.": "Ελπίζω να βρείτε κάτι που σας αρέσει. Ορίστε μερικές επιλογές.",
        // AI chat – reply variations (sad event, neutral tone)
        "I understand. Here are some appropriate options.": "Κατανοώ. Ορίστε μερικές κατάλληλες επιλογές.",
        "I'll help you find something suitable.": "Θα σας βοηθήσω να βρείτε κάτι κατάλληλο.",
        "Here are some options that might work.": "Ορίστε μερικές επιλογές που μπορεί να ταιριάξουν.",
        "Let me show you some suitable options.": "Επιτρέψτε μου να σας δείξω μερικές κατάλληλες επιλογές.",
        // AI chat – reply variations (neutral)
        "Here are some items that might work.": "Ορίστε μερικά αντικείμενα που μπορεί να ταιριάξουν.",
        "Here are some options for you.": "Ορίστε μερικές επιλογές για εσάς.",
        "These might match what you're looking for.": "Αυτά μπορεί να ταιριάζουν με αυτό που ψάχνετε.",
        "Here are some picks based on your search.": "Ορίστε μερικές επιλογές βάσει της αναζήτησής σας.",
        // Chat reactions
        "Reactions": "Αντιδράσεις",
        "Search emojis": "Αναζήτηση emoji",
        "No matching emojis": "Δεν βρέθηκαν emoji",

        // Plan & seller limits
        "Plan": "Πλάνο",
        "Your plan": "Το πλάνο σας",
        "Silver": "Silver",
        "Gold": "Gold",
        "Gold + unlimited mystery": "Gold + απεριόριστα mystery",
        "Your Wearhouse profile tier includes Gold benefits.": "Η βαθμίδα του προφίλ σας στο Wearhouse περιλαμβάνει προνόμια Gold.",
        "Unlimited product uploads": "Απεριόριστες αναρτήσεις προϊόντων",
        "Up to 1 active mystery box listing": "Έως 1 ενεργή ανάρτηση mystery box",
        "You've reached your scheduled listing limit for this billing period. Gold allows more each month. Open Settings → Plan to upgrade.": "Φτάσατε το όριο προγραμματισμένων αναρτήσεων για αυτή την περίοδο χρέωσης. Το Gold επιτρέπει περισσότερες κάθε μήνα. Ανοίξτε Ρυθμίσεις → Plan για αναβάθμιση.",
        "Scheduled listings": "Προγραμματισμένες αναρτήσεις",
        "%d of %d scheduled listings used this billing period.": "%1$d από %2$d προγραμματισμένες αναρτήσεις χρησιμοποιήθηκαν αυτή την περίοδο χρέωσης.",
        "0% selling fees": "0% προμήθειες πώλησης",
        "Current plan": "Τρέχον πλάνο",
        "Everything in Silver": "Όλα του Silver",
        "Up to 5 active mystery box listings": "Έως 5 ενεργές αναρτήσεις mystery box",
        "Priority placement in search & category browsing": "Προτεραιότητα στην αναζήτηση και τις κατηγορίες",
        "Priority seller support": "Προτεραιότητα στην υποστήριξη πωλητών",
        "Upgrade to Gold": "Αναβάθμιση σε Gold",
        "Remove local Gold preview": "Αφαίρεση τοπικής προεπισκόπησης Gold",
        "Unlimited mystery boxes": "Απεριόριστα mystery boxes",
        "Requires an active Gold plan. Billed monthly when in-app purchases go live.": "Απαιτείται ενεργό Gold. Χρέωση μηνιαία όταν ενεργοποιηθούν οι αγορές εντός εφαρμογής.",
        "No cap on active mystery box listings": "Χωρίς όριο ενεργών mystery box",
        "£10.99/month after purchase": "£10,99/μήνα μετά την αγορά",
        "Subscribed (preview)": "Συνδρομή (προεπισκόπηση)",
        "Turn off preview subscription": "Απενεργοποίηση προεπισκόπησης συνδρομής",
        "Subscribe — £10.99/month": "Συνδρομή — £10.99/μήνα",
        "Gold unlocks more mystery box listings and priority visibility. App Store billing will be available soon; you can enable a preview on this device for testing.": "Το Gold ξεκλειδώνει περισσότερα mystery box και προτεραιότητα εμφάνισης. Η χρέωση μέσω App Store θα είναι σύντομα διαθέσιμη· μπορείτε να ενεργοποιήσετε προεπισκόπηση σε αυτή τη συσκευή.",
        "Enable Gold (preview)": "Ενεργοποίηση Gold (προεπισκόπηση)",
        "Add unlimited active mystery box listings for £10.99/month. This add-on requires Gold. In-app purchase coming soon — enable preview for testing.": "Προσθέτει απεριόριστα ενεργά mystery box για £10.99/μήνα. Απαιτείται Gold. Η αγορά εντός εφαρμογής έρχεται σύντομα — ενεργοποιήστε προεπισκόπηση για δοκιμές.",
        "Enable add-on (preview)": "Ενεργοποίηση add-on (προεπισκόπηση)",
        "You've reached the maximum number of mystery box listings for your plan. Open Settings → Plan to upgrade.": "Φτάσατε το μέγιστο mystery box για το πλάνο σας. Ανοίξτε Ρυθμίσεις → Plan για αναβάθμιση.",
        "Mystery box limit": "Όριο mystery box",
        "Card": "Κάρτα",

        // Plan screen (carousel)
        "Essential seller tools": "Βασικά εργαλεία πωλητή",
        "Grow faster on Wearhouse": "Μεγαλώστε πιο γρήγορα στο Wearhouse",
        "For mystery power sellers": "Για power sellers mystery",
        "Swipe to compare tiers": "Σαρώστε για να συγκρίνετε πακέτα",
        "The standard for most sellers": "Το πρότυπο για τους περισσότερους πωλητές",
        "More reach, more mystery boxes": "Περισσότερη προβολή, περισσότερα mystery boxes",
        "No ceiling on mystery listings": "Χωρίς όριο στις mystery αναρτήσεις",
        "Unlimited mystery": "Απεριόριστο mystery",
        "Unlimited mystery add-on is active on top of Gold.": "Το add-on απεριόριστου mystery είναι ενεργό πάνω στο Gold.",
        "Requires Gold. Billed monthly when IAP is live.": "Απαιτείται Gold. Χρέωση μηνιαία όταν ενεργοποιηθούν οι αγορές εντός εφαρμογής.",
        "Prices and entitlements will sync from your App Store subscription when billing goes live.": "Οι τιμές και τα δικαιώματα θα συγχρονίζονται από τη συνδρομή App Store όταν ενεργοποιηθεί η χρέωση.",

    ]
}

// MARK: - User-facing error messages
extension L10n {

    /// Pull-to-refresh and navigation often cancel in-flight URLSession work; never show that as an error banner.
    static func isCancellationLikeError(_ error: Error) -> Bool {
        for e in unwindErrorChain(error) {
            if e is CancellationError { return true }
            if let url = e as? URLError, url.code == .cancelled { return true }
            let ns = e as NSError
            if ns.code == NSURLErrorCancelled { return true }
        }
        let desc = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if desc == "cancelled" || desc == "canceled" { return true }
        if desc == "operation cancelled" || desc == "operation canceled" { return true }
        if desc.hasPrefix("cancelled") && desc.count <= 48 { return true }
        if desc.hasPrefix("canceled") && desc.count <= 48 { return true }
        return false
    }

    /// Short headline for inline error banners when the issue is transport/security (optional UI).
    static func userFacingErrorBannerTitle(_ error: Error) -> String? {
        if isCancellationLikeError(error) { return nil }
        for e in unwindErrorChain(error) {
            if secureTransportMappedKey(for: e) != nil {
                return L10n.string("Secure connection")
            }
        }
        return nil
    }

    /// Returns a short, user-friendly message for API/network errors (never raw TLS/SSL strings in UI).
    /// Cancellation and superseded refresh tasks return an empty string so callers can hide banners without showing internal messages.
    static func userFacingError(_ error: Error) -> String {
        if isCancellationLikeError(error) {
            return ""
        }
        if let graphQLMapped = userFacingMessageForGraphQLError(error) {
            return graphQLMapped
        }
        for e in unwindErrorChain(error) {
            if let key = secureTransportMappedKey(for: e) {
                return L10n.string(key)
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                return ""
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return L10n.string("Unable to connect. Please check your internet connection.")
            case .timedOut:
                return L10n.string("Connection timed out. Please try again.")
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return L10n.string("Unable to connect. Please check your internet connection.")
            default:
                break
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorCancelled:
                return ""
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed:
                return L10n.string("Unable to connect. Please check your internet connection.")
            case NSURLErrorTimedOut:
                return L10n.string("Connection timed out. Please try again.")
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return L10n.string("Unable to connect. Please check your internet connection.")
            default:
                break
            }
        }
        if let apiMessage = userFacingMessageFromNSErrorChain(error) {
            return apiMessage
        }
        return L10n.string("Something went wrong. Please try again.")
    }

    /// Mutations such as `rateUser` return `success: false` with a plain-language `message`; the client throws `NSError` with that string. Show it when it does not look like GraphQL/decoding noise.
    private static func userFacingMessageFromNSErrorChain(_ error: Error) -> String? {
        for e in unwindErrorChain(error) {
            let ns = e as NSError
            if ns.domain == NSURLErrorDomain { continue }
            let desc = ns.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard userFacingNSErrorDescriptionLooksSafe(desc) else { continue }
            return desc
        }
        return nil
    }

    private static func userFacingNSErrorDescriptionLooksSafe(_ desc: String) -> Bool {
        if desc.isEmpty { return false }
        if desc.count > 900 { return false }
        if desc.rangeOfCharacter(from: .letters) == nil { return false }
        let lower = desc.lowercased()
        if lower.contains("graphql") { return false }
        if lower.contains("json") && (lower.contains("decod") || lower.contains("serial")) { return false }
        if lower.contains("variable") && lower.contains("$") { return false }
        if lower.contains("operation") && lower.contains("document") { return false }
        if lower.contains("swift.decoding") || lower.contains("swift/decoding") { return false }
        if lower == "the operation couldn’t be completed." { return false }
        if lower.hasPrefix("error domain=") { return false }
        return true
    }

    /// Human-readable line under interactive order-review stars (0…5 in half-star steps).
    static func orderReviewRatingSubtitle(for rating: Double) -> String {
        let step = min(10, max(0, Int((rating * 2).rounded())))
        return string(orderReviewRatingKeys[step])
    }

    private static let orderReviewRatingKeys: [String] = [
        "Tap to rate",
        "Very poor",
        "Poor",
        "Below average",
        "Fair",
        "Okay",
        "Good",
        "Very good",
        "Great",
        "Excellent",
        "Perfect",
    ]

    /// Avoid exposing decoding paths, HTTP codes, and GraphQL plumbing in production UI.
    private static func userFacingMessageForGraphQLError(_ error: Error) -> String? {
        guard let gq = error as? GraphQLError else { return nil }
        switch gq {
        case .noData:
            return L10n.string("Something went wrong. Please try again.")
        case .decodingError:
            return L10n.string("Something went wrong. Please try again.")
        case .httpError:
            return L10n.string("Something went wrong. Please try again.")
        case .networkError(let message):
            let lower = message.lowercased()
            if lower.contains("cancel") { return "" }
            if lower.contains("tls") || lower.contains("ssl") || lower.contains("certificate") {
                return L10n.string("We couldn't complete a secure connection. Please try again shortly.")
            }
            return L10n.string("Unable to connect. Please check your internet connection.")
        case .graphQLErrors(let errors):
            if GraphQLClient.graphQLErrorsIndicateInvalidSession(errors) {
                return ""
            }
            guard let raw = errors.first?.message.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return L10n.string("Something went wrong. Please try again.")
            }
            let lower = raw.lowercased()
            if lower.contains("updatelookbookpost"),
               lower.contains("cannot query field") || lower.contains("unknown field") {
                return L10n.string("Lookbook edits aren’t supported on this server yet. Deploy the updateLookbookPost API (see docs/lookbooks-backend-spec.md).")
            }
            if lower.contains("setlookbookproducttags"),
               lower.contains("cannot query field") || lower.contains("unknown field") {
                return L10n.string("Updating tagged products isn’t available on this server yet. Your team can deploy setLookbookProductTags when ready.")
            }
            if lower.contains("valid credentials") || (lower.contains("invalid") && lower.contains("credential")) {
                return L10n.string("Incorrect username or password. Use your username (not your email). For seed accounts, the password is the STAGING_SEED_PASSWORD from GitHub Actions — if that secret was changed after users were created, the old password still applies until you reset it.")
            }
            if lower.contains("variable") && lower.contains("$") { return L10n.string("Something went wrong. Please try again.") }
            if lower.contains("syntax") || (lower.contains("graphql") && lower.contains("error")) {
                return L10n.string("Something went wrong. Please try again.")
            }
            return raw
        }
    }

    private static func unwindErrorChain(_ error: Error) -> [Error] {
        var out: [Error] = [error]
        var cur: NSError? = error as NSError
        var guardDepth = 0
        while let n = cur, guardDepth < 8, let next = n.userInfo[NSUnderlyingErrorKey] as? NSError {
            out.append(next)
            cur = next
            guardDepth += 1
        }
        return out
    }

    /// Returns localization key for branded secure-transport copy, or nil.
    private static func secureTransportMappedKey(for error: Error) -> String? {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("tls") || lower.contains("ssl") || lower.contains("certificate")
            || lower.contains("handshake") || lower.contains("server trust")
        {
            return "We couldn't complete a secure connection. Please try again shortly."
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired:
                return "We couldn't complete a secure connection. Please try again shortly."
            default:
                break
            }
        }
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return nil }
        switch ns.code {
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateNotYetValid,
             NSURLErrorClientCertificateRejected, NSURLErrorClientCertificateRequired:
            return "We couldn't complete a secure connection. Please try again shortly."
        default:
            return nil
        }
    }
}
