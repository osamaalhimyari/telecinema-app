# Defect review — watch-party app + backend

Source: direct code review of both repos (the deeper multi-agent verification pass was
stopped for speed). Each item lists repo · file · severity · root cause · fix. Ordered
by severity. Nothing below has been applied yet — this is the plan.

Repos:
- App: `c:\xampp\htdocs\projects\mine\watch_aprty_app`
- Backend: `c:\xampp\htdocs\projects\mine\watch-party`

---

## CRITICAL

### C1 — SSRF: redirect bypasses the private-IP guard
- **Repo / file:** backend · `app/services/video_downloader.ts` (`runDownload`, ~L275–285)
- **Root cause:** `assertPublicHost(url)` validates only the *original* URL's host, then
  `fetch(url, { redirect: 'follow' })` follows 3xx redirects to *any* host with no
  re-check. A public link can 302 to `http://169.254.169.254/...` (cloud metadata),
  `http://127.0.0.1`, or an internal service — the exact SSRF the guard exists to stop.
- **Fix:** Don't let `fetch` auto-follow. Use `redirect: 'manual'` and loop: on each 3xx,
  resolve the `Location`, run `parseHttpUrl` + `assertPublicHost` on it, cap hops (e.g. 5),
  then continue. Reject `file:`/non-http. (Alternatively validate `response.url` and every
  hop, but manual-follow is the only airtight option.) Apply the same check to the magnet
  path is N/A — only the URL downloader fetches arbitrary hosts.
- **Note:** this is pre-existing, not from the recent work, but it's the highest-risk
  defect found.

---

## HIGH

### H1 — Operations panel polls the server forever
- **Repo / file:** app · `lib/features/operations/presentation/bloc/operations_cubit.dart`
  (`_poll` / `_schedule`, ~L53–72)
- **Root cause:** `start()` is called at launch (`main.dart`, `..start()`), and `_poll`'s
  `finally { _schedule() }` re-arms unconditionally. So the app fires `GET /api/operations`
  every 15 s for its entire lifetime — even when the user has never created a transfer and
  the panel has zero operations. Constant background network + battery drain.
- **Fix:** Make polling demand-driven. Stop rescheduling when there are no operations and no
  active local uploads; (re)start polling when: a room-create download/torrent kicks off,
  `beginUpload` runs, the panel sheet opens, or `refresh()` is called. Keep the fast/idle
  split only while something is being tracked. Concretely: in `_schedule`, `if (_server.isEmpty && _local.isEmpty) { _timer?.cancel(); _started = false; return; }`
  and have the Rooms screen / create flow call `start()`/`refresh()` to wake it.

### H2 — `emit` after a poll can throw if the cubit is ever closed
- **Repo / file:** app · `operations_cubit.dart` (`_poll` → `_emitMerged` → `emit`)
- **Root cause:** `_poll` runs detached on a timer; if the singleton is ever disposed (or in
  tests), the in-flight poll resolves and calls `emit` after `close()`, which throws. Also
  `refresh()` can run a second `_poll` concurrently with the scheduled one — two `_ds.list()`
  in flight, last writer wins.
- **Fix:** Guard `if (isClosed) return;` before every `emit`/`_schedule`. Optionally a
  `bool _polling` re-entrancy guard so `refresh()` and the timer don't overlap.

---

## MEDIUM

### M1 — Device id persisted fire-and-forget (id can change across a fast restart)
- **Repo / file:** app · `lib/core/device/device_identity.dart` (`id` getter, ~L37)
- **Root cause:** On first use it generates a UUID, caches it in memory, and calls
  `_storage.setString(...)` **without awaiting**. If the app is killed before the write
  flushes, the next launch generates a *different* id — and the server then can't match the
  prior device's in-flight operations (the whole point of the id).
- **Fix:** Generate the id eagerly during DI init and `await` the persist before the app
  runs (DI is already async). e.g. add `Future<void> ensurePersisted()` that awaits
  `setString`, called from `injectSingletons` right after `DeviceIdHolder.current = ...`.

### M2 — Torrent cancel is ignored once metadata has arrived
- **Repo / file:** backend · `app/services/torrent_streamer.ts` (`runTorrentRoom`, the
  stream flow)
- **Root cause:** The only cancel checkpoint is right after `ensureTorrent`. If the user
  cancels *after* that but before the room row is created, `cancelTorrentJob` returns `true`
  (status still `downloading`) yet the room is still created and the job ends `done`. The UI
  shows "canceled succeeded" but the room exists anyway.
- **Fix:** Re-check `job.canceled` immediately before `Room.create(...)` and, for the
  magnet-download flow, after the pipeline. If canceled, skip room creation / delete the
  freshly-created row and mark the job `operation_canceled`. (Magnet-download already aborts
  mid-stream via the counter — only the metadata→create gap needs the extra check.)

### M3 — Subtitles: dead `query` path + orphaned helpers after removing name search
- **Repo / file:** app · `lib/features/subtitles/data/datasources/opensubtitles_datasource.dart`
- **Root cause:** Name search was removed from the cubit, so `query` is never passed.
  `buildOpenSubtitlesSearchUrl`'s `query-` branch and the helpers `subtitleSearchTerms` /
  `showTitleFromRelease` / `_titleCutRe` are now dead code; `subtitleTitleHint` translation
  key is unused. Not a runtime bug, but dead surface that misleads.
- **Fix:** Drop the `query` parameter from `buildOpenSubtitlesSearchUrl`, `search`, the
  repository, usecase, and `SearchSubtitlesParams`; delete `subtitleSearchTerms` /
  `showTitleFromRelease` / `_titleCutRe` and the `subtitleTitleHint` key. Pure cleanup —
  confirm no other caller (e.g. room context) still uses them first.

---

## LOW

### L1 — Stale `cancelToken` left on the create-room usecase
- **Repo / file:** app · `lib/features/rooms/presentation/bloc/create_room/create_room_cubit.dart`
  + `domain/usecases/create_room_usecase.dart`
- **Root cause:** `_createRoom.cancelToken` is set for an upload but never cleared on
  `reset()` or for a subsequent non-upload submit. Harmless today (only the multipart branch
  reads it), but a latent footgun if a future flow passes the token to a non-multipart call.
- **Fix:** Set `_createRoom.cancelToken = null` for non-upload submits and in `reset()`.

### L2 — `clearFinished`/`dismiss` for finished SERVER ops — ALREADY FIXED
- **Repo / file:** app · `operations_cubit.dart`
- **Status:** ✅ Resolved in the current file via the `_dismissed` set (hides finished
  server transfers immediately and prunes the set once the server stops listing the id).
  Listed here only so the review is complete — no action needed.

### L3 — Operations `dismiss` X-button discoverability
- **Repo / file:** app · `lib/features/operations/presentation/widgets/operations_button.dart`
- **Root cause:** Minor UX — a dismissed server op reappears only because it was hidden, but
  there's no toast/feedback. Cosmetic; optional.
- **Fix:** Optional — none required.

---

## Verification steps (after applying)
- App: `flutter analyze lib` → expect **No issues found**.
- Backend: `npx tsc --noEmit -p tsconfig.json` → expect **exit 0**.
- Manual smoke (optional): create a link-download room, kill the socket for ~1 s, confirm the
  operation still shows in the panel and Cancel aborts it (validates C1 fix didn't break the
  happy path and H1/M1 still surface the op).

## Suggested order
1. **C1** (SSRF) — security, isolated to `runDownload`.
2. **H1 + H2** (polling lifecycle + close guard) — same file, one pass.
3. **M1** (device-id persist) — DI tweak.
4. **M2** (torrent cancel gap) — backend.
5. **M3 + L1** (dead-code cleanup + token reset) — low-risk tidy.
