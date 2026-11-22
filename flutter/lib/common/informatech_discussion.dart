// InformaTech (Adrien's V1 answers, 22/11, via Luffy): the raw OPMD chat is hidden on the Android viewer while OPMD is
// 0.x; a chat comes back in the Hub banner after V1. `true` brings the upstream chat back (one line).

/// Whether the Android viewer offers OPMD's own chat: the « Discussion » tool of the session bar, and the chat window a
/// message from the PC would open.
const bool kInformatechDiscussion = false;

/// Whether a chat message received by the viewer may open the chat window on the phone (Android, client mode only).
/// Pure, so the rule is tested without a session.
bool informatechChatOuvrable({required bool android, required bool modeClient}) =>
    kInformatechDiscussion || !(android && modeClient);

/// Scylla P4 (22/11): whether the connection window on the client's PC shows its chat button for a connection. Hidden
/// in 0.x, so the client never types into a chat that a phone technician cannot read (the message would be dropped and
/// the client might think « arrêtez » was read). The file-transfer button of a file connection is not the chat. A
/// message from a desktop viewer still opens the chat page there, as upstream does, so the client can answer it.
bool informatechBoutonChatCm({required bool fichier}) => fichier || kInformatechDiscussion;
