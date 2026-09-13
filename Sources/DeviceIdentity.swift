import Foundation
import Security

/// MAC + token i pajisjes — ruhen në Keychain, ndaj MBETEN edhe pasi
/// aplikacioni të fshihet (maqur Android, ku MAC-ja është "stable").
struct DeviceIdentity {
    static let macKey = "mane.mac"
    static let tokenKey = "mane.token"

    static func macAddress() -> String {
        if let m = read(macKey) { return m }
        let r = { String(format: "%02X", Int.random(in: 0...255)) }
        let m = "02:4D:41:4E:\(r()):\(r())"
        write(macKey, m)
        return m
    }

    static func deviceToken() -> String {
        if let t = read(tokenKey) { return t }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        let t = bytes.map { String(format: "%02x", $0) }.joined()
        write(tokenKey, t)
        return t
    }

    private static func read(_ key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var r: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let data = r as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ key: String, _ val: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(q as CFDictionary)
        let a: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(val.utf8)
        ]
        SecItemAdd(a as CFDictionary, nil)
    }
}
