// language: Swift, file: AdminServer.swift, target: iOS 15+
// безсерверная версия — только локальные операции

import Foundation
import LocalAuthentication
import Security
import UIKit

final class AdminServer {
    static let shared = AdminServer()

    private let adminTokenKey = "ipa.admin.token"

    func handle(action: String, completion: @escaping ([String: Any]) -> Void) {
        switch action {
        case "OpenPanel":
            authenticate { ok in
                completion([
                    "admin": ok,
                    "token": ok ? (self.loadToken() ?? "local") : ""
                ])
            }
        case "Wipe":
            clearToken()
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

    private func clearToken() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: adminTokenKey
        ]
        SecItemDelete(q as CFDictionary)
    }
}
