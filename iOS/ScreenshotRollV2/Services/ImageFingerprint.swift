import CryptoKit
import Foundation

enum ImageFingerprint {
    static func exactHashHex(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
