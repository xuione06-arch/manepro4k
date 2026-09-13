import SwiftUI

/// MOVIES / TV SERIES: kategori chips + kërkim + posterë (më të rejat në fillim).
struct LibraryView: View {
    enum Mode { case movies, series }

    let mode: Mode
    @EnvironmentObject var store: AppStore
    @State private var cat = "__all__"
    @State private var query = ""

    var body: some View {
        VStack(spacing: 8) {
            TextField(mode == .movies ? "Kërko filma…" : "Kërko seriale…", text: $query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("__all__", "Të gjitha")
                    ForEach(cats) { c in
                        chip(c.id, c.name)
                    }
                }
                .padding(.horizontal, 12)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 12) {
                    if mode == .movies {
                        ForEach(filteredVod) { v in
                            NavigationLink {
                                PlayerView(kind: .movie(v))
                            } label: {
                                poster(v.name, v.icon)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ForEach(filteredSeries) { s in
                            NavigationLink {
                                SeriesDetailView(series: s)
                            } label: {
                                poster(s.name, s.cover)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle(mode == .movies ? "MOVIES" : "TV SERIES")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.vod.isEmpty && store.series.isEmpty { await load() }
        }
    }

    private var cats: [Category] { mode == .movies ? store.vodCats : store.serCats }

    @MainActor private func load() async {
        guard let line = store.line else { return }
        let api = XtreamApi(base: store.streamBase(), user: line.username, pass: line.password)
        if let l = try? await api.loadAll() { store.applyLists(l) }
    }

    private var filteredVod: [VodItem] {
        var l = cat == "__all__" ? store.vod : store.vod.filter { $0.category == cat }
        if !query.isEmpty {
            let q = query.lowercased()
            l = l.filter { $0.name.lowercased().contains(q) }
        }
        return l
    }

    private var filteredSeries: [SeriesItem] {
        var l = cat == "__all__" ? store.series : store.series.filter { $0.category == cat }
        if !query.isEmpty {
            let q = query.lowercased()
            l = l.filter { $0.name.lowercased().contains(q) }
        }
        return l
    }

    private func chip(_ id: String, _ name: String) -> some View {
        Button {
            cat = id
        } label: {
            Text(name)
                .font(.caption.bold())
                .foregroundColor(cat == id ? .brand : .txt2)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(cat == id ? Color.card2 : Color.card)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func poster(_ name: String, _ icon: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Group {
                if let s = icon, !s.isEmpty, let u = URL(string: s) {
                    AsyncImage(url: u) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        placeholderIcon
                    }
                } else {
                    placeholderIcon
                }
            }
            .frame(height: 158)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(10)

            Text(name)
                .font(.caption2.bold())
                .foregroundColor(.lav)
                .lineLimit(2)
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            Color.card2
            Image(systemName: mode == .movies ? "film" : "tv")
                .font(.title2)
                .foregroundColor(.brand)
        }
    }
}

/// Detajet e serialit: episodat e çdo sezoni.
struct SeriesDetailView: View {
    let series: SeriesItem
    @EnvironmentObject var store: AppStore

    struct Season: Identifiable {
        let num: Int
        let episodes: [Episode]
        var id: Int { num }
    }

    @State private var seasons: [Season] = []

    var body: some View {
        List {
            ForEach(seasons) { s in
                Section(header: Text("Sezoni \(s.num)")) {
                    ForEach(s.episodes) { ep in
                        NavigationLink {
                            PlayerView(kind: .episode(ep, title: "\(series.name) — S\(s.num) E\(ep.num)"))
                        } label: {
                            Text("Episodi \(ep.num)")
                                .font(.subheadline.bold())
                        }
                    }
                }
            }
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEpisodes() }
    }

    @MainActor private func loadEpisodes() async {
        guard let line = store.line else { return }
        let api = XtreamApi(base: store.streamBase(), user: line.username, pass: line.password)
        if let info: SeriesInfoResponse = try? await api.get(
            "get_series_info", extra: ["series_id": String(series.id)]) {
            let eps = info.episodes ?? [:]
            seasons = eps.keys.compactMap { Int($0) }
                .sorted()
                .map { Season(num: $0, episodes: (eps[String($0)] ?? []).sorted { $0.num < $1.num }) }
        }
    }
}
