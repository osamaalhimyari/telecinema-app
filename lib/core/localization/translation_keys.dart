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
  static const browseTab = 'browse_tab';
  static const favoritesTab = 'favorites_tab';

  // Favorites (saved movies/series)
  static const favoritesTitle = 'favorites_title';
  static const favoritesEmpty = 'favorites_empty';
  static const favoritesEmptyHint = 'favorites_empty_hint';

  // TopCinema (isolated direct-download "second way")
  static const topcinemaButton = 'topcinema_button';
  static const topcinemaTitle = 'topcinema_title';
  static const topcinemaNameHint = 'topcinema_name_hint';
  static const topcinemaGo = 'topcinema_go';
  static const topcinemaNotFound = 'topcinema_not_found';
  static const topcinemaUnavailable = 'topcinema_unavailable';

  // Browse (catalogue)
  static const browseTitle = 'browse_title';
  static const browseSearchHint = 'browse_search_hint';
  static const allGenres = 'all_genres';
  static const browseNoResults = 'browse_no_results';
  static const browseNoResultsHint = 'browse_no_results_hint';
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
  static const messages = 'messages';

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

  // Online subtitles (OpenSubtitles search)
  static const downloadSubtitle = 'download_subtitle';
  static const subtitleLanguage = 'subtitle_language';
  static const subtitlesSearching = 'subtitles_searching';
  static const subtitlesNoResults = 'subtitles_no_results';
  static const subtitleTitleHint = 'subtitle_title_hint';
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
  static const externalUrl = 'external_url';
  static const externalUrlHint = 'external_url_hint';
  static const videoUrl = 'video_url';
  static const videoUrlHint = 'video_url_hint';
  static const magnetUrl = 'magnet_url';
  static const magnetUrlHint = 'magnet_url_hint';
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
}
