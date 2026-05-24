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
  static const viewersTab = 'viewers_tab';
  static const chatTab = 'chat_tab';

  // Chat
  static const chatHint = 'chat_hint';
  static const chatEmpty = 'chat_empty';
  static const chatThrottled = 'chat_throttled';

  // Reactions
  static const reactions = 'reactions';

  // Voice (push-to-talk)
  static const holdToTalk = 'hold_to_talk';
  static const speaking = 'speaking';
  static const micPermissionDenied = 'mic_permission_denied';

  // Subtitles
  static const addSubtitle = 'add_subtitle';
  static const subtitleAdded = 'subtitle_added';
  static const subtitleExternalOnly = 'subtitle_external_only';

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
  static const externalUrl = 'external_url';
  static const externalUrlHint = 'external_url_hint';
  static const videoUrl = 'video_url';
  static const videoUrlHint = 'video_url_hint';
  static const pickVideo = 'pick_video';
  static const password = 'password';
  static const passwordOptionalHint = 'password_optional_hint';
  static const creatingRoom = 'creating_room';
  static const downloadingVideo = 'downloading_video';
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
}
