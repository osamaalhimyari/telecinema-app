import '../translation_keys.dart';

const Map<String, String> enUs = {
  TranslationKeys.appName: 'TeleCinema',

  TranslationKeys.retry: 'Retry',
  TranslationKeys.cancel: 'Cancel',
  TranslationKeys.create: 'Create',
  TranslationKeys.delete: 'Delete',
  TranslationKeys.close: 'Close',
  TranslationKeys.save: 'Save',
  TranslationKeys.ok: 'OK',

  TranslationKeys.errorTimeout: 'The server took too long to respond.',
  TranslationKeys.errorNoInternet: 'No internet connection.',
  TranslationKeys.errorServer: 'Something went wrong on the server.',
  TranslationKeys.errorRequestFailed: 'The request could not be completed.',
  TranslationKeys.errorNotFound: 'Not found.',
  TranslationKeys.errorUnknown: 'Something went wrong.',

  TranslationKeys.torrentInvalidMagnet:
      'That does not look like a valid magnet link.',
  TranslationKeys.torrentTimeout:
      'Could not find any peers for that magnet. Try another.',
  TranslationKeys.torrentNoVideo:
      'No playable video was found in that torrent.',
  TranslationKeys.torrentFailed: 'That torrent could not be opened.',

  TranslationKeys.roomsTitle: 'TeleCinema',
  TranslationKeys.roomsSubtitle: 'Pick a room and watch together, in sync.',
  TranslationKeys.roomsEmpty: 'No rooms yet',
  TranslationKeys.roomsEmptyHint:
      'Create the first room to start watching together.',
  TranslationKeys.watching: 'watching',
  TranslationKeys.noOneWatching: 'No one watching',
  TranslationKeys.passwordProtected: 'Password protected',
  TranslationKeys.externalBadge: 'Embed',
  TranslationKeys.createRoom: 'Create room',

  TranslationKeys.searchRooms: 'Search rooms',
  TranslationKeys.roomsNoResults: 'No rooms match your search.',
  TranslationKeys.favorites: 'Favorites',
  TranslationKeys.recent: 'Recent',
  TranslationKeys.categoryAll: 'All',

  TranslationKeys.roomsTab: 'Rooms',
  TranslationKeys.browseTab: 'Browse',

  TranslationKeys.browseTitle: 'Browse',
  TranslationKeys.browseSearchHint: 'Search movies & series',
  TranslationKeys.allGenres: 'All genres',
  TranslationKeys.browseNoResults: 'Nothing found',
  TranslationKeys.browseNoResultsHint: 'Try a different title, category or genre.',
  TranslationKeys.torrentSearching: 'Looking for a torrent…',
  TranslationKeys.torrentNotAvailable: 'Not available currently',

  TranslationKeys.chooseEpisode: 'Choose an episode',
  TranslationKeys.chooseQuality: 'Choose a version',
  TranslationKeys.season: 'Season',
  TranslationKeys.fullSeason: 'Full season',
  TranslationKeys.collectionsPacks: 'Collections & packs',
  TranslationKeys.otherSources: 'Other',

  TranslationKeys.category: 'Category',
  TranslationKeys.categoryMovies: 'Movies',
  TranslationKeys.categorySeries: 'TV Shows',
  TranslationKeys.categoryAnime: 'Anime',
  TranslationKeys.categorySports: 'Sports',
  TranslationKeys.categoryMusic: 'Music',
  TranslationKeys.categoryGaming: 'Gaming',
  TranslationKeys.categoryNews: 'News',
  TranslationKeys.categoryOther: 'Other',

  TranslationKeys.share: 'Share',
  TranslationKeys.shareRoom: 'Share room',
  TranslationKeys.copyLink: 'Copy link',
  TranslationKeys.linkCopied: 'Link copied',
  TranslationKeys.scanToJoin: 'Scan to join',

  TranslationKeys.live: 'LIVE',
  TranslationKeys.connecting: 'Connecting…',
  TranslationKeys.reconnecting: 'Reconnecting…',
  TranslationKeys.disconnected: 'Disconnected',
  TranslationKeys.videoUnavailable: 'Video file not found',
  TranslationKeys.waitingForViewers: 'Waiting for slow viewers…',
  TranslationKeys.youAreBuffering: 'Buffering…',
  TranslationKeys.resync: 'Resync',
  TranslationKeys.changeSource: 'Change source',
  TranslationKeys.leaveRoom: 'Leave room',
  TranslationKeys.deleteRoom: 'Delete room',
  TranslationKeys.roomDeleted: 'This room was deleted.',
  TranslationKeys.deleteRoomConfirm:
      'Delete this room and its video? This cannot be undone.',
  TranslationKeys.roomNotEmpty:
      'Someone is still watching — wait until the room is empty.',
  TranslationKeys.playbackSpeed: 'Playback speed',
  TranslationKeys.fullscreen: 'Fullscreen',
  TranslationKeys.pictureInPicture: 'Picture in picture',
  TranslationKeys.viewersTab: 'Viewers',
  TranslationKeys.chatTab: 'Chat',

  TranslationKeys.chatHint: 'Say something…',
  TranslationKeys.chatEmpty: 'No messages yet. Be the first to say hi 👋',
  TranslationKeys.chatThrottled: 'You\'re sending messages too fast.',
  TranslationKeys.messages: 'Messages',

  TranslationKeys.reactions: 'Reactions',
  TranslationKeys.chooseReactions: 'Pick 8 reactions for this room',
  TranslationKeys.addEmoji: 'Add emoji',
  TranslationKeys.addEmojiHint: 'Type or pick an emoji',

  TranslationKeys.holdToTalk: 'Hold to talk',
  TranslationKeys.tapToTalk: 'Tap to talk',
  TranslationKeys.speaking: 'speaking',
  TranslationKeys.micPermissionDenied: 'Microphone permission denied.',

  TranslationKeys.addSubtitle: 'Add subtitle',
  TranslationKeys.subtitleAdded: 'Subtitle added.',
  TranslationKeys.subtitleExternalOnly:
      'Subtitles are only available for embed rooms.',

  TranslationKeys.downloadSubtitle: 'Download subtitle',
  TranslationKeys.subtitleLanguage: 'Subtitle language',
  TranslationKeys.subtitlesSearching: 'Searching subtitles…',
  TranslationKeys.subtitlesNoResults: 'No subtitles found for this language.',
  TranslationKeys.subtitleTitleHint: 'Title to search',
  TranslationKeys.subtitleApplyFailed: 'That subtitle could not be applied.',

  TranslationKeys.createRoomTitle: 'Create a room',
  TranslationKeys.roomName: 'Room name',
  TranslationKeys.roomNameHint: 'e.g. Movie night',
  TranslationKeys.sourceType: 'Video source',
  TranslationKeys.typeExternal: 'Embed link',
  TranslationKeys.typeExternalDesc:
      'Play a third-party stream inside the room.',
  TranslationKeys.typeDownload: 'Download from link',
  TranslationKeys.typeDownloadDesc:
      'The server fetches the video file for you.',
  TranslationKeys.typeUpload: 'Upload a file',
  TranslationKeys.typeUploadDesc: 'Upload a video from this device.',
  TranslationKeys.typeTorrent: 'Magnet / Torrent',
  TranslationKeys.typeTorrentDesc:
      'Stream a video from a magnet link — no full download.',
  TranslationKeys.externalUrl: 'Embed URL',
  TranslationKeys.externalUrlHint: 'https://…',
  TranslationKeys.videoUrl: 'Video link',
  TranslationKeys.videoUrlHint: 'Direct link to an .mp4 / .webm file',
  TranslationKeys.magnetUrl: 'Magnet link',
  TranslationKeys.magnetUrlHint: 'magnet:?xt=urn:btih:…',
  TranslationKeys.pickVideo: 'Choose a video',
  TranslationKeys.password: 'Password',
  TranslationKeys.passwordOptionalHint:
      'Optional — leave blank for an open room',
  TranslationKeys.creatingRoom: 'Creating room…',
  TranslationKeys.downloadingVideo: 'Downloading video…',
  TranslationKeys.preparingTorrent: 'Finding peers & preparing stream…',
  TranslationKeys.uploadingVideo: 'Uploading…',
  TranslationKeys.changeSourceUrlHint: 'Paste the next embed URL',

  TranslationKeys.enterPassword: 'This room is password protected.',
  TranslationKeys.unlock: 'Unlock',
  TranslationKeys.incorrectPassword: 'Incorrect password.',

  TranslationKeys.yourName: 'Your name',
  TranslationKeys.enterName: 'What should we call you?',
  TranslationKeys.anonymous: 'Anonymous',

  TranslationKeys.settings: 'Settings',
  TranslationKeys.theme: 'Theme',
  TranslationKeys.language: 'Language',
  TranslationKeys.server: 'Server',
  TranslationKeys.serverHint: 'https://your-server.com',
  TranslationKeys.serverDefaultLabel: 'Default',
  TranslationKeys.serverInvalid: 'Enter a valid http(s) URL.',
  TranslationKeys.serverChangedRestart: 'Server updated — restart the app to apply.',
  TranslationKeys.resetToDefault: 'Reset to default',
};
