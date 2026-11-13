import SwiftUI

struct RootView: View {
    @EnvironmentObject private var player: PlaybackCoordinator
    @State private var showPlayer = false
    var body: some View {
        TabView {
            NavigationStack { DiscoverView() }.tabItem { Label("Discover", systemImage: "sparkles.tv") }
            NavigationStack { SearchView() }.tabItem { Label("Search", systemImage: "magnifyingglass") }
            NavigationStack { SavedView() }.tabItem { Label("Saved", systemImage: "heart") }
            NavigationStack { DownloadsView() }.tabItem { Label("Offline", systemImage: "arrow.down.circle") }
            NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let track = player.track {
                Button { showPlayer = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform").font(.title2).foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(track.title).font(.subheadline.bold()).lineLimit(1)
                            Text(player.concert?.artist ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button { player.toggle() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3).padding(9)
                        }.buttonStyle(.plain).accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                    }.padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.regularMaterial)
                }.buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showPlayer) { NowPlayingView() }
    }
}

struct DiscoverView: View {
    @State private var recent: [CatalogHit] = []
    @State private var todays: [CatalogHit] = []
    @State private var loading = false
    @State private var issue: String?
    @EnvironmentObject private var library: LibraryStore
    private let archive = InternetArchiveSource()
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LIVE MUSIC, KEPT ALIVE.").font(.caption.bold()).tracking(2).foregroundStyle(.orange)
                    Text("Every show has a story.").font(.largeTitle.bold())
                    Text("Explore freely shared live recordings, one tape at a time.").foregroundStyle(.secondary)
                }.padding(.vertical, 12)
            }
            if !library.history.isEmpty {
                Section("Continue Listening") {
                    ForEach(library.history.prefix(4), id: \.self) { id in
                        if let concert = library.cached[id] { NavigationLink(value: id) { ConcertRow(concert: concert) } }
                    }
                }
            }
            if !todays.isEmpty { Section("On This Day") { ForEach(todays) { hit in NavigationLink(value: hit.id) { HitRow(hit: hit) } } } }
            Section("Recently added to the Archive") {
                ForEach(recent) { hit in NavigationLink(value: hit.id) { HitRow(hit: hit) } }
                if loading { ProgressView("Loading concerts…") }
                if let issue { Text(issue).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Taper")
        .navigationDestination(for: String.self) { ConcertDetailView(id: $0) }
        .refreshable { await reload() }
        .task { if recent.isEmpty { await reload() } }
    }
    private func reload() async {
        loading = true; defer { loading = false }
        do { recent = try await archive.recent(); issue = nil }
        catch { issue = "Archive unavailable. Cached saved shows remain accessible." }
        let formatter = DateFormatter(); formatter.dateFormat = "MM-dd"
        todays = (try? await archive.onThisDay(monthDay: formatter.string(from: Date()))) ?? []
    }
}

struct SearchView: View {
    @State private var query = ""
    @State private var hits: [CatalogHit] = []
    @State private var errorText: String?
    @State private var searching = false
    @EnvironmentObject private var library: LibraryStore
    private let archive = InternetArchiveSource()
    var body: some View {
        List {
            let local = library.localMatches(query)
            if !local.isEmpty { Section("Cached recordings") { ForEach(local) { concert in NavigationLink(value: concert.id) { ConcertRow(concert: concert) } } } }
            Section("Internet Archive") {
                if searching { ProgressView("Searching…") }
                ForEach(hits.filter { hit in !local.contains(where: { $0.id == hit.id }) }) { hit in
                    NavigationLink(value: hit.id) { HitRow(hit: hit) }
                }
                if let errorText { Text(errorText).foregroundStyle(.secondary) }
                if query.isEmpty { Text("Search artists, venues or concert titles.").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Artist, show, venue")
        .navigationDestination(for: String.self) { ConcertDetailView(id: $0) }
        .task(id: query) {
            guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { hits = []; return }
            do {
                try await Task.sleep(for: .milliseconds(350))
                searching = true; defer { searching = false }
                let result = try await archive.search(query, page: 1)
                try Task.checkCancellation(); hits = result; errorText = nil
            } catch is CancellationError { }
            catch { errorText = error.localizedDescription; hits = [] }
        }
    }
}

struct HitRow: View {
    let hit: CatalogHit
    var body: some View {
        HStack(spacing: 12) {
            PosterView(artist: hit.artist, date: hit.date, venue: hit.venue).frame(width: 66, height: 66)
            VStack(alignment: .leading, spacing: 4) {
                Text(hit.artist).font(.headline).lineLimit(1)
                Text(hit.title).font(.subheadline).lineLimit(2)
                Text(hit.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }.padding(.vertical, 4)
    }
}
struct ConcertRow: View {
    let concert: Concert
    var body: some View {
        HitRow(hit: CatalogHit(id: concert.id, title: concert.title, artist: concert.artist,
                               date: concert.performanceDate, venue: concert.venue))
    }
}
