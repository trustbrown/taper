import SwiftUI

@main struct TaperApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var player = PlaybackCoordinator()
    @StateObject private var downloads = DownloadCoordinator()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(player)
                .environmentObject(downloads)
                .task {
                    player.library = library
                    player.downloads = downloads
                    downloads.wifiOnly = library.wifiOnly
                }
                .tint(.orange)
                .preferredColorScheme(.dark)
        }
    }
}
