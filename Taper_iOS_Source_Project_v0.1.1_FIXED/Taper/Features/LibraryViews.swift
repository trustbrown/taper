import SwiftUI

struct SavedView: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        List {
            Section("Favorite recordings") {
                ForEach(library.cached.values.filter { library.favorites.contains($0.id) }.sorted { $0.title < $1.title }) { concert in
                    NavigationLink(value: concert.id) { ConcertRow(concert: concert) }
                }
                if library.favorites.isEmpty { Text("Save a show to find it here.").foregroundStyle(.secondary) }
            }
            Section("Recently played") {
                ForEach(library.history, id: \.self) { id in
                    if let concert = library.cached[id] { NavigationLink(value: id) { ConcertRow(concert: concert) } }
                }
            }
        }
        .navigationTitle("Saved")
        .navigationDestination(for: String.self) { ConcertDetailView(id: $0) }
    }
}

struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadCoordinator
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        List {
            Section {
                LabeledContent("Stored audio", value: ByteCountFormatter.string(fromByteCount: downloads.storedBytes, countStyle: .file))
                Text("Offline audio is kept on this iPhone until you delete it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Tracks") {
                ForEach(downloads.entries.values.sorted { $0.concertTitle < $1.concertTitle }) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.trackTitle).font(.headline)
                        Text("\(entry.artist) · \(entry.concertTitle)").font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Text("\(entry.codec.rawValue) · \(entry.state.capitalized)").font(.caption)
                            Spacer()
                            if entry.state == "running", let p = downloads.progress[entry.id] { ProgressView(value: p).frame(width: 100) }
                            if entry.state == "failed", let concert = library.cached[entry.concertID] {
                                Button("Retry") { downloads.retry(entry, concert: concert) }
                            }
                            Button(role: .destructive) { downloads.delete(entry.id) } label: { Image(systemName: "trash") }
                        }
                        if let error = entry.error { Text(error).font(.caption).foregroundStyle(.orange) }
                    }.padding(.vertical, 4)
                }
                if downloads.entries.isEmpty { Text("Downloaded shows will appear here.").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Offline")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var downloads: DownloadCoordinator
    var body: some View {
        Form {
            Section("Playback") {
                Picker("Preferred format", selection: $library.preferredCodec) {
                    ForEach(AudioCodec.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("MP3 has broad streaming compatibility. FLAC playback depends on device and file compatibility; downloaded FLAC files are not automatically guaranteed to decode.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Downloads") {
                Toggle("Wi-Fi only downloads", isOn: $library.wifiOnly)
                    .onChange(of: library.wifiOnly) { _, newValue in downloads.wifiOnly = newValue }
                Text("The preference applies to new transfers; existing transfers retain their original network policy.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                Text("Taper · Live music, kept alive.")
                Text("Made for the music. Given to the community.")
                Text("Recordings are supplied by their respective archive and artists. Please respect each artist’s trading policy.")
                    .font(.footnote)
                Link("Internet Archive Live Music Archive", destination: URL(string: "https://archive.org/details/etree")!)
                Link("Archive artist permissions", destination: URL(string: "https://archivesupport.zendesk.com/hc/en-us/articles/360016553532-Live-Music-Archive-etree-org")!)
            }
        }
        .navigationTitle("Settings")
    }
}
