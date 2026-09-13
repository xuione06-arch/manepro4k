import Foundation

/// Xtream / XUI One — player_api (logjika e bazës si në Android v1.8.x):
/// kandidatët me https në krye (iOS kërkon TLS), pastaj origjinalja.
struct XtreamApi {
    let base: String
    let user: String
    let pass: String

    struct Lists {
        var liveCats: [Category] = []
        var live: [LiveChannel] = []
        var vodCats: [Category] = []
        var vod: [VodItem] = []
        var serCats: [Category] = []
        var series: [SeriesItem] = []
    }

    static func candidates(for server: String) -> [String] {
        let raw = server.trimmingCharacters(in: CharacterSet(charactersIn: "/ \n"))
        guard !raw.isEmpty else { return [] }
        var out = [raw]
        if raw.hasPrefix("http://") {
            let hp = String(raw.dropFirst(7))
            out.insert("https://" + hp, at: 0)
            if hp.contains(":8080") {
                out.append("https://" + hp.replacingOccurrences(of: ":8080", with: ":8443"))
            }
        }
        return out
    }

    static func login(server: String, user: String, pass: String) async throws -> (LoginResponse, String) {
        var last: Error = URLError(.badURL)
        for b in candidates(for: server) {
            do {
                let api = XtreamApi(base: b, user: user, pass: pass)
                let r: LoginResponse = try await api.get("")
                guard r.user_info?.auth == true else { throw URLError(.userAuthenticationRequired) }
                return (r, b)
            } catch {
                last = error
            }
        }
        throw last
    }

    func get<T: Decodable>(_ action: String, extra: [String: String] = [:]) async throws -> T {
        var comp = URLComponents(string: base + "/player_api.php")!
        var items = [
            URLQueryItem(name: "username", value: user),
            URLQueryItem(name: "password", value: pass)
        ]
        if !action.isEmpty { items.append(URLQueryItem(name: "action", value: action)) }
        for (k, v) in extra { items.append(URLQueryItem(name: k, value: v)) }
        comp.queryItems = items

        var req = URLRequest(url: comp.url!, timeoutInterval: 30)
        req.setValue("VLC/3.0.20 Vetinari", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// I ngarkon të gjitha listat; toleron dështime pjesore (si Android).
    func loadAll() async throws -> Lists {
        var l = Lists()
        let lc: [Category]?    = try? await get("get_live_categories")
        let ls: [LiveChannel]? = try? await get("get_live_streams")
        let vc: [Category]?    = try? await get("get_vod_categories")
        let vs: [VodItem]?     = try? await get("get_vod_streams")
        let sc: [Category]?    = try? await get("get_series_categories")
        let ss: [SeriesItem]?  = try? await get("get_series")

        l.liveCats = lc ?? []
        l.live = ls ?? []
        l.vodCats = vc ?? []
        l.vod = vs ?? []
        l.serCats = sc ?? []
        l.series = ss ?? []

        if l.live.isEmpty && l.vod.isEmpty && l.series.isEmpty {
            throw URLError(.cannotParseResponse)
        }
        return l
    }
}
