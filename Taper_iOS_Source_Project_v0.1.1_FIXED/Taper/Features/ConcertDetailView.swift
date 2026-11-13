import SwiftUI

struct ConcertDetailView: View {
    let id: String
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var playback: PlaybackCoordinator
    @EnvironmentObject private var downloads: DownloadCoordinator
    @State private var concert: Concert?
    @State private var errorText: String?
    @State private var codec: AudioCodec = .mp3
    @State private var showDownloadConfirm = false
    var body: some View {
        Group {
            if let concert {
                List {
                    Section {
                        PosterView(artist: concert.artist, date: concert.performanceDate, venue: concert.venue)
                            .frame(maxWidth: 300).frame(maxWidth: .infinity)
                        Text(concert.artist).font(.title.bold())
                        Text(concert.title).font(.headline).foregroundStyle(.secondary)
                        if !concert.subtitle.isEmpty { Text(concert.subtitle).font(.subheadline) }
                        HStack {
                            Button { playback.start(concert, codec: codec) } label: { Label("Play show", systemImage: "play.fill") }
                                .buttonStyle(.borderedProminent)
                            Button { library.toggle(concert.id) } label: {
                                Label("Save", systemImage: library.favorites.contains(concert.id) ? "heart.fill" : "heart")
                            }.buttonStyle(.bordered)
                        }
                        Picker("Format", selection: $codec) { ForEach(AudioCodec.allCases) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented)
                        if concert.downloadable {
                            Button { showDownloadConfirm = true } label: { Label("Download show (\(codec.rawValue))", systemImage: "arrow.down.circle") }
                        }
                    }
                    Section("Tracks · \(concert.tracks.count)") {
                        ForEach(Array(concert.tracks.enumerated()), id: \.element.id) { index, track in
                            HStack {
                                Button { playback.start(concert, at: index, codec: codec) } label: {
                                    VStack(alignment: .leading) {
                                        Text("\(track.sequence). \(track.title)").font(.subheadline).foregroundStyle(.primary)
                                        Text(track.variants.map(\.codec.rawValue).joined(separator: " / ")).font(.caption).foregroundStyle(.secondary)
                                    }
                                }.buttonStyle(.plain)
                                Spacer()
                                if concert.downloadable && track.variants.contains(where: { $0.codec == codec }) {
                                    Button { downloads.download(concert, track: track, codec: codec) } label: {
                                        Image(systemName: "arrow.down.circle")
                                    }.accessibilityLabel("Download \(track.title)")
                                }
                            }
                        }
                    }
                    Section("Recording notes") {
                        if let taper = concert.taper { LabeledContent("Taper", value: taper) }
                        if let source = concert.source { Text(source).font(.footnote) }
                        if let rights = concert.rights { Text(rights).font(.footnote) }
                        Link("Original recording on Internet Archive", destination: concert.archiveURL)
                        Text("Artist permissions and recording-specific restrictions still apply.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .confirmationDialog("Save all available \(codec.rawValue) tracks?", isPresented: $showDownloadConfirm) {
                    Button("Download") { downloads.downloadShow(concert, codec: codec) }
                }
            } else if let errorText {
                ContentUnavailableView("Recording unavailable", systemImage: "wifi.exclamationmark", description: Text(errorText))
            } else { ProgressView("Loading recording…") }
        }
        .navigationTitle("Concert")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { codec = library.preferredCodec }
        .task(id: id) {
            if let cached = library.cached[id] { concert = cached }
            do { let fetched = try await InternetArchiveSource().recording(id: id); concert = fetched; library.put(fetched) }
            catch { if concert == nil { errorText = error.localizedDescription } }
        }
    }
}

struct NowPlayingView: View {
    @EnvironmentObject private var player: PlaybackCoordinator
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let concert = player.concert {
                    PosterView(artist: concert.artist, date: concert.performanceDate, venue: concert.venue)
                        .frame(maxWidth: 320)
                    VStack(spacing: 5) {
                        Text(player.track?.title ?? "").font(.title2.bold()).lineLimit(2)
                        Text(concert.artist).foregroundStyle(.secondary)
                        Text(player.activeCodec.rawValue + " · Internet Archive").font(.caption).foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }),
                           in: 0...max(1, player.duration))
                    HStack {
                        Text(time(player.position)); Spacer(); Text(time(player.duration))
                    }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    HStack(spacing: 42) {
                        Button { player.previous() } label: { Image(systemName: "backward.end.fill").font(.title) }
                        Button { player.toggle() } label: {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 70))
                        }
                        Button { player.next() } label: { Image(systemName: "forward.end.fill").font(.title) }
                    }.buttonStyle(.plain)
                    if let error = player.error { Text(error).foregroundStyle(.orange).font(.footnote) }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return "\(Int(seconds) / 60):\(String(format: "%02d", Int(seconds) % 60))"
    }
}
