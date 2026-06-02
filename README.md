# TeleCinema

> Synchronized video rooms, live chat, reactions, and push-to-talk voice — a cross-platform Flutter client.

![Flutter](https://img.shields.io/badge/Flutter-3.11%2B-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-SDK%203.11-0175C2?logo=dart&logoColor=white)
![State](https://img.shields.io/badge/State-BLoC%2FCubit-8A2BE2)
![Realtime](https://img.shields.io/badge/Realtime-Socket.IO-010101?logo=socketdotio&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-success)

TeleCinema lets people watch the same video together, in sync, from anywhere. Playback is driven by an authoritative server clock, so everyone in a room sees the same moment — whether the video was uploaded directly, downloaded from a link, or embedded from a third-party site. Around the video sits a live social layer: chat, emoji reactions, presence, and burst push-to-talk voice.

The app is the mobile/desktop companion to an [AdonisJS](https://adonisjs.com/) backend and speaks the **exact same realtime protocol as the web client**, so users on any platform share one room seamlessly.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Realtime Protocol](#realtime-protocol)
- [Localization & Theming](#localization--theming)
- [Supported Platforms](#supported-platforms)

---

## Features

- **Synchronized playback** — The server is the single source of truth for the playhead. The client extrapolates the room's position for network latency, nudges the playback rate for small drift, and hard-seeks when it drifts past a threshold (`1.5s`).
- **Three room types**
  - **Upload** — stream a video file uploaded directly to the server.
  - **Download** — paste a link; the server fetches the file in the background while the client polls download progress.
  - **External** — embed a third-party page inside a `WebView`; the room tracks a virtual clock for synchronized subtitles.
- **Buffer-aware wait gate** — A sustained local stall (debounced ~1.5s) reports buffering to the room so a single slow connection can pause everyone, then resume together.
- **Live chat** — Real-time messages with a bounded in-memory history (mirrors the server's ring buffer) and throttling feedback.
- **Presence & viewer count** — See who's in the room and a live headcount.
- **Emoji reactions** — Tap a reaction to broadcast a floating emoji overlay to the whole room.
- **Push-to-talk voice** — Record a short burst, relayed over the socket to other viewers (mobile ↔ mobile, server does no mixing — it only forwards bytes).
- **Subtitles** — Upload `.srt`/`.vtt` tracks; rendered as a synchronized overlay on top of the player.
- **Password-protected rooms** — Locked rooms are gated by an in-page unlock overlay; unlocks are remembered locally.
- **Room management** — Create rooms, change the source, and delete rooms you own.
- **Bilingual & themed** — English / Arabic with full RTL support, plus light/dark themes — both persisted across launches.

---

## Architecture

The codebase follows **Clean Architecture** with a **feature-first** layout. Each feature is split into three layers:

```
presentation  →  domain  →  data
   (BLoC)        (entities,    (datasources,
                  use cases,    models,
                  repos)        repo impls)
```

- **Domain** holds framework-agnostic entities, repository contracts, and use cases.
- **Data** implements those contracts against the REST API and the Socket.IO layer, mapping DTOs to entities.
- **Presentation** uses Cubits/BLoCs for state and `go_router` for navigation.

Cross-cutting concerns (the shared socket, identity, theme, locale, storage, networking) live under `core/` and `logic/`. Errors are modeled functionally: data sources throw typed exceptions, repositories convert them into `Failure`s, and use cases return `Either<Failure, T>` (via `dartz`), so the UI handles success and failure explicitly without try/catch sprawl.

A **single shared socket** is kept alive per signed-in user; each room binds its own typed event streams onto it and tears them down on leave.

---

## Tech Stack

| Concern | Package(s) |
| --- | --- |
| State management | `bloc`, `flutter_bloc`, `hydrated_bloc` (persisted state) |
| Dependency injection | `get_it` |
| Functional core | `dartz`, `equatable` |
| Routing | `go_router` |
| Networking (REST) | `dio` |
| Realtime | `socket_io_client` (Socket.IO v4 protocol) |
| Media | `video_player`, `webview_flutter`, `flutter_svg` |
| Pickers | `image_picker`, `file_picker` |
| Voice (push-to-talk) | `record`, `just_audio` |
| Storage / platform | `shared_preferences`, `path_provider`, `package_info_plus`, `url_launcher` |
| Localization | `flutter_localizations`, `intl` |

---

## Project Structure

```
lib/
├── main.dart                 # Bootstraps DI, hydrated storage, MaterialApp.router
├── core/                     # Cross-cutting building blocks
│   ├── config/               # AppConfig — base URL + derived REST/media/socket URLs
│   ├── constants/            # Tunables (sync thresholds, chat limits, debounce)
│   ├── network/              # Dio API client + typed responses
│   ├── errors/               # Exceptions, Failures, message mapping
│   ├── localization/         # AppLocalizations + en/ar string tables
│   ├── theme/                # Colors and light/dark themes
│   └── services/             # Theme & locale read-only service interfaces
├── logic/                    # App-wide stateful logic
│   ├── socket/               # Shared SocketCubit + connection handlers
│   ├── identity/             # Anonymous display identity
│   ├── theme/                # ThemeCubit (persisted)
│   ├── localization/         # LocaleCubit (persisted, RTL-aware)
│   └── storage/              # Key-value storage abstraction
├── features/
│   ├── rooms/                # Room catalogue: browse, create, unlock, delete
│   │   ├── data/  domain/  presentation/  injections/
│   └── watch/                # In-room experience: sync, chat, reactions, voice
│       ├── data/  domain/  presentation/  injections/
├── injections/               # Composition root (singletons + factories)
└── routes/                   # go_router configuration
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.11+** (Dart SDK `^3.11.0`)
- A running instance of the TeleCinema **AdonisJS backend** (serves the REST API, Socket.IO endpoint, and static video/thumbnail/subtitle assets)
- Platform toolchains for your target (Android Studio / Xcode / a desktop or web build setup)

### Installation

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Point the app at your backend (see Configuration below)
#    edit lib/core/config/app_config.dart

# 3. Run on a connected device, emulator, or browser
flutter run
```

### Build

```bash
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web
flutter build windows    # Windows (or macos / linux)
```

---

## Configuration

All backend wiring is driven by a **single base URL** in [lib/core/config/app_config.dart](lib/core/config/app_config.dart). The REST API (`/api`), the Socket.IO endpoint (server root), and the static media URLs are all derived from it.

```dart
// lib/core/config/app_config.dart
static const String baseUrl = 'https://your-domain.com';
```

Common values during development:

| Target | `baseUrl` |
| --- | --- |
| Deployed server | `https://your-domain.com` |
| Android emulator | `http://10.0.2.2:3333` (host machine's localhost) |
| Physical device | `http://192.168.x.x:3333` (your PC's LAN IP) |

> Cleartext HTTP is already permitted on Android/iOS via the native manifests for local development.

---

## Realtime Protocol

The watch experience runs over Socket.IO, using the same event set as the web client. The client binds these once per room and emits commands as the user interacts.

**Inbound (server → client):** `sync`, `force_resync`, `rate_changed`, `chat_history`, `chat`, `chat_throttled`, `viewer_count`, `room_users`, `wait_state`, `source_changed`, `subtitle_changed`, `reaction`, `room_deleted`, `voice_start` / `voice_chunk` / `voice_end`.

**Outbound (client → server):** `join_room` / `leave_room`, `control` (play / pause / seek / rate), `chat`, `reaction`, `buffer_state`, `force_resync`, `change_source`, `voice_start` / `voice_chunk` / `voice_end`.

The room catalogue and lifecycle (list, fetch, create, unlock, delete, subtitle upload, download-progress polling) go over the REST API under `/api/rooms`.

---

## Localization & Theming

- **Languages:** English (`en`) and Arabic (`ar`), with full **right-to-left** layout support when Arabic is active.
- **Persistence:** Both the active locale and the theme mode are stored via `hydrated_bloc` and restored on the next launch.
- Translations live in [lib/core/localization/lang/](lib/core/localization/lang/); access them in widgets through the `context.tr` extension.

---

## Supported Platforms

| Android | iOS | Web | Windows | macOS | Linux |
| :---: | :---: | :---: | :---: | :---: | :---: |
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

> Note: push-to-talk voice interoperates **mobile ↔ mobile**. Web peers use a `webm`/MediaRecorder format that mobile clients cannot decode incrementally — an inherent gap in the byte-relay design.

---

<p align="center"><sub>Built with Flutter · Clean Architecture · BLoC</sub></p>
