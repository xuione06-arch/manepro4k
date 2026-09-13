import Foundation
import UIKit

/// MANE IPTV Activation Panel — api/device.php (identike me Android v1.9.0).
struct PanelApi {
    static let url = URL(string: "https://apkim.uk/mane-panel/api/device.php")!

    static func check() async -> PanelResponse? {
        let deviceName = await MainActor.run {
            let n = UIDevice.current.name
            return n.isEmpty ? UIDevice.current.model : n
        }

        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "mac": DeviceIdentity.macAddress(),
            "device_token": DeviceIdentity.deviceToken(),
            "device_name": deviceName,
            "app_version": "1.9.0"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // 2 prova si në Android
        for _ in 0..<2 {
            if let (data, _) = try? await URLSession.shared.data(for: req),
               let r = try? JSONDecoder().decode(PanelResponse.self, from: data) {
                return r
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        return nil
    }

    /// Lejohet vetëm "active" me linjë të plotë (si Android).
    static func allowed(_ r: PanelResponse) -> Bool {
        guard r.status == "active", let l = r.line else { return false }
        return !l.server.isEmpty && !l.username.isEmpty
    }

    /// Roja: kthen true kur pajisja duhet bllokuar (fshirë/skaduar në panel)
    /// dhe e pastron gjendjen lokale. Paneli i paarritshëm NUK bllokon.
    @MainActor
    static func enforce(store: AppStore) async -> Bool {
        guard store.line != nil, let r = await check() else { return false }
        if allowed(r) {
            if r.line != store.line { store.saveLine(r.line!) }
            return false
        }
        store.wipe()
        return true
    }
}
