# CapsLog

CapsLog is a native iOS 26 client for a self-hosted
[SilverBullet](https://silverbullet.md) space.

## Included in v1

- Trawl-style first-launch onboarding and guided server setup
- Bearer-token authentication using `SB_AUTH_TOKEN`
- Markdown page listing and path filtering
- Read-first Markdown notes rendered with Textual
- Notes-style title extraction with frontmatter hidden from presentation
- Native internal navigation for SilverBullet page links
- Authenticated inline image loading for SilverBullet attachments
- Raw-Markdown editing with smart punctuation disabled
- Expandable Liquid Glass Markdown keyboard toolbar
- Autosave and explicit save
- Last-modified conflict detection
- SwiftData-backed offline page and listing cache
- Queued offline writes retried after reconnecting
- Keychain storage for the auth token
- Support for HTTP servers on the local network

## SilverBullet API

CapsLog uses the SilverBullet v2 HTTP API:

- `GET /.ping`
- `GET /.config`
- `GET /.fs`
- `GET /.fs/<path>`
- `PUT /.fs/<path>`
- `DELETE /.fs/<path>`

Every API request includes `X-Sync-Mode: true`. File metadata is read from
`X-Last-Modified`, `X-Created`, `X-Permission`, and `X-Content-Length`.

## Setup

1. Run SilverBullet with a token, for example `SB_AUTH_TOKEN=<token>`.
2. Build and run CapsLog from `CapsLog.xcodeproj`.
3. Enter the server URL, including any port or `SB_URL_PREFIX`.
4. Enter the matching bearer token and tap **Connect**.

The target uses Swift 6, strict concurrency, SwiftUI Observation, and SwiftData.
Markdown presentation uses
[Textual](https://github.com/gonzalezreal/textual), pinned through Swift Package
Manager.
