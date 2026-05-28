# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**TeleCinema** — a Flutter client for synchronized video watch-parties. People in a
room watch the same video in lockstep (server is the authoritative clock) with live
chat, presence, emoji reactions, subtitles, and push-to-talk voice. It is the
mobile/desktop companion to an **AdonisJS backend** and speaks the *exact same*
Socket.IO protocol as the web client, so all platforms share one room.

The package name in `pubspec.yaml` is `watch_aprty_app`; the user-facing app name is `TeleCinema`.

## Commands

```bash
flutter pub get                 # fetch deps (run after pulling / editing pubspec)
flutter run                     # run on connected device/emulator/browser
flutter analyze                 # lint (flutter_lints) — the only static gate
flutter test                    # run all tests
flutter test test/widget_test.dart --plain-name "<name>"   # single test by name

flutter build apk | ios | web | windows | macos | linux

dart run flutter_launcher_icons # regenerate launcher icons from assets/icon/
```

There is currently only a starter `test/widget_test.dart`; there is no real test suite yet.

## First thing to set: the backend URL

Everything is derived from one constant in [lib/core/config/app_config.dart](lib/core/config/app_config.dart):

```dart
static const String baseUrl = 'https://telecinema.up.railway.app';
```

REST (`/api`), the Socket.IO endpoint (server root), and media URLs (`/video/`,
`/thumbnails/`, `/subtitles/`) are all computed from it. For local dev use
`http://10.0.2.2:3333` (Android emulator) or `http://192.168.x.x:3333` (physical
device). Cleartext HTTP is already permitted in the native manifests.

## Architecture

Clean Architecture, **feature-first**. Two features under `lib/features/`:
`rooms/` (catalogue: browse, create, unlock, delete) and `watch/` (in-room sync,
chat, reactions, voice). Each feature has `data/ domain/ presentation/ injections/`.

```
presentation (Cubit/BLoC)  →  domain (entities, repo contracts, use cases)  →  data (datasources, models, repo impls)
```

Cross-cutting code lives in `lib/core/` (config, network, errors, localization,
theme, constants) and `lib/logic/` (app-wide stateful singletons: socket, identity,
theme, locale, storage).

### Dependency injection (`get_it`, alias `sl`)

`main()` calls `initDependencies()` → [lib/injections/injection.dart](lib/injections/injection.dart),
which runs `injectSingletons` then `initFactories`. The split matters:

- **Singletons** ([inject_singletons.dart](lib/injections/inject_singletons.dart)): long-lived — `SocketCubit`,
  `ApiClient`, storage, identity, theme/locale cubits, and each feature's
  **datasource + repository**. Order is significant: storage/socket come up before
  `IdentityCubit` (needs both).
- **Factories** ([inject_factories.dart](lib/injections/inject_factories.dart)): a fresh page-scoped instance per route —
  `WatchCubit`, `VoiceCubit`, `RoomsListCubit`, `CreateRoomCubit`.

Each feature registers its own DI in `features/<name>/injections/` and is wired in from the root.

### The shared socket (the central design choice)

One [`SocketCubit`](lib/logic/socket/socket_cubit.dart) wraps a single Socket.IO connection for the whole app
(generic transport — knows nothing about rooms). Its methods are split across
`part` files in `logic/socket/handlers/`. Handlers route state through `_set()`
because `emit` is `@protected`.

[`WatchSocketDataSource`](lib/features/watch/data/datasources/watch_socket_datasource.dart) is a **singleton** that binds the room protocol onto that
shared socket and exposes typed broadcast streams (`sync`, `chat`, `reaction`,
`voice_*`, …). It is a singleton because only one room is open at a time and one
connection is kept alive per signed-in user; binding happens once (`on` is
idempotent across reconnects) and `join_room` is re-emitted on every reconnect.
Page-scoped `WatchCubit`/`VoiceCubit` consume its streams.

Protocol events are listed in [README.md](README.md#realtime-protocol). When changing realtime behavior,
keep parity with the web client — the backend forwards the same events to both.

### Error handling (functional, no try/catch in the UI)

The flow is uniform — follow it for any new data path:

1. **Datasource** throws a typed `ServerException` (see [core/errors/exceptions.dart](lib/core/errors/exceptions.dart)).
2. **Repository** wraps every call in `_guard()` and converts exceptions into a
   `Failure` whose `.message` **is a `TranslationKeys` constant** (see
   [rooms_repository_impl.dart](lib/features/rooms/data/repositories/rooms_repository_impl.dart)).
3. **Use case** returns `Either<Failure, T>` (`dartz`). Streaming realtime data uses
   `StreamUseCase` instead (see [core/UseCase/usecase.dart](lib/core/UseCase/usecase.dart)).
4. **Cubit** does `res.fold((f) => emit(error, errorKey: f.message), (ok) => …)`.
   The UI translates `errorKey` via `context.tr`.

So a `Failure.message` is never a human string — it is always a translation key.

### Synchronized playback (the watch "brain")

[`WatchCubit`](lib/features/watch/presentation/bloc/watch_cubit.dart) owns playback. Key facts:

- **The player is `media_kit` (libmpv), not `video_player`** — file rooms use a
  `Player`/`VideoController` with a large demuxer buffer + back-buffer cache so
  re-seeks don't re-download. (The README's stack table is out of date here.)
- The server is the source of truth. On each `sync`, `PlaybackSync.effectiveTime()`
  extrapolates the room's position from `serverTime` to account for latency
  ([playback_sync.dart](lib/features/watch/domain/entities/playback_sync.dart)). The client hard-seeks only when drift exceeds
  `AppConstants.hardSeekThresholdSeconds` (1.5s); otherwise it lets playback ride.
- **Buffer-wait gate**: a *sustained* local stall (debounced `bufferReportDelay`,
  1.5s) emits `buffer_state: true` so one slow viewer pauses the room, then resumes
  together. Don't report momentary hiccups.
- **External (embed) rooms have no player** — they render a WebView and only track
  the virtual clock for the subtitle overlay; resync/source-change reload the view
  via a `resyncTick` bump.
- Tunables live in [core/constants/app_constants.dart](lib/core/constants/app_constants.dart) (chat history cap mirrors the
  server's ring buffer; sync/buffer thresholds match the web client). Change them
  there, not inline.

## Localization

Map-based, no ARB/codegen. Add a string by:

1. Adding a constant to [translation_keys.dart](lib/core/localization/translation_keys.dart).
2. Adding the value to **both** [lang/en_us.dart](lib/core/localization/lang/en_us.dart) **and** [lang/ar_ar.dart](lib/core/localization/lang/ar_ar.dart) (a missing
   key falls back to English, then to the raw key — visible, not crashing).
3. Reading it in widgets with `context.tr(TranslationKeys.x)`.

Arabic (`ar`) triggers full RTL. Locale and theme are persisted via `hydrated_bloc`
(`LocaleCubit` / `ThemeCubit`) and restored on launch. Theme/colors are read through
`context` extensions (`context.colors`, `context.semantic`, `context.text`) — see
[core/extensions/context_extensions.dart](lib/core/extensions/context_extensions.dart).

## Conventions

- Navigation is a single `go_router` ([routes/routers.dart](lib/routes/routers.dart)); no auth gate — every room is
  public, password rooms use an in-page unlock overlay. Navigate by route *name*
  (`RoutesNames`), passing a `Room` via `extra` when available to skip a refetch.
- New realtime work: extend `WatchSocketDataSource` (add a stream + a bind in
  `_bind()` + an emit method), surface it through `WatchRepository`, then consume in
  the cubit. Don't talk to `SocketCubit` directly from features.
- New REST work: add to the datasource (throw `ServerException`), map in the repo
  `_guard`/`_map`, expose a use case, consume via `Either.fold`.
