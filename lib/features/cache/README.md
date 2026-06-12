# Offline cache (`features/cache`)

Download a room's video to the device, then play it from disk with **zero
buffering** while the room stays in sync over the socket. Solves the "slow
viewer drags the whole room down" problem from `plan.md`.

## Why this design

The video **never travels over the socket** — every device fetches it
independently, and sync (play/pause/seek/chat/reactions) is a separate,
lightweight channel. The only thing a slow viewer needs is the bytes *ahead of
time*. Crucially, every cacheable room already exposes a **rangeable HTTP
endpoint**:

| Room type            | Source URL (`Room.videoUrl`) | Range support |
| -------------------- | ---------------------------- | ------------- |
| upload / download    | `/video/:filename`           | yes           |
| torrent              | `/stream/:slug`              | yes           |
| external (embed)     | — (cross-origin iframe)      | not cacheable |

So a **single resumable HTTP downloader covers every room type**, including
torrents — no Rust/`librqbit` changes and no backend changes were required. The
cache is purely a per-device, client-side optimization; the server never learns
about it.

## Pieces

- `domain/entities/cached_video.dart` — one cache entry (status, bytes, paths).
- `data/file_downloader.dart` — resumable streaming download (HTTP `Range`,
  append-on-206, truncate-on-200, cancel keeps the partial).
- `data/cache_index_store.dart` — atomic JSON index (`cache/index.json`).
- `data/cache_manager.dart` — orchestrates start/pause/resume/delete, persists
  state, reconciles after a cold start, and exposes `resolvePlayable(room)`.
- `presentation/widgets/download_button.dart` — in-room control (reaction row).
- `presentation/pages/cached_videos_page.dart` — the library screen (home AppBar).
- `injections/cache_injection.dart` — registers `CacheManager` (loads the index
  at startup).

## Seams into existing code (minimal, per "isolate new features")

- `watch_cubit.dart` `_enterRoom` — one pre-check: if a finished copy exists,
  play the local file instead of streaming.
- `watch_injection.dart` — `WatchCubit` gains a `CacheManager` dependency.
- `routers.dart` / `routes_names.dart` — `/cached` route.
- `rooms_page.dart` — AppBar "Cached videos" action.
- `room_page.dart` — `DownloadButton` in the reaction row.

Files on disk: `<appSupportDir>/cache/videos/<slug>.<ext>` (final),
`<slug>.part` (in progress), `<slug>.sub` (subtitle), plus `cache/index.json`.

## Storage / DB choice

`plan.md` §10 left this open with sqflite as the default. This implementation
uses a small **JSON index** instead — it needs no new native plugin (so it runs
without an extra `pub get`/platform registration step), and the index is tiny (a
handful of entries). Swapping to sqflite later only touches `cache_index_store`.

## Tested by hand (do before shipping — plan M7)

Android + iOS: file room, download room, topcinema room, torrent room ×
{download, pause, resume, cancel}; kill-and-relaunch mid-download (resumes);
cache-then-watch in a 2-device session (cached peer shows no `wait_state`, no
forced catch-up seeks); delete from the library; low-storage path.

## Optional future optimization — cache from the swarm directly (plan M1/WS1)

Today a torrent room is cached by pulling the **server's** `/stream/:slug`. To
cache **peer-to-peer** instead (offloading the server), extend the embedded
`librqbit` engine in `packages/rust/src/api/torrent.rs` with additive `pub`
functions — `torrent_stats`, `pause`/`resume`, `list`, `remove(deleteFiles)`,
and session persistence — then regenerate the bindings:

```
flutter_rust_bridge_codegen generate
```

and add a torrent strategy to `CacheManager` keyed by infoHash. This is a pure
optimization; the feature is already complete without it.
