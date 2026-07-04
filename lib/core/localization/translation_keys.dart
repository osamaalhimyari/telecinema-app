/// String constants for every translatable UI label. Each key must have an
/// entry in BOTH `lang/en_us.dart` and `lang/ar_ar.dart`.
class TranslationKeys {
  TranslationKeys._();

  // App
  static const appName = 'app_name';

  // Common actions
  static const retry = 'retry';
  static const cancel = 'cancel';
  static const create = 'create';
  static const delete = 'delete';
  static const close = 'close';
  static const save = 'save';
  static const ok = 'ok';

  // Exit-app confirmation (Android back at the home shell)
  static const exitAppTitle = 'exit_app_title';
  static const exitAppMessage = 'exit_app_message';
  static const exitApp = 'exit_app';

  // Network / failure keys (must match DioApiClient + repository mappings)
  static const errorTimeout = 'error_timeout';
  static const errorNoInternet = 'error_no_internet';
  static const errorServer = 'error_server';
  static const errorRequestFailed = 'error_request_failed';
  static const errorNotFound = 'error_not_found';
  static const errorUnknown = 'error_unknown';

  // Torrent failure keys (must match torrent_streamer.ts error keys)
  static const torrentInvalidMagnet = 'torrent_invalid_magnet';
  static const torrentTimeout = 'torrent_timeout';
  static const torrentNoVideo = 'torrent_no_video';
  static const torrentFailed = 'torrent_failed';

  // Rooms list
  static const roomsTitle = 'rooms_title';
  static const roomsSubtitle = 'rooms_subtitle';
  static const roomsEmpty = 'rooms_empty';
  static const roomsEmptyHint = 'rooms_empty_hint';
  static const watching = 'watching'; // "<n> watching"
  static const noOneWatching = 'no_one_watching';
  static const passwordProtected = 'password_protected';
  static const externalBadge = 'external_badge';
  static const createRoom = 'create_room';

  // Discovery (search / filters / favorites)
  static const searchRooms = 'search_rooms';
  static const roomsNoResults = 'rooms_no_results';
  static const favorites = 'favorites';
  static const recent = 'recent';
  static const categoryAll = 'category_all';

  // Bottom navigation tabs
  static const roomsTab = 'rooms_tab';
  static const cinemaTab = 'cinema_tab';
  static const browseTab = 'browse_tab';
  static const favoritesTab = 'favorites_tab';
  static const youtubeTab = 'youtube_tab';
  static const tvTab = 'tv_tab';

  // Live TV (isolated YacineTV catalogue → on-device native player)
  static const tvTitle = 'tv_title';
  static const tvChannels = 'tv_channels';
  static const tvEmpty = 'tv_empty';
  static const tvLive = 'tv_live';
  static const tvChannelUnavailable = 'tv_channel_unavailable';
  static const tvCreateRoom = 'tv_create_room';
  static const tvPreviewFailed = 'tv_preview_failed';

  // Cinema (isolated EgyBest catalogue → on-device resolve → direct-download room)
  static const cinemaTitle = 'cinema_title';
  static const cinemaSearchHint = 'cinema_search_hint';
  static const cinemaNoResults = 'cinema_no_results';
  static const cinemaNoResultsHint = 'cinema_no_results_hint';
  static const cinemaChooseServer = 'cinema_choose_server';
  static const cinemaNoServers = 'cinema_no_servers';
  static const cinemaResolveFailed = 'cinema_resolve_failed';
  static const cinemaDirectFile = 'cinema_direct_file';
  static const cinemaStreamHost = 'cinema_stream_host';
  static const cinemaLoading = 'cinema_loading';
  static const cinemaUnavailable = 'cinema_unavailable';
  static const cinemaNoEpisodes = 'cinema_no_episodes';
  static const favoritesSourceImdb = 'favorites_source_imdb';
  static const favoritesSourceCinema = 'favorites_source_cinema';

  // YouTube search tab (isolated "search → server download" feature)
  static const youtubeSearchHint = 'youtube_search_hint';
  static const youtubeSearchPrompt = 'youtube_search_prompt';
  static const youtubeNoResults = 'youtube_no_results';
  static const youtubeUnavailable = 'youtube_unavailable';
  static const youtubeCreateRoom = 'youtube_create_room';

  // Favorites (saved movies/series)
  static const favoritesTitle = 'favorites_title';
  static const favoritesEmpty = 'favorites_empty';
  static const favoritesEmptyHint = 'favorites_empty_hint';

  // TopCinema (isolated direct-download "second way")
  static const topcinemaButton = 'topcinema_button';
  static const topcinemaChooseSource = 'topcinema_choose_source';
  static const topcinemaTitle = 'topcinema_title';
  static const topcinemaNameHint = 'topcinema_name_hint';
  static const topcinemaGo = 'topcinema_go';
  static const topcinemaNotFound = 'topcinema_not_found';
  static const topcinemaUnavailable = 'topcinema_unavailable';

  // iwaatch (isolated server-resolved direct-link "third way", movies only)
  static const iwaatchButton = 'iwaatch_button';
  static const iwaatchTitle = 'iwaatch_title';
  static const iwaatchNameHint = 'iwaatch_name_hint';
  static const iwaatchGo = 'iwaatch_go';
  static const iwaatchNotFound = 'iwaatch_not_found';
  static const iwaatchUnavailable = 'iwaatch_unavailable';

  // Browse (catalogue)
  static const browseTitle = 'browse_title';
  static const browseSearchHint = 'browse_search_hint';
  static const allGenres = 'all_genres';
  static const browseNoResults = 'browse_no_results';
  static const browseNoResultsHint = 'browse_no_results_hint';
  static const loadMore = 'load_more';
  static const browseSort = 'browse_sort';
  static const browseSortDefault = 'browse_sort_default';
  static const browseSortRelease = 'browse_sort_release';
  static const browseSortRating = 'browse_sort_rating';
  static const browseSortAscending = 'browse_sort_ascending';
  static const browseSortDescending = 'browse_sort_descending';
  static const torrentSearching = 'torrent_searching';
  static const torrentNotAvailable = 'torrent_not_available';

  // Source picker (episodes for series, qualities for movies)
  static const chooseEpisode = 'choose_episode';
  static const chooseSeason = 'choose_season';
  static const chooseQuality = 'choose_quality';
  static const season = 'season';
  static const fullSeason = 'full_season';
  static const collectionsPacks = 'collections_packs';
  static const otherSources = 'other_sources';

  // Categories
  static const category = 'category';
  static const categoryMovies = 'category_movies';
  static const categorySeries = 'category_series';
  static const categoryAnime = 'category_anime';
  static const categorySports = 'category_sports';
  static const categoryMusic = 'category_music';
  static const categoryGaming = 'category_gaming';
  static const categoryNews = 'category_news';
  static const categoryOther = 'category_other';

  // Share / invite
  static const share = 'share';
  static const shareRoom = 'share_room';
  static const copyLink = 'copy_link';
  static const linkCopied = 'link_copied';
  static const copy = 'copy';
  static const copied = 'copied';
  static const scanToJoin = 'scan_to_join';

  // Room / watch screen
  static const live = 'live';
  static const connecting = 'connecting';
  static const reconnecting = 'reconnecting';
  static const disconnected = 'disconnected';
  static const videoUnavailable = 'video_unavailable';
  static const waitingForViewers = 'waiting_for_viewers'; // someone buffering
  static const youAreBuffering = 'you_are_buffering';
  static const resync = 'resync';
  static const changeSource = 'change_source';
  static const leaveRoom = 'leave_room';
  static const deleteRoom = 'delete_room';
  static const roomDeleted = 'room_deleted';
  static const deleteRoomConfirm = 'delete_room_confirm';
  static const roomNotEmpty = 'room_not_empty';
  static const playbackSpeed = 'playback_speed';
  static const fullscreen = 'fullscreen';
  static const pictureInPicture = 'picture_in_picture';
  static const viewersTab = 'viewers_tab';
  static const chatTab = 'chat_tab';

  // Chat
  static const chatHint = 'chat_hint';
  static const chatEmpty = 'chat_empty';
  static const chatThrottled = 'chat_throttled';
  static const chatSending = 'chat_sending';
  static const chatRetry = 'chat_retry';
  static const chatReceived = 'chat_received';
  static const messages = 'messages';
  static const writing = 'writing';

  // Voice messages
  static const voiceSlideToCancel = 'voice_slide_to_cancel';
  static const voiceReleaseToCancel = 'voice_release_to_cancel';
  static const voiceMicPermission = 'voice_mic_permission';
  static const voiceHoldToRecord = 'voice_hold_to_record';
  static const voiceMessage = 'voice_message';

  // Presence join/leave toasts ("<name> joined" / "<name> left")
  static const userJoined = 'user_joined';
  static const userLeft = 'user_left';

  // Drawing on video
  static const draw = 'draw';

  // Reactions
  static const reactions = 'reactions';
  static const chooseReactions = 'choose_reactions';
  static const addEmoji = 'add_emoji';
  static const addEmojiHint = 'add_emoji_hint';

  // Voice (tap-to-talk)
  static const holdToTalk = 'hold_to_talk';
  static const tapToTalk = 'tap_to_talk';
  static const speaking = 'speaking';
  static const micPermissionDenied = 'mic_permission_denied';

  // Per-user touch lock (disables the video's tap layer; emoji/chat/mic stay on)
  static const lockControls = 'lock_controls';
  static const unlockControls = 'unlock_controls';

  // Subtitles
  static const addSubtitle = 'add_subtitle';
  static const subtitleAdded = 'subtitle_added';
  static const subtitleExternalOnly = 'subtitle_external_only';

  // Subtitle display settings (shared across the room)
  static const subtitleSettings = 'subtitle_settings';
  static const subtitleTiming = 'subtitle_timing';
  static const subtitleTimingHint = 'subtitle_timing_hint';
  static const subtitleEarlier = 'subtitle_earlier';
  static const subtitleLater = 'subtitle_later';
  static const subtitleInSync = 'subtitle_in_sync';
  static const subtitleThickness = 'subtitle_thickness';
  static const subtitleSize = 'subtitle_size';
  static const reset = 'reset';

  // Offline cache (videos downloaded to this device)
  static const cachedVideos = 'cached_videos';
  static const cachedVideosEmpty = 'cached_videos_empty';
  static const cachedVideosEmptyHint = 'cached_videos_empty_hint';
  static const downloadForOffline = 'download_for_offline';
  static const savedOffline = 'saved_offline';
  static const downloadPaused = 'download_paused';
  static const downloadFailed = 'download_failed';
  static const pause = 'pause';
  static const resume = 'resume';
  static const deleteDownload = 'delete_download';
  static const deleteDownloadConfirm = 'delete_download_confirm';
  static const deleteAll = 'delete_all';
  static const deleteAllConfirm = 'delete_all_confirm';
  static const storageUsed = 'storage_used';

  // Server operations (transfers) panel
  static const operationsTitle = 'operations_title';
  static const operationsEmpty = 'operations_empty';
  static const operationsClearFinished = 'operations_clear_finished';
  static const operationDone = 'operation_done';
  static const operationCanceled = 'operation_canceled';
  static const operationKindDownload = 'operation_kind_download';
  static const operationKindTorrent = 'operation_kind_torrent';
  static const operationKindMagnet = 'operation_kind_magnet';
  static const operationKindUpload = 'operation_kind_upload';

  // Online subtitles (OpenSubtitles search)
  static const downloadSubtitle = 'download_subtitle';
  static const subtitleLanguage = 'subtitle_language';
  static const subtitlesSearching = 'subtitles_searching';
  static const subtitlesNoResults = 'subtitles_no_results';
  static const subtitleImdbHint = 'subtitle_imdb_hint';
  static const subtitleSeasonHint = 'subtitle_season_hint';
  static const subtitleEpisodeHint = 'subtitle_episode_hint';
  static const subtitleApplyFailed = 'subtitle_apply_failed';

  // Create room
  static const createRoomTitle = 'create_room_title';
  static const roomName = 'room_name';
  static const roomNameHint = 'room_name_hint';
  static const sourceType = 'source_type';
  static const typeExternal = 'type_external';
  static const typeExternalDesc = 'type_external_desc';
  static const typeDownload = 'type_download';
  static const typeDownloadDesc = 'type_download_desc';
  static const typeUpload = 'type_upload';
  static const typeUploadDesc = 'type_upload_desc';
  static const typeTorrent = 'type_torrent';
  static const typeTorrentDesc = 'type_torrent_desc';
  static const typeYoutube = 'type_youtube';
  static const typeYoutubeDesc = 'type_youtube_desc';
  static const typeTelegram = 'type_telegram';
  static const typeTelegramDesc = 'type_telegram_desc';
  static const externalUrl = 'external_url';
  static const externalUrlHint = 'external_url_hint';
  static const videoUrl = 'video_url';
  static const videoUrlHint = 'video_url_hint';
  static const magnetUrl = 'magnet_url';
  static const magnetUrlHint = 'magnet_url_hint';
  static const youtubeLink = 'youtube_link';
  static const youtubeLinkHint = 'youtube_link_hint';
  static const telegramLink = 'telegram_link';
  static const telegramLinkHint = 'telegram_link_hint';
  static const pickVideo = 'pick_video';
  static const password = 'password';
  static const passwordOptionalHint = 'password_optional_hint';
  static const creatingRoom = 'creating_room';
  static const downloadingVideo = 'downloading_video';
  static const preparingTorrent = 'preparing_torrent';
  static const uploadingVideo = 'uploading_video';
  static const changeSourceUrlHint = 'change_source_url_hint';

  // Unlock
  static const enterPassword = 'enter_password';
  static const unlock = 'unlock';
  static const incorrectPassword = 'incorrect_password';

  // Identity
  static const yourName = 'your_name';
  static const enterName = 'enter_name';
  static const anonymous = 'anonymous';

  // Settings
  static const settings = 'settings';
  static const theme = 'theme';
  static const language = 'language';
  static const server = 'server';
  static const serverHint = 'server_hint';
  static const serverDefaultLabel = 'server_default_label';
  static const serverInvalid = 'server_invalid';
  static const serverChangedRestart = 'server_changed_restart';
  static const resetToDefault = 'reset_to_default';
  static const appVersion = 'app_version';

  // In-app updates (sideloaded APK self-update)
  static const updateAvailable = 'update_available';
  static const updateDownload = 'update_download';
  static const updateDownloading = 'update_downloading';
  static const updateInstall = 'update_install';
  static const updateLater = 'update_later';
  static const updateError = 'update_error';
  static const updatePermissionDenied = 'update_permission_denied';
  static const updateRequiredTitle = 'update_required_title';
  static const updateRequiredBody = 'update_required_body';
  static const updateInstallHint = 'update_install_hint';

  // Bookmarks
  static const addBookmark = 'add_bookmark';
  static const bookmarkSaved = 'bookmark_saved';
  static const bookmarks = 'bookmarks';
  static const bookmarkName = 'bookmark_name';
  static const bookmarkNameHint = 'bookmark_name_hint';
  static const noBookmarks = 'no_bookmarks';
}
