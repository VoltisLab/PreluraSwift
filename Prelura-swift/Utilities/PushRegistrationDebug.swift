import Foundation

/// Persists last push registration outcome for Menu → Debug → Push diagnostics (visible in TestFlight too).
enum PushRegistrationDebug {
    static let uploadSummaryKey = "prelura_push_upload_summary"
    static let uploadDetailKey = "prelura_push_upload_detail"
    static let uploadTimestampKey = "prelura_push_upload_timestamp"

    static func recordUploadSuccess() {
        let df = ISO8601DateFormatter()
        UserDefaults.standard.set("OK — token sent to API", forKey: uploadSummaryKey)
        UserDefaults.standard.set("", forKey: uploadDetailKey)
        UserDefaults.standard.set(df.string(from: Date()), forKey: uploadTimestampKey)
    }

    static func recordUploadFailure(_ detail: String) {
        let df = ISO8601DateFormatter()
        UserDefaults.standard.set("Failed — see detail", forKey: uploadSummaryKey)
        UserDefaults.standard.set(detail, forKey: uploadDetailKey)
        UserDefaults.standard.set(df.string(from: Date()), forKey: uploadTimestampKey)
        // Always print so device logs help without opening Debug.
        print("[Push] updateProfile(fcmToken:) failed — \(detail)")
    }
}
