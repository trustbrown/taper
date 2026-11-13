# Taper — API, Rights, and Developer Access Tracker

**Reminder: complete before each integration; do not commit secrets to source control.**

| Complete | Service | Status / owner / contact | Credentials or permissions needed | Verified date |
|---|---|---|---|---|
| [ ] | Apple Developer / App Store Connect | TBD | Team ID, Bundle ID, signing, TestFlight | |
| [ ] | Internet Archive Live Music Archive | TBD | Public API, acceptable app use, artists' stream/download rights, attribution | |
| [ ] | MusicBrainz | TBD | Identifying User-Agent and real project contact; throttle to <=1 request/s | |
| [ ] | Fanart.tv | TBD | Taper project API key; caching and app-client restrictions | |
| [ ] | setlist.fm (optional) | TBD | API access key; source-specific terms | |
| [ ] | Other permitted live-show sources | TBD | Formal API access and rights for streaming/downloads where needed | |
| [ ] | Artwork rights | TBD | Photo artwork attribution, caching, transformations | |
| [ ] | App privacy / support web page | TBD | Real public contact URL and support/privacy details | |

## Provider approval record template

- Provider:
- Documentation and terms URLs:
- Contact person/email:
- API credentials required: Yes / No
- Key may appear in distributed iOS client: Explicitly allowed / Not allowed / Unknown
- Search and metadata access: Approved / Unclear / Denied
- Streaming through a third-party free application: Approved / Unclear / Denied
- Offline downloads through application: Approved / Unclear / Denied
- Attribution/display requirements:
- Cache/storage restrictions:
- Request limits and User-Agent rules:
- Approval evidence/location (no secret values):
- Review date:

## Hard-stop rules

- Do not ship a provider with unresolved required permission.
- Public Archive URLs do not automatically convey redistribution rights.
- Do not expose confidential keys in Swift, Info.plist, source bundles, screenshots or README.
- Failing optional metadata/artwork services must not break the core player.
- Obtain an Internet Archive/provider-specific answer if the intended app behavior isn't covered by published documentation.
