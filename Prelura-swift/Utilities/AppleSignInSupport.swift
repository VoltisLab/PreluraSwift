import CryptoKit
import Foundation

enum AppleSignInSupport {
    /// Raw nonce (send to your backend) and SHA256 hex string (set on `ASAuthorizationAppleIDRequest.nonce`).
    static func makeNoncePair() -> (raw: String, hashed: String) {
        let raw = UUID().uuidString + "-" + UUID().uuidString
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hashed = digest.map { String(format: "%02x", $0) }.joined()
        return (raw, hashed)
    }
}
