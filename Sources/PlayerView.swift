import SwiftUI
import AVKit

/// Player: HLS (m3u8) me rezervë URL-në "bare" brenda 14s + zapping para/pas.
struct PlayerView: View {
    enum Kind {
        case live(channel: LiveChannel, list: [LiveChannel])
        case movie(VodItem)
        case episode(Episode, title: String)
    }

    let kind: Kind
    @EnvironmentObject var store: AppStore

    @State private var player = AVPlayer()
    @State private var urls: [String] = []
    @State private var tryIdx = 0
    @State private var failed = false
    @State private var timer: Timer?
    @State private var curId = 0
    @State private var curName = ""
    @State private var liveList: [LiveChannel] = []

    private var isLive: Bool {
        if case .live = kind { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if isLive {
                    Button { zap(-1) } label: {
                        Label("PARA", systemImage: "backward.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.brand)

                    Button { zap(1) } label: {
                        Label("PAS", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.brand)
                }
                Text(curName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundColor(.lav)
                Spacer()
            }
            .padding(8)

            ZStack {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
                if failed {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.pink)
                        Text("Kanali nuk po hapet.\nProvo një kanal tjetër ose kontrollo VPN-në.")
                            .font(.subheadline)
                            .foregroundColor(.txt2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(curName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { start() }
        .onDisappear {
            timer?.invalidate()
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    private func start() {
        switch kind {
        case .live(let ch, let list):
            liveList = list
            curId = ch.id
            curName = ch.name
            urls = store.liveUrls(id: ch.id)
        case .movie(let v):
            curName = v.name
            urls = [store.movieUrl(v)]
        case .episode(_, let t):
            curName = t
            urls = [store.episodeUrl(kindEpisode)]
        }
        tryIdx = 0
        failed = false
        play()
    }

    private var kindEpisode: Episode {
        if case .episode(let e, _) = kind { return e }
        return Episode(id: 0, num: 0, title: "", ext: "mp4")
    }

    private func play() {
        timer?.invalidate()
        guard tryIdx < urls.count else {
            failed = true
            return
        }
        guard let u = URL(string: urls[tryIdx]) else {
            tryIdx += 1
            play()
            return
        }
        player.replaceCurrentItem(with: AVPlayerItem(url: u))
        player.play()
        timer = Timer.scheduledTimer(withTimeInterval: 14, repeats: false) { _ in
            if player.timeControlStatus != .playing {
                tryIdx += 1
                play()
            }
        }
    }

    /// Kalimi në kanalin para/pas (auto-zap si në Android).
    private func zap(_ dir: Int) {
        guard !liveList.isEmpty,
              let idx = liveList.firstIndex(where: { $0.id == curId }) else { return }
        let n = idx + dir
        guard n >= 0, n < liveList.count else { return }
        let ch = liveList[n]
        curId = ch.id
        curName = ch.name
        urls = store.liveUrls(id: ch.id)
        tryIdx = 0
        failed = false
        play()
    }
}
