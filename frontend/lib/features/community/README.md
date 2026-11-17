# Community module (frontend) — Module 3

Module 3 (Communication + Community) is split across three feature folders,
each following the Marketplace layout (models/ services/ providers/ screens/ widgets/):

| Folder | What it holds |
|---|---|
| `features/community/` | Feed, post details + comments, create/edit post, likes. Also the shared Module 3 bits: `UserBrief`, `PageResult`, `ViewStatus`, `community_labels.dart` (enum labels, date formatting, error text). |
| `features/chat/` | Conversations list and chat screen. `chat_launcher.dart` exposes `openChatWith(context, userId, listingId: ...)` for other modules (e.g. a "Chat with seller" button). |
| `features/issue_reports/` | `showReportDialog(context, type, id)` (usable from any screen) and the admin reports screen. |

Chat has no websockets: `ChatProvider` and `ChatScreen` poll the API at the
interval the backend advertises (`CHAT_POLL_INTERVAL_SECONDS`, default 5 s).

All strings live in `lib/shared/l10n/app_{en,si,ta}.arb`; run
`flutter gen-l10n` after editing them.
