# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

TeleCinema is a cross-platform Flutter client for synchronized watch-party rooms (Android / iOS / Web / Windows / macOS / Linux). It is the companion to an AdonisJS backend and speaks the **same Socket.IO realtime protocol as the web client**, so users on any platform share one room. The backend lives outside this repo (its providers are an additional working dir: `../watch-party/providers`).

## Commands

```bash
flutter pub get                 # fetch deps
flutter run                     # run on a connected device/emulator/browser
flutter analyze                 # lint (flutter_lints, see analysis_options.yaml)
flutter test                    # run all tests
flutter test test/widget_test.dart --plain-name 'extrapolates forward'  # single test by name

flutter build apk               # Android (also: appbundle)
flutter build ios | web | windows | macos | linux

dart run flutter_launcher_icons # regenerate platform launcher icons after changing assets/telecinema_icon.png
dart run tool/gen_icon.dart     # regenerate the source icon in assets/icon/
```

There is one Dart test file: `test/widget_test.dart` (domain smoke tests only — the app is **not** widget-tested because `main()` boots HydratedBloc storage + GetIt).

### Critical first-build steps (the app will not compile without these)

1. **`lib/core/config/endpoints.dart` is git-ignored.** It holds the default server URL, catalogue/torrent/subtitle provider endpoints, and the BitTorrent tracker list — deliberately kept out of history. Copy `endpoints.example.dart` → `endpoints.dart` and fill it in before building. This is the single place to bump a rotated scraper mirror host (e.g. TopCinema `web4.` → `web5.`) or refresh the tracker list.
2. **The Rust torrent engine** (`packages/rust/`, a librqbit-backed crate exposed via `flutter_rust_bridge` 2.12.0) builds automatically through `packages/rust_builder` on native targets. The generated Dart lives in `lib/src/rust/` (do not hand-edit — it's `@generated`). Regenerate bindings with `flutter_rust_bridge_codegen generate` only after changing `packages/rust/src/api/*.rs`. No wasm build exists, so the engine is **native-only** — `RustLib.init()` is skipped on web (`main.dart`).

### Versioning gotcha

`pubspec.yaml` `version: X.Y.Z+N` — the `+N` build number is the Android `versionCode` the **in-app updater** (`features/app_update`) compares against the server. It MUST increase on every release published to the admin dashboard, or clients won't detect the update.

## Architecture

**Clean Architecture, feature-first.** Each feature under `lib/features/<name>/` is split into `data/` → `domain/` → `presentation/`, plus an `injections/` file that registers its DI. Cross-cutting infrastructure is in `core/` (config, network, errors, localization, theme, device identity, shared widgets) and `logic/` (app-wide stateful cubits: socket, identity, theme, locale, favorites, storage).

- **State:** BLoC/Cubit (`flutter_bloc`). App-lifetime cubits use `hydrated_bloc` for persisted state (theme, locale, favorites). Page-scoped blocs are `factory`-registered (fresh per page).
- **DI:** `get_it`, accessed everywhere as `sl<T>()`. Composition root is `lib/injections/`: `inject_singletons.dart` (long-lived: storage → socket → device identity → network → per-feature `inject<Feature>Singletons`) and `inject_factories.dart` (per-page blocs). **Order matters** in singletons — storage and the socket come up before `IdentityCubit`; device identity is published before the network layer so the Dio interceptor can stamp every request.
- **Errors are functional.** Datasources throw typed `Exception`s (`core/errors/exceptions.dart`), repositories catch them and return `Either<Failure, T>` via `dartz`, use cases (`core/UseCase/usecase.dart`) pass those through, and the UI branches on success/failure with no try/catch sprawl. `Failure` codes map to localized strings via `core/errors/failure_messages.dart`.
- **Navigation:** single `go_router` (`routes/routers.dart`). The three tabs (Rooms · Browse · Favorites) live in a `StatefulShellRoute` under `MainShell`; create-room, the player, and detail pages push on the root navigator. No auth gate — every room is public; password rooms use an in-page unlock overlay.

### Config: one base URL drives everything

`core/config/app_config.dart` derives the REST API (`/api`), the Socket.IO origin, and all media URLs (`/video`, `/stream`, `/youtube`, `/livetv`, `/thumbnails`, `/subtitles`, `/voice`) from a single mutable `AppConfig.baseUrl`. Users can override the server in Settings; the saved URL is applied in `injectSingletons` **before** the network layer is built. The default comes from `Endpoints.defaultBaseUrl`.

Every REST request carries an `X-Device-Id` header (`DeviceIdHolder` → `core/device/device_identity.dart`), a stable per-install id the server uses to scope long-running operations (downloads/torrents) to this device so they survive socket reconnects (see `features/operations`). There is **no auth token** — `DioApiClient` only does device-id stamping + error mapping.

### The single shared socket

`logic/socket/socket_cubit.dart` is a generic Socket.IO v4 client (one per signed-in user, registered as a singleton). It is domain-agnostic: features bind their own typed event streams onto it via `.on(event)` and emit with `.emitEvent(...)`, tearing bindings down on leave. Its methods are split across `part` files in `logic/socket/handlers/`.

### The watch/sync engine (the core of the app)

`features/watch/presentation/bloc/watch_cubit.dart` (~1400 lines) owns the media_kit (libmpv) `Player` and all realtime state. It consumes room events through `features/watch/data/datasources/watch_socket_datasource.dart`, which exposes typed streams (`sync`, `forceResync`, `chatHistory`, `chat`, `presence`, `waitState`, `sourceChanged`, `reaction`, voice…).

- **Authoritative clock:** the server is the single source of truth for the playhead. `PlaybackSync.effectiveTime()` (`domain/entities/playback_sync.dart`) extrapolates the room's true position from `currentTime + (now - serverTime) * playbackRate`, correcting for network latency.
- **Convergence:** on each `sync`, the client nudges `player.setRate()` for small drift but **hard-seeks** when drift exceeds `AppConstants.hardSeekThresholdSeconds` (1.5s).
- **Buffer wait-gate:** a sustained local stall (debounced `AppConstants.bufferReportDelay`, 1500ms) reports `buffer_state: true`; the server pauses the whole room until every viewer clears, then resumes together.
- **Torrent stall watchdog:** if an on-device torrent stream stalls ~20s, the cubit swaps to the server's `/stream/:slug` copy.
- **Social layer:** chat (optimistic send matched by `clientId`, retried on reconnect), floating emoji reactions (with per-emoji haptics), push-to-talk voice (mobile↔mobile byte relay; web's webm is undecodable on mobile), presence diffing, and typing indicators are all wired through the same socket datasource.
- **External (embed) rooms** have no player: a WebView renders the third-party page and the socket sync drives a *virtual* clock for subtitle timing / forced reloads.

### Room types & content sources

A room's `RoomType` (`features/rooms/domain/entities/room_type.dart`) determines how its video is sourced; `Room.videoUrl` resolves the right stream URL per type:

| Type | Source | Resolved where |
| --- | --- | --- |
| `upload` | file uploaded to the server | — |
| `download` | server fetches a pasted link in the background (client polls progress) | server |
| `torrent` | magnet → on-device librqbit stream, falls back to server `/stream/:slug` | device + server |
| `youtube` | server resolves the watch URL and proxies `/youtube/:slug` (plays like a file room, full seek) | server |
| `telegram` | submitted as a `download` whose URL is a `t.me/...` link; server scrapes the CDN URL | server |
| `tv` | YacineTV HLS relay via `/livetv/:slug`, no seek, token refresh on expiry | server + device |
| `external` | third-party page in a WebView, virtual-clock sync only | — |

**Browsing → room creation.** Each content source is an isolated feature that funnels the user into the universal `features/rooms/presentation/pages/create_room_page.dart`, pre-filling it via `state.extra` (magnet / videoUrl / youtubeUrl / imdbId / thumbnail / category):

- **browse** / **discover** — the unified Browse tab (`DiscoverPage`) merges the Cinemeta (IMDB metadata) and Cinema (EgyBest) catalogues; a title's detail page lists torrent options (from the apibay Pirate-Bay JSON API), classified by quality/season/episode.
- **cinema** — EgyBest catalogue + on-device resolver → `download` room.
- **youtube** — search/quality resolution is **on-device** (`youtube_explode_dart`) inside the Create-Room stream picker; playback is server-proxied.
- **topcinema** — direct-download scraper resolved **on-device** (the client can reach the host; the server is blocked there).
- **iwaatch** — direct-link source resolved **on the server** (`/api/iwaatch/resolve`; iwaatch.com is geo-blocked for clients), movies only.
- **tv** — YacineTV live-TV tree; the client refreshes expired stream tokens on-device.
- **subtitles** — OpenSubtitles (keyless legacy REST); download `.srt`/`.vtt`, either applied in-room or uploaded to the server. The in-room "Download subtitle" search keys off the room's `imdbId` when it was created from the catalogue.

The room catalogue/lifecycle (list, create, unlock, delete, subtitle upload, download-progress polling) goes over the REST API under `/api/rooms`.

### Realtime protocol (Socket.IO)

Bound once per room. **Inbound:** `sync`, `force_resync`, `rate_changed`, `chat_history`, `chat`, `chat_throttled`, `viewer_count`, `room_users`, `wait_state`, `source_changed`, `subtitle_changed`, `reaction`, `room_deleted`, `voice_start`/`voice_chunk`/`voice_end`. **Outbound:** `join_room`/`leave_room`, `control` (play/pause/seek/rate), `chat`, `reaction`, `buffer_state`, `force_resync`, `change_source`, `set_name`, voice events.

### Localization & theming

English (`en`) + Arabic (`ar`) with full RTL. Strings live in `core/localization/lang/`; access them in widgets via the `context.tr` extension (`core/extensions/context_extensions.dart`). Active locale and theme mode are both persisted through `hydrated_bloc` and restored on launch.
