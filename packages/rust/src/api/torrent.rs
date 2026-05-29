//! On-device torrent streaming engine backed by librqbit.
//!
//! A single global librqbit [`Session`] runs inside a dedicated multi-threaded
//! Tokio runtime. librqbit's built-in HTTP API serves the partial file over
//! `GET /torrents/{id}/stream/{file}` with HTTP Range support, and the stream
//! reader prioritises pieces in playback order (first/last piece, then
//! sequential), so `media_kit` can start playing within seconds while the rest
//! keeps downloading.
//!
//! This is the local-streaming path only: each device fetches the torrent from
//! the swarm itself and plays it from `127.0.0.1`. There is no peer-to-peer
//! signalling between app users — room sync (play/pause/seek/chat/reactions)
//! travels over the app's existing server socket, not through here.

use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock};

use anyhow::{anyhow, Context, Result};
use librqbit::http_api::HttpApi;
use librqbit::{AddTorrent, AddTorrentOptions, Api, Session, SessionOptions};
use tokio::runtime::Runtime;

struct Engine {
    session: Arc<Session>,
    /// Port the local HTTP streaming server is bound to (127.0.0.1:port).
    port: u16,
}

static RUNTIME: OnceLock<Runtime> = OnceLock::new();
static ENGINE: OnceLock<Engine> = OnceLock::new();

/// A single file inside a torrent.
pub struct TorrentFile {
    pub index: u32,
    pub name: String,
    pub length: u64,
}

/// Result of adding a torrent: everything the UI needs to start streaming.
pub struct AddedTorrent {
    pub id: u32,
    pub name: String,
    pub files: Vec<TorrentFile>,
    /// Index of the largest file — the one to stream by default (the video).
    pub primary_file_index: u32,
    /// Ready-to-play URL for the primary file.
    pub stream_url: String,
}

/// Initialise the torrent engine. `download_dir` must be an app-writable
/// directory (e.g. from `path_provider`). Returns the local HTTP server port.
/// Idempotent: later calls just return the existing port.
pub fn init_torrent_engine(download_dir: String) -> Result<u16> {
    if let Some(engine) = ENGINE.get() {
        return Ok(engine.port);
    }

    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(3)
        .thread_name("telecinema-torrent")
        .build()
        .context("failed to build tokio runtime")?;

    let port = rt.block_on(async move {
        let opts = SessionOptions {
            // Streaming client: no persistence so we never touch a non-writable
            // config dir on Android, and we use a fresh DHT each launch. DHT
            // itself stays ENABLED — it is how we find seeders for the torrent
            // (this is not user-to-user signalling).
            disable_dht: false,
            disable_dht_persistence: true,
            persistence: None,
            fastresume: false,
            ..Default::default()
        };

        let session = Session::new_with_opts(PathBuf::from(&download_dir), opts)
            .await
            .context("error creating librqbit session")?;

        // Third arg (line_broadcast) exists because tracing-subscriber-utils
        // is enabled; we don't stream logs to the UI, so pass None.
        let api = Api::new(session.clone(), None, None);
        let http_api = HttpApi::new(api, None);

        let listener = tokio::net::TcpListener::bind(SocketAddr::from(([127, 0, 0, 1], 0)))
            .await
            .context("error binding local stream server")?;
        let port = listener.local_addr()?.port();

        // Detached; runs for the lifetime of the runtime.
        tokio::spawn(http_api.make_http_api_and_run(listener, None));

        ENGINE
            .set(Engine { session, port })
            .map_err(|_| anyhow!("torrent engine already initialised"))?;

        Ok::<u16, anyhow::Error>(port)
    })?;

    let _ = RUNTIME.set(rt);
    Ok(port)
}

fn engine() -> Result<&'static Engine> {
    ENGINE.get().context("torrent engine not initialised")
}

fn runtime() -> Result<&'static Runtime> {
    RUNTIME.get().context("torrent runtime not initialised")
}

/// Add a torrent from a magnet link (or an http(s) `.torrent` URL). Resolves
/// metadata, then returns the file list plus a stream URL for the largest file.
pub fn add_torrent(magnet: String) -> Result<AddedTorrent> {
    let engine = engine()?;
    let rt = runtime()?;

    rt.block_on(async move {
        let response = engine
            .session
            .add_torrent(
                AddTorrent::from_url(magnet.as_str()),
                Some(AddTorrentOptions {
                    overwrite: true,
                    ..Default::default()
                }),
            )
            .await
            .context("error adding torrent")?;

        let handle = response
            .into_handle()
            .context("torrent was list-only; no handle returned")?;

        // A magnet's metadata (file list, sizes) is fetched from the swarm
        // asynchronously, so it is usually NOT ready the moment `add_torrent`
        // returns. Wait for the torrent to finish initializing — bounded, so a
        // dead magnet surfaces as an error rather than hanging — before reading
        // the file list below; otherwise `metadata` is still empty and we'd
        // build a stream URL for a file that hasn't been resolved yet.
        tokio::time::timeout(
            std::time::Duration::from_secs(60),
            handle.wait_until_initialized(),
        )
        .await
        .context("timed out resolving torrent metadata")?
        .context("error resolving torrent metadata")?;

        let id = handle.id() as u32;
        let name = handle.name().unwrap_or_else(|| format!("torrent-{id}"));

        let mut files: Vec<TorrentFile> = Vec::new();
        if let Some(meta) = handle.metadata.load_full() {
            for (i, fi) in meta.file_infos.iter().enumerate() {
                files.push(TorrentFile {
                    index: i as u32,
                    name: fi.relative_filename.to_string_lossy().into_owned(),
                    length: fi.len,
                });
            }
        }

        // The largest file is the video in the common case.
        let primary_file_index = files
            .iter()
            .max_by_key(|f| f.length)
            .map(|f| f.index)
            .unwrap_or(0);

        let stream_url = stream_url_for(engine.port, id, primary_file_index);

        Ok(AddedTorrent {
            id,
            name,
            files,
            primary_file_index,
            stream_url,
        })
    })
}

/// Build the stream URL for a specific file in a torrent.
#[flutter_rust_bridge::frb(sync)]
pub fn get_stream_url(torrent_id: u32, file_index: u32) -> Result<String> {
    let engine = engine()?;
    Ok(stream_url_for(engine.port, torrent_id, file_index))
}

fn stream_url_for(port: u16, torrent_id: u32, file_index: u32) -> String {
    format!("http://127.0.0.1:{port}/torrents/{torrent_id}/stream/{file_index}")
}
