import FirebaseMessaging
import UIKit

/// Firebase `Messaging.token()` requires an APNs device token first (`Messaging.apnsToken`).
/// On launch and simulator, `token()` is often called too early → "No APNS token specified…".
/// This helper waits and retries instead of treating that as a fatal error.
enum PreluraFCMRegistration {
    private static let retryDelay: TimeInterval = 0.35
    private static let maxAttempts = 15

    /// Resolves the current FCM registration token after APNs is ready (or fails after retries).
    static func fetchRegistrationToken(
        attempt: Int = 0,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        if Messaging.messaging().apnsToken == nil {
            UIApplication.shared.registerForRemoteNotifications()
            guard attempt < maxAttempts else {
                completion(.failure(Self.apnsTimeoutError))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                fetchRegistrationToken(attempt: attempt + 1, completion: completion)
            }
            return
        }

        Messaging.messaging().token { token, error in
            if let error {
                if Self.isApnsNotReady(error), attempt < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        fetchRegistrationToken(attempt: attempt + 1, completion: completion)
                    }
                    return
                }
                completion(.failure(error))
                return
            }
            guard let token, !token.isEmpty else {
                completion(.failure(Self.emptyTokenError))
                return
            }
            completion(.success(token))
        }
    }

    private static var apnsTimeoutError: NSError {
        NSError(
            domain: "PreluraFCM",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "APNs device token not received in time — try a physical device or check Push capability."]
        )
    }

    private static var emptyTokenError: NSError {
        NSError(domain: "PreluraFCM", code: 2, userInfo: [NSLocalizedDescriptionKey: "FCM returned an empty token"])
    }

    private static func isApnsNotReady(_ error: Error) -> Bool {
        let s = error.localizedDescription.lowercased()
        return s.contains("apns") && s.contains("token")
    }
}
