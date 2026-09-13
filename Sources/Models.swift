import Foundation

// MARK: - Paneli i aktivizimit (apkim.uk/mane-panel/api/device.php)
struct PanelResponse: Codable {
    let ok: Bool?
    let status: String?
    let message: String?
    let line: PanelLine?
}

struct PanelLine: Codable, Equatable {
    let server: String
    let username: String
    let password: String
}

// MARK: - Xtream / XUI One
struct LoginResponse: Codable {
    let user_info: UserInfo?
}

struct UserInfo: Codable {
    let username: String?
    let status: String?
    let auth: Bool?
    let exp_date: String?
    let max_connections: String?
    let active_cons: String?

    enum CodingKeys: String, CodingKey {
        case username, status, auth, exp_date, max_connections, active_cons
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        username = c.flexString(.username)
        status = c.flexString(.status)
        auth = c.flexBool(.auth)
        exp_date = c.flexString(.exp_date)
        max_connections = c.flexString(.max_connections)
        active_cons = c.flexString(.active_cons)
    }

    var expiryTs: Double? {
        guard let s = exp_date, let t = Double(s), t > 0 else { return nil }
        return t
    }

    var expiryText: String {
        guard let ts = expiryTs else { return "Unlimited" }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: Date(timeIntervalSince1970: ts))
    }
}

// MARK: - Modelet e listave (dekodim fleksibël String/Int si në Android)
struct Category: Identifiable, Equatable, Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey { case category_id, category_name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.category_id) ?? ""
        name = c.flexString(.category_name) ?? ""
    }
}

struct LiveChannel: Identifiable, Equatable, Decodable {
    let id: Int          // stream_id
    let num: Int
    let name: String
    let icon: String?
    let categories: [String]

    enum CodingKeys: String, CodingKey {
        case num, name, stream_id, stream_icon, category_id, category_ids
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.stream_id) ?? 0
        num = c.flexInt(.num) ?? 0
        name = c.flexString(.name) ?? ""
        icon = c.flexString(.stream_icon)
        if let ids = try? c.decode([Int].self, forKey: .category_ids) {
            categories = ids.map(String.init)
        } else if let ids = try? c.decode([String].self, forKey: .category_ids) {
            categories = ids
        } else if let one = c.flexString(.category_id) {
            categories = [one]
        } else {
            categories = []
        }
    }
}

struct VodItem: Identifiable, Decodable {
    let id: Int          // stream_id
    let name: String
    let icon: String?
    let ext: String
    let category: String
    let added: Double

    enum CodingKeys: String, CodingKey {
        case name, stream_id, stream_icon, container_extension, category_id, added
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.stream_id) ?? 0
        name = c.flexString(.name) ?? ""
        icon = c.flexString(.stream_icon)
        ext = (c.flexString(.container_extension) ?? "mp4").replacingOccurrences(of: ".", with: "")
        category = c.flexString(.category_id) ?? ""
        added = c.flexDouble(.added) ?? 0
    }
}

struct SeriesItem: Identifiable, Decodable {
    let id: Int          // series_id
    let name: String
    let cover: String?
    let category: String
    let added: Double

    enum CodingKeys: String, CodingKey {
        case name, series_id, cover, category_id, added, last_modified
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.series_id) ?? 0
        name = c.flexString(.name) ?? ""
        cover = c.flexString(.cover)
        category = c.flexString(.category_id) ?? ""
        added = c.flexDouble(.added) ?? c.flexDouble(.last_modified) ?? 0
    }
}

struct SeriesInfoResponse: Decodable {
    let episodes: [String: [Episode]]?
}

struct Episode: Identifiable, Decodable {
    let id: Int
    let num: Int
    let title: String
    let ext: String

    enum CodingKeys: String, CodingKey {
        case id, episode_num, title, container_extension
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        num = c.flexInt(.episode_num) ?? 0
        title = c.flexString(.title) ?? "Episod"
        ext = (c.flexString(.container_extension) ?? "mp4").replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - Lexim fleksibël (disa panele dërgojnë numra si tekst dhe anasjelltas)
extension KeyedDecodingContainer {
    func flexString(_ key: Key) -> String? {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let i = try? decode(Int.self, forKey: key) { return String(i) }
        return nil
    }

    func flexInt(_ key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let s = try? decode(String.self, forKey: key) { return Int(s) }
        return nil
    }

    func flexDouble(_ key: Key) -> Double? {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let i = try? decode(Int.self, forKey: key) { return Double(i) }
        if let s = try? decode(String.self, forKey: key) { return Double(s) }
        return nil
    }

    func flexBool(_ key: Key) -> Bool? {
        if let b = try? decode(Bool.self, forKey: key) { return b }
        if let i = try? decode(Int.self, forKey: key) { return i != 0 }
        if let s = try? decode(String.self, forKey: key) { return s == "1" || s == "true" }
        return nil
    }
}

// MARK: - Store qendror (si Repository në Android)
@MainActor
final class AppStore: ObservableObject {
    @Published var line: PanelLine?
    @Published var login: LoginResponse?
    var base: String = ""

    @Published var liveCats: [Category] = []
    @Published var live: [LiveChannel] = []
    @Published var vodCats: [Category] = []
    @Published var vod: [VodItem] = []
    @Published var serCats: [Category] = []
    @Published var series: [SeriesItem] = []

    private let d = UserDefaults.standard

    init() {
        if let data = d.data(forKey: "mane_line"),
           let l = try? JSONDecoder().decode(PanelLine.self, from: data) {
            line = l
        }
        if let data = d.data(forKey: "mane_login"),
           let l = try? JSONDecoder().decode(LoginResponse.self, from: data) {
            login = l
        }
        base = d.string(forKey: "mane_base") ?? line?.server ?? ""
    }

    func saveLine(_ l: PanelLine) {
        line = l
        d.set(try? JSONEncoder().encode(l), forKey: "mane_line")
    }

    func saveLogin(_ l: LoginResponse, base b: String) {
        login = l
        base = b
        d.set(try? JSONEncoder().encode(l), forKey: "mane_login")
        d.set(b, forKey: "mane_base")
    }

    func wipe() {
        line = nil
        login = nil
        base = ""
        liveCats = []; live = []; vodCats = []; vod = []; serCats = []; series = []
        for k in ["mane_line", "mane_login", "mane_base"] {
            d.removeObject(forKey: k)
        }
    }

    func applyLists(_ l: XtreamApi.Lists) {
        liveCats = l.liveCats
        live = l.live
        vodCats = l.vodCats
        vod = l.vod.sorted { $0.added > $1.added }          // më të rejat në fillim
        serCats = l.serCats
        series = l.series.sorted { $0.added > $1.added }    // më të rejat në fillim
    }

    func streamBase() -> String {
        let s = base.isEmpty ? (line?.server ?? "") : base
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Live: provon .m3u8 (HLS) dhe pastaj URL-në "bare" (si në Android ts→hls).
    func liveUrls(id: Int) -> [String] {
        guard let l = line else { return [] }
        let b = streamBase()
        return [
            "\(b)/live/\(l.username)/\(l.password)/\(id).m3u8",
            "\(b)/live/\(l.username)/\(l.password)/\(id)"
        ]
    }

    func movieUrl(_ v: VodItem) -> String {
        guard let l = line else { return "" }
        return "\(streamBase())/movie/\(l.username)/\(l.password)/\(v.id).\(v.ext)"
    }

    func episodeUrl(_ e: Episode) -> String {
        guard let l = line else { return "" }
        return "\(streamBase())/series/\(l.username)/\(l.password)/\(e.id).\(e.ext)"
    }
}
