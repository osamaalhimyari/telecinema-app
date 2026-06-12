# Watch Party — Offline Pre‑Cache & Local Playback

**Implementation Plan · Fixed price: $8,000**

> Goal: let a viewer on a slow connection **fully download a room's video to his
> device before/while watching**, then **play it locally** (zero buffering) while
> everyone stays perfectly in sync — controls, emojis and chat unchanged. Plus a
> **Cached Videos** screen (AppBar button) to manage and delete downloads.

---

## 1. Executive summary

The app already streams each room's video **independently per device** — there is
**no video data on the socket**. Torrent rooms stream through the embedded Rust
`librqbit` engine (a local `http://127.0.0.1:<port>/…` server with range support);
download/upload/topcinema rooms stream a plain HTTP file from the backend. The
Socket.IO channel only carries lightweight sync (`control`, `chat`, `reaction`,
`room_users`, `voice_*`, …).

That changes the shape of the work:

- **"Separating control from video frames" is already done.** The video is never
  emitted over the socket; controls/chat/reactions are already tiny, server‑relayed
  events. We will *verify and harden* this (Workstream 7), but the heavy lifting is
  elsewhere.
- **The real fix is on‑device pre‑caching.** Give the slow viewer a **Download**
  button that pulls the whole movie to disk (pause / resume / cancel, live
  progress). Once cached, his player reads from local disk — no buffering, no drift,
  no forced "catch‑up" seeks — while the socket keeps him in lockstep with the host.
- **Per‑device cache.** Each viewer decides independently whether to cache. Cached
  viewers play locally; everyone else streams as today.
- **Zero backend changes required for v1.** The client already has everything it
  needs (the magnet for torrent rooms via the room's `magnetUri`, and the
  `/video/:filename` HTTP URL for file rooms). This keeps the feature a **self‑
  contained new module**, per the project's "isolate new features" rule.

The only substantial new engineering is **extending the Rust `librqbit` bridge**
(it currently exposes *start / add / get‑stream‑URL* only — no progress, pause,
resume, list, or delete). Everything else is standard Flutter + Dio + a small local
cache index.

---

## 2. Problem analysis (why the slow client suffers today)

Traced through [watch_cubit.dart](lib/features/watch/presentation/bloc/watch_cubit.dart)
and the backend `start/socket.ts`:

1. **Real‑time starvation.** A torrent/stream that downloads slower than the video's
   bitrate can't fill the player's buffer. `media_kit`/libmpv stalls.
2. **The room pauses for everyone.** When a client stalls it emits
   `buffer_state{buffering:true}` (1.5 s debounce). The server's `evaluateBufferGate`
   auto‑pauses the whole room and broadcasts `wait_state` → the "wait for the slow
   viewer" banner. So the slow peer degrades *everyone's* experience.
3. **Forced catch‑up seeks lose content.** The server keeps an authoritative clock
   and extrapolates time forward. When the slow client drifts > 5 s, `_applyToVideo`
   **hard‑seeks him forward** to the room position — skipping exactly the part that
   never downloaded. He literally never sees those seconds.
4. **On‑device torrent stall → server fallback.** If the on‑device torrent stalls
   20 s, the client silently falls back to the server stream — which may be just as
   slow.

**Pre‑downloading eliminates all four:** a fully cached file plays from disk
instantly, never buffers, never trips the gate, never drifts, never gets
force‑seeked.

---

## 3. Solution architecture

### 3.1 The model

```
            ┌─────────────── Socket.IO (unchanged) ───────────────┐
            │  control · chat · reaction · room_users · voice_*    │   ← tiny, shared
            └──────────────────────────────────────────────────────┘
                    ▲                         ▲                    ▲
            Host (streams)            Slow viewer (CACHED)   Other viewer (streams)
                    │                         │                    │
        on-device librqbit / HTTP     LOCAL FILE on disk     on-device librqbit / HTTP
            (network, real time)      (instant, no network)     (network, real time)
```

Each device chooses its **playback source** independently. Sync is identical for all.

### 3.2 Two content types we cache (per `room_type`)

| Room type | Source today | Cache strategy | Play‑from‑cache |
|-----------|--------------|----------------|-----------------|
| **torrent** | magnet → `librqbit` local HTTP server | Tell `librqbit` to download **all** pieces, persist the session across restarts | Same `127.0.0.1` stream URL — now served entirely from disk, instantly |
| **download / upload** (incl. topcinema files) | `/video/:filename` HTTP (range) | Dio **resumable range download** to a local cache file | Point `media_kit` at the local file path |
| **external / embed** | cross‑origin WebView iframe | **Not cacheable** (out of scope) | n/a — button hidden |

### 3.3 Source resolution (the one seam in existing playback)

In [watch_cubit.dart](lib/features/watch/presentation/bloc/watch_cubit.dart),
`_initVideo(url)` calls `player.open(Media(url))`. We add a single pre‑check:

```
final cached = await cacheManager.resolvePlayable(room);   // null if not cached
await player.open(Media(cached ?? url), play: false);      // prefer local
```

- Torrent room, fully cached → `cached` is the local `librqbit` stream URL (now
  100 % on disk).
- File room, fully cached → `cached` is the absolute local file path.
- Not cached / partial below threshold → unchanged behaviour (stream).

That's the **only** change to existing playback code. Everything else lives in a new
`lib/features/cache/` module.

---

## 4. Scope

**In scope (v1)**

- In‑room **Download** button: start, pause, resume, cancel; live % / size / speed.
- Resumable downloads that survive app backgrounding **and full app restart**.
- **Play‑from‑cache** for torrent and file rooms; sync verified unaffected.
- **Cached Videos** library screen (AppBar action): list, per‑item delete, delete‑all,
  resume partials, storage usage.
- Storage‑quota awareness and safe cleanup of partial files.

**Out of scope (v1, listed so it's explicit)**

- Caching **external/embed** rooms (cross‑origin — technically impossible).
- Server‑side cache or any backend schema change (kept client‑only by design).
- Adaptive HLS/DASH caching (all current content is single‑file MP4/torrent — N/A).
- A new "who's playing from cache" indicator for *other* users (optional, see §7.3;
  it would require a small server change, so it's deferred).
- Web platform (no on‑device torrent engine on web; the button is hidden there).

---

## 5. Workstreams (detailed)

### WS1 — Rust `librqbit` bridge extension  *(heaviest item)*

Today [torrent.rs](packages/rust/src/api/torrent.rs) exposes only
`initTorrentEngine`, `addTorrent`, `getStreamUrl`
(see [torrent.dart](lib/src/rust/api/torrent.dart)). We add **additive** `pub`
functions (no changes to existing ones), regenerate the `flutter_rust_bridge`
bindings, and wrap them in [torrent_engine.dart](lib/features/watch/data/datasources/torrent_engine.dart):

- `torrentStats(infoHash) -> {state, totalBytes, downloadedBytes, downloadSpeed, finished}`
  — drives the progress UI. Prefer a **stats stream** (poll librqbit stats on a
  timer in Dart if a stream is awkward across the bridge).
- `setDownloadWhole(infoHash)` — switch from "stream window" to **download the entire
  primary file** (all pieces wanted), so caching completes even when paused playback.
- `pauseTorrent(infoHash)` / `resumeTorrent(infoHash)` — true stop/start of the swarm.
- `listTorrents() -> [{infoHash, name, totalBytes, downloadedBytes, finished}]` —
  rebuild the library after restart.
- `removeTorrent(infoHash, deleteFiles: true)` — delete from disk for the cache UI.
- **Session persistence:** enable `librqbit` session/state persistence (currently DHT
  persistence is disabled) so added torrents and their downloaded data **survive app
  restarts** and resume automatically.

> Risk note: this is Rust + cross‑compile (Android/iOS) + FRB codegen. M0 includes a
> half‑day spike to confirm the exact `librqbit` API surface and persistence config
> before committing the estimate.

### WS2 — Dart cache core (new module `lib/features/cache/`)

- **`CacheManager` service** (DI singleton, registered in
  [inject_singletons.dart](lib/injections/inject_singletons.dart) next to the other
  singletons): the single entry point — `startCache(room)`, `pause(key)`,
  `resume(key)`, `cancel(key)`, `delete(key)`, `resolvePlayable(room)`,
  `progressStream(key)`, `list()`.
- **Cache index** (persistent): one record per cached item —
  `{ key, roomSlug, title, roomType, infoHash?, localPath?, totalBytes, downloadedBytes,
  status(queued|downloading|paused|done|error), subtitlePath?, createdAt, updatedAt }`.
  Use **`sqflite`** (add to `pubspec.yaml`) for a real, queryable index; `shared_preferences`
  (current KV store) isn't suited to dozens of large‑file records. Initialise it in
  `main()` before `initDependencies()`, mirroring the existing HydratedBloc bootstrap.
- **Cache key (stable identity):** torrent → **`infoHash`** (from the magnet); file →
  **`roomSlug` + `videoFilename`**.
- **Storage location:** a dedicated `cache/videos/` dir under
  `getApplicationSupportDirectory()` (same root `librqbit` already uses), **not** the
  Documents dir (keeps large media out of HydratedBloc's space).

### WS3 — HTTP resumable downloader (for download/upload/topcinema file rooms)

- Add `downloadWithProgress(url, savePath, {onProgress, cancelToken, resumeFrom})` to
  the [ApiClient](lib/core/network/api_client.dart) abstraction and implement it in
  [dio_api_client.dart](lib/core/network/dio_api_client.dart) using Dio's `Range:
  bytes=<offset>-` header, appending to a `.part` file and persisting the byte offset.
- Pause = cancel the Dio request but **keep** the `.part` + offset; resume = re‑issue
  from the saved offset. On completion, atomically rename `.part` → final file.
- On cancel/delete, remove the `.part` file (avoid orphaned partials — see gotchas).
- Also cache the room's **subtitle** alongside the video so offline playback keeps subs.

### WS4 — Play‑from‑cache wiring

- Implement `CacheManager.resolvePlayable(room)` per §3.3.
- One‑line seam in [watch_cubit.dart](lib/features/watch/presentation/bloc/watch_cubit.dart)
  `_initVideo`, with a safe fallback to the network URL if the local file is missing
  or unreadable (handles the file:// edge case on some Android builds — fall back to
  a tiny local file server only if a device test shows `Media(path)` failing).
- Verify the cached player still honours every `sync` / `force_resync` / `rate_changed`
  event (it should — sync is source‑agnostic).

### WS5 — In‑room Download button + `DownloadCubit`

- New `DownloadCubit` (room‑scoped, like `WatchCubit`/`VoiceCubit`), driven by
  `CacheManager.progressStream`. States: `idle → queued → downloading(%) → paused →
  done | error`.
- New `DownloadButton` widget inserted into the reaction row in
  [room_page.dart](lib/features/watch/presentation/pages/room_page.dart) (between
  `ReactionBar` and `VoiceButton`). Tap = start/pause/resume; long‑press = cancel.
  Hidden for `external` rooms and on web.
- Optional matching control in
  [fullscreen_player_page.dart](lib/features/watch/presentation/pages/fullscreen_player_page.dart)
  as a top‑right overlay (low priority).

### WS6 — Cached Videos library screen (the AppBar button)

- New route `'/cached'` in [routers.dart](lib/routes/routers.dart) (root navigator,
  same pattern as the room/subtitles routes).
- New `CachedVideosPage` + `CachedVideosCubit` reading `CacheManager.list()`: each row
  shows title, quality/size, status, progress, and a **Delete** action; plus
  **Delete all** and total storage used. Resume action for partial/paused items.
- AppBar entry point: an **IconButton** in the home AppBar actions in
  [rooms_page.dart](lib/features/rooms/presentation/pages/rooms_page.dart) (next to the
  existing Operations/Settings buttons) — and/or a menu item in the in‑room `_RoomMenu`.
- Delete → `CacheManager.delete(key)` → `librqbit removeTorrent(deleteFiles)` **or**
  unlink the cached file → remove the index row → emit new state (UI updates instantly).

### WS7 — Sync verification & "make it light" hardening

- **Confirm** control/chat/reaction payloads are minimal (they are) and that a cached
  player never emits `buffer_state` (so it stops tripping the room‑wide pause gate —
  the core win).
- **Voice is the only heavy socket payload** (`voice_chunk` raw audio). Keep it on its
  own event (already is); optionally gate it so it can't compete with control latency.
  No protocol redesign needed.
- *(Deferred, optional)* a per‑user "playing locally" indicator would need a small
  server `playback_source` relay — left out of v1 to keep the feature client‑only.

### WS8 — Resilience & storage safety

- **Restart resume:** on launch, reconcile the sqflite index with `librqbit
  listTorrents()` and on‑disk `.part` files; auto‑resume or mark paused.
- **Background continuation:** keep downloads running while the room is open and when
  backgrounded for a reasonable window; document OS limits (no third‑party background
  downloader is added in v1 — `librqbit` + Dio cover foreground/active use).
- **Quota awareness:** check free space before starting; warn near a soft cap; surface
  total cache size in the library screen.
- **Cleanup:** delete partials on cancel; remove orphaned files with no index row.

### WS9 — QA, device testing & handover

- Manual matrix on real **Android + iOS** devices: torrent room, file room, topcinema
  file room; pause/resume/cancel; kill‑and‑relaunch mid‑download; cache then watch in
  a 2‑device sync session (confirm no `wait_state`, no forced seeks for the cached
  peer); delete while in room; low‑storage path.
- Short handover doc + inline code docs.

---

## 6. Data, storage & identity (reference)

- **Cache dir:** `getApplicationSupportDirectory()/cache/videos/`.
- **Index:** `sqflite` table `cached_videos` (schema in WS2).
- **Keys:** torrent → `infoHash`; file → `slug|videoFilename`.
- **Subtitles:** cached next to the video; deleted with it.
- **Excluded:** `external` rooms; web platform.

---

## 7. Key risks & mitigations

| # | Risk | Mitigation |
|---|------|-----------|
| 1 | `librqbit` bridge lacks pause/progress/list/delete | WS1 adds them; M0 spike confirms API + persistence before lock‑in |
| 2 | Cross‑compiling Rust for iOS/Android | Already shipping `librqbit`; we only add `pub` fns + regen FRB |
| 3 | `file://` rejected by some Android players | Pass raw path to `media_kit`; fall back to a tiny local file server only if needed |
| 4 | Dead torrent swarm (0 seeders) → can't complete | Surface seeders; warn before deleting the only source; allow server‑stream fallback |
| 5 | Topcinema URLs expire (~24 h) | Cache the **bytes**, not the URL; once downloaded it's permanent locally |
| 6 | Multi‑GB downloads fill storage | Pre‑flight free‑space check, soft cap, usage meter, easy delete |
| 7 | Partial files orphaned on crash/cancel | Reconcile index ↔ disk on launch; always clean `.part` on cancel |
| 8 | Cached peer must still obey sync | Sync is source‑agnostic; explicitly tested in WS9 2‑device matrix |

---

## 8. Milestones, deliverables & cost allocation

Fixed price **$8,000**. Estimated effort ≈ **22 working days** (~4.5 weeks) for one
senior Flutter + Rust developer. Allocation:

| Milestone | Deliverable | Effort | Share | Amount |
|-----------|-------------|-------:|------:|-------:|
| **M0** Discovery & Rust spike | Confirmed `librqbit` API + persistence; final design sign‑off | 2 d | 8% | **$640** |
| **M1** Rust bridge extension (WS1) | progress/stats, download‑whole, pause/resume, list, remove, session persistence + FRB bindings | 5 d | 22% | **$1,760** |
| **M2** Cache core (WS2 + WS3) | `CacheManager`, sqflite index, resumable HTTP downloader, DI, subtitle caching | 4 d | 18% | **$1,440** |
| **M3** Play‑from‑cache (WS4 + WS7) | source resolution seam + sync hardening/verification | 2.5 d | 10% | **$800** |
| **M4** In‑room Download button (WS5) | `DownloadCubit` + button (portrait + optional fullscreen) | 2 d | 10% | **$800** |
| **M5** Cached Videos screen (WS6) | library page, AppBar entry, route, delete/delete‑all/resume | 3 d | 12% | **$960** |
| **M6** Resilience (WS8) | restart‑resume, background, quota, cleanup | 2 d | 10% | **$800** |
| **M7** QA & handover (WS9) | device test matrix, fixes, docs | 1.5 d | 10% | **$800** |
| | **Total** | **22 d** | **100%** | **$8,000** |

Suggested payment schedule: 25% on M0+M1 sign‑off, 50% on M3+M5 (feature usable
end‑to‑end), 25% on M7 acceptance.

---

## 9. Acceptance criteria (definition of done)

1. In a torrent room **and** a file/topcinema room, a viewer can press **Download**,
   watch progress, **pause and resume** repeatedly, and **cancel** — with no crashes.
2. After download completes, that viewer's playback is served **from local disk**:
   no buffering, no `wait_state` banner caused by him, no forced catch‑up seeks; he
   stays in sync with the host on play/pause/seek/rate.
3. Emojis, reactions, chat and voice work **identically** for cached and streaming
   viewers.
4. Killing and relaunching the app **resumes** an interrupted download from where it
   stopped; completed caches remain playable offline.
5. The **Cached Videos** screen (AppBar) lists every cached/partial item with size and
   status, allows **per‑item delete and delete‑all**, frees the disk space, and the UI
   updates immediately.
6. The **external/embed** room type cleanly hides the Download button (no errors).
7. **No backend code or schema changes** were required.

---

## 10. Open decisions (recommended defaults in **bold**)

1. Local DB for the cache index: **`sqflite`** (vs `isar`/`hive`). Recommend sqflite
   for simplicity and queryability.
2. Cached file playback: **pass the raw local path to `media_kit`**; add a local file
   server only if a device test proves it necessary.
3. Fullscreen Download button: **include as a small overlay** (or portrait‑only to cut
   scope — your call).
4. "Who's watching locally" indicator for others: **deferred** (needs a minor server
   change; can be a fast follow‑up).
5. Soft storage cap default: **suggest 2–4 GB** with a user‑visible meter (configurable).

---

### Appendix — primary integration points

| Concern | File |
|--------|------|
| Playback orchestrator (source‑resolution seam) | [watch_cubit.dart](lib/features/watch/presentation/bloc/watch_cubit.dart) |
| Torrent engine wrapper (extend) | [torrent_engine.dart](lib/features/watch/data/datasources/torrent_engine.dart) |
| Rust FRB bindings (regenerate) | [torrent.dart](lib/src/rust/api/torrent.dart) · `packages/rust/src/api/torrent.rs` |
| HTTP client (add resumable download) | [api_client.dart](lib/core/network/api_client.dart) · [dio_api_client.dart](lib/core/network/dio_api_client.dart) |
| Room screen (Download button) | [room_page.dart](lib/features/watch/presentation/pages/room_page.dart) |
| Fullscreen (optional button) | [fullscreen_player_page.dart](lib/features/watch/presentation/pages/fullscreen_player_page.dart) |
| Home AppBar (Cached Videos entry) | [rooms_page.dart](lib/features/rooms/presentation/pages/rooms_page.dart) |
| Routing (`/cached` route) | [routers.dart](lib/routes/routers.dart) |
| DI registration | [inject_singletons.dart](lib/injections/inject_singletons.dart) |
| Sync protocol (unchanged, for reference) | [watch_socket_datasource.dart](lib/features/watch/data/datasources/watch_socket_datasource.dart) |
| Room source identity | [room.dart](lib/features/rooms/domain/entities/room.dart) · [room_type.dart](lib/features/rooms/domain/entities/room_type.dart) |
</content>
</invoke>
