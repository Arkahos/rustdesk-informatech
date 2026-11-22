// InformaTech (Adrien's V1 answers, 22/11, via Luffy): the raw OPMD chat is hidden on the Android viewer while OPMD is
// 0.x; a chat comes back in the Hub banner after V1. `true` brings the upstream chat back (one line).

/// Whether the Android viewer offers OPMD's own chat: the « Discussion » tool of the session bar, and the chat window a
/// message from the PC would open.
const bool kInformatechDiscussion = false;

/// Whether a chat message received by the viewer may open the chat window on the phone (Android, client mode only).
/// Pure, so the rule is tested without a session.
bool informatechChatOuvrable({required bool android, required bool modeClient}) =>
    kInformatechDiscussion || !(android && modeClient);
