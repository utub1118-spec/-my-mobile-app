// language: Swift, file: LocalVault.swift, target: iOS 15+
// безсерверное хранилище: AES-GCM, ключ в Keychain под биометрией,
// всё лежит в Documents/.vault.dat, доступ только через LAContext

import Foundation
import CryptoKit
import LocalAuthentication
import UIKit

final class LocalVault {
    static let shared = LocalVault()

    private let keyTag = "ipa.vault.key"
    private let vaultName = ".vault.dat"
    private let lockQueue = DispatchQueue(label: "ipa.vault.queue")

    private var vaultURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(vaultName)
    }

    // MARK: - Публичный интерфейс

    /// Сохранить запись (feature + payload). Вызывается из ViewController без биометрии — данные пишутся фоном.
    func store(feature: String, payload: [String: Any], completion: ((Bool) -> Void)? = nil) {
        lockQueue.async {
            var all = self.readRaw() ?? []
            all.append([
                "ts": Int(Date().timeIntervalSince1970),
                "feature": feature,
                "payload": payload
            ])
            let ok = self.writeRaw(all)
            DispatchQueue.main.async { completion?(ok) }
        }
    }

    /// Прочитать всё — требует Face ID.
    func readAll(completion: @escaping ([[String: Any]]?) -> Void) {
        authenticate { ok in
            guard ok else { completion(nil); return }
            self.lockQueue.async {
                let all = self.readRaw()
                DispatchQueue.main.async { completion(all) }
            }
        }
    }

    /// Экспорт в Documents/export.json (открытый файл для вытаскивания по кабелю).
    func exportToDocuments(completion: @escaping (URL?) -> Void) {
        authenticate { ok in
            guard ok else { completion(nil); return }
            self.lockQueue.async {
                guard let all = self.readRaw() else { completion(nil); return }
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let out = docs.appendingPathComponent("export.json")
                do {
                    let data = try JSONSerialization.data(withJSONObject: all, options: [.prettyPrinted])
                    try data.write(to: out, options: .atomic)
                    DispatchQueue.main.async { completion(out) }
                } catch {
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        }
    }

    /// Стереть всё.
    func wipe() {
        lockQueue.async {
            try? FileManager.default.removeItem(at: self.vaultURL)
            self.deleteKey()
        }
    }

    // MARK: - Биометрия

    private func authenticate(_ cb: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        ctx.localizedReason = "Доступ к собранным данным"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            cb(false); return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Доступ к собранным данным") { ok, _ in
            cb(ok)
        }
    }

    // MARK: - Ключ AES-GCM в Keychain

    private func loadOrCreateKey() -> SymmetricKey? {
        if let existing = loadKey() { return existing }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccessControl as String: secAccessControl()
        ]
        SecItemDelete(q as CFDictionary)
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { return nil }
        return key
    }

    private func loadKey() -> SymmetricKey? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: LAContext()
        ]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let d = r as? Data else { return nil }
        return SymmetricKey(data: d)
    }

    private func deleteKey() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag
        ]
        SecItemDelete(q as CFDictionary)
    }

    private func secAccessControl() -> SecAccessControl? {
        return SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )
    }

    // MARK: - Чтение/запись зашифрованного файла

    private func readRaw() -> [[String: Any]]? {
        guard FileManager.default.fileExists(atPath: vaultURL.path),
              let blob = try? Data(contentsOf: vaultURL),
              let key = loadOrCreateKey() else { return [] }

        guard let box = try? AES.GCM.SealedBox(combined: blob),
              let plain = try? AES.GCM.open(box, using: key) else { return [] }

        return (try? JSONSerialization.jsonObject(with: plain)) as? [[String: Any]] ?? []
    }

    private func writeRaw(_ array: [[String: Any]]) -> Bool {
        guard let key = loadOrCreateKey(),
              let plain = try? JSONSerialization.data(withJSONObject: array),
              let box = try? AES.GCM.seal(plain, using: key),
              let combined = box.combined else { return false }
        do {
            try combined.write(to: vaultURL, options: [.atomic, .completeFileProtection])
            return true
        } catch {
            return false
        }
    }
}
