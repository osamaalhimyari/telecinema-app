/// A broad set of reaction emoji shown in the floating picker grid and the
/// create-room palette.
///
/// Kept to widely-supported single codepoints / common sequences so they render
/// across devices, and ordered in groups of six so each row reads cleanly.
const List<String> kReactionEmojis = <String>[
  // smileys / positive
  '😂', '🤣', '😅', '😊', '😍', '🥰',
  '😘', '😎', '🤩', '🥳', '😜', '🤪',
  '😇', '🙂', '😉', '😌', '😏', '🤔',
  '🤨', '😐', '😴', '😋', '🤗', '🤭',
  // negative / shock
  '🥺', '😢', '😭', '😤', '😠', '😡',
  '🤬', '😱', '😨', '😰', '😓', '🤯',
  '😳', '🥶', '🥵', '🤢', '🤮', '🤧',
  '😷', '🤒', '💀', '👻', '🤡', '👽',
  // gestures
  '👍', '👎', '👏', '🙌', '🙏', '💪',
  '👀', '🔥', '✨', '💯', '⚡', '💥',
  // hearts
  '❤️', '🧡', '💛', '💚', '💙', '💜',
  '🖤', '💔', '💖', '💕', '💘', '💝',
  // party / misc
  '🎉', '🎊', '🎈', '🌟', '⭐', '🍿',
  '🍆', '🎵', '❓', '❗', '💩', '🤝',
];
