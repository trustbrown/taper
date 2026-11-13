# Taper — Live music, kept alive.

**Build-stage source project** · Free iPhone app, no accounts, ads, paywall, subscriptions, Plex, or personal server.

## Open on your Mac

1. Install Xcode with the iOS 26 SDK (or adjust deployment target to an SDK you actually have).
2. Open **Taper.xcodeproj** and select the **Taper** target.
3. In **Signing & Capabilities**, choose your Apple Developer Team and replace `org.tapercommunity.Taper` with a unique bundle identifier.
4. Build and run on an iPhone. Enable automatic signing. The project includes the supplied 1024px light/dark/tinted icon assets.
5. Test network requests and playback with a real Archive recording, then test background audio and download recovery on a physical iPhone.

The project is also described in `project.yml` for regeneration using XcodeGen, but **the `.xcodeproj` is already included**. No third-party dependencies or private credentials are required for this baseline.

## Implemented source files

- Native SwiftUI app with Discover, live Search, recording detail, mini-player, Now Playing, Saved, Offline, Settings.
- Internet Archive Advanced Search and metadata requests, with provider protocol and recorded-source attribution.
- Per-upload recording identities, MP3/FLAC format selection, track grouping, source links and show metadata.
- AVPlayer playback, lock-screen metadata, system transport commands, seek, next, previous, resume positions.
- Background `URLSession` track/show transfers, local audio preference for downloaded tracks, on-disk manifest, size verification, retry and deletion.
- Persisted favorites, recent shows, local cached concerts, deterministic vintage show posters, On This Day best-effort query.

## Important limitations — not release ready

- **This environment cannot run Xcode or an iPhone simulator.** Swift files were parsed with Swift on Linux; Archive networking and decoding code were also typechecked. This is not proof of an iOS build or real-device playback.
- **FLAC streaming and FLAC offline decoding are not validated.** AVPlayer may reject some FLAC recordings. A proper tested FLAC backend with bounded buffering and seeking is still required to deliver the original FLAC product requirement.
- **Background transfer app-relaunch handoff needs device testing and AppDelegate completion handling** for reliable iOS re-launch processing. Some failed downloads may need user retries.
- The transfer manifest is JSON, not yet the planned SQLite store. Search uses cached JSON, not a large indexed SQLite catalog. This initial functional skeleton should be migrated to SQLite before scaling.
- Download integrity currently checks sizes where available, not SHA/MD5. Pausing/resuming partial downloads and accurate completion of whole shows need further work.
- Download access reflects Archive item/file availability, but **per-artist and per-recording policy review is still required** before App Store release. An archive's public URL does not supersede rights restrictions.
- Artwork currently uses locally generated deterministic posters; licensed show-specific and artist artwork integrations are not enabled.
- MusicBrainz, fanart.tv, setlist.fm and other recording providers are intentionally not activated until provider access/licensing is verified.
- Playlist/source grouping, detailed source comparisons, accessibility audits, Bluetooth/AirPlay route tests, privacy disclosures and automated iOS integration tests remain pending.
- On This Day is best-effort against archive date search and may produce no results.

## Next gates

1. Complete `API_ACCESS_CHECKLIST.md` with provider contact, rights, artist restrictions, and App Store Team details.
2. Run iOS compile, resolve any SDK-specific issues, and test Archive response variants and malformed fields.
3. Implement and test a robust FLAC network/local decoder and streaming queue.
4. Add robust background transfer reattachment, resume data, SQLite migration and per-file verification.
5. Complete artwork licensing, accessibility and App Store review checklist.

**License:** no license was granted or included. Copyright remains with the authors until a source-available/noncommercial license is chosen after review. Live recordings and artwork remain under their own owners' rights.

## v0.1.1 project-file repair

The previous v0.1 archive contained malformed OpenStep project syntax (missing semicolons after selected dictionary fields). v0.1.1 regenerates `Taper.xcodeproj/project.pbxproj` with valid terminators. `plutil -lint` passes, and all referenced project objects are present. This repairs the **project-opening** failure; compilation on macOS/Xcode still needs to be checked.
