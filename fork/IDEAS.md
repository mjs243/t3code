# T3 Code fork — improvement ideas

Started 2026-10-06. Fork: `mjs243/t3code`, branch `malik`. Upstream: `pingdotgg/t3code` (MIT), ~360 commits/week.
`main` is an untouched mirror of upstream; everything personal lives on `malik`. `fork/sync-upstream.sh` runs nightly.

Each idea records the moment it came from (thread date) so it can be re-read in context.
Priority: **P0** = hurt a live trade · **P1** = daily friction · **P2** = nice-to-have.
Route: **fork** = personal change, keep here · **upstream** = generic enough for a bug report / Ideas discussion first.

## P0 — cost a trade or a decision

### 1. The "Worked for …" fold hides assistant text written before a tool call

- **Said:** 9/13 _"fuck i didn't see the note to not take it on #2 -- the 'work' gets collapsed, so i miss it"_ (Funded #2 died on that fill). 9/22 _"I can't see what you produced" / "I keep missing output"_ twice (row 352 trigger block).
- **Today's workaround:** Claude runs tools first and writes the block last (memory `t3-final-message-only`); account line inside the block.
- **Idea:** a setting that folds only tool/activity rows and keeps every assistant _message_ visible in a settled turn. Alternative: never fold a message that contains a table or a bold price/`ACCOUNTS:` line. At minimum, the fold header should show how many assistant messages are hidden ("Worked for 3m · 2 messages"), not just the duration.
- **Code:** `apps/web/src/components/chat/MessagesTimeline.logic.ts` → `deriveTurnFolds` (~L863–1049); mobile mirror `apps/mobile/src/lib/threadActivity.ts`.
- **Route:** fork first (one boolean in the fold derivation), then propose upstream as a config option ("focused configuration option for an established capability" is an allowed PR class in their CONTRIBUTING).
- **Status:** shipped on `malik` 2026-10-07 (`foldWorkOnly`, off by default). Web: Settings → General → Behavior → "Keep messages out of work folds". Mobile: Settings → Thread behavior → Beta. The "· 2 messages" header count is not done.

### 2. Readability — "a sea of greyish text on a black background"

- **Said:** 9/28 D-alt (a written 2.0R winner) was missed in the thread; readability named as the bottleneck; dashboard tried and abandoned. 9/26 asked to try rendered markdown tables instead of fenced code.
- **Idea:** a high-contrast reading theme: brighter body text, bold rendered heavier, table borders visible, a highlight style for `####` trigger headers. Possibly a "focus" mode that renders only the final assistant message of each turn full-width.
- **Code:** web theme/Tailwind tokens (`apps/web/vite/tailwind.ts`, theme CSS); `apps/server/src/environmentTheme.ts` suggests per-environment theming already exists.
- **Route:** fork.

### 3. Notifications that survive the mobile connection dropping

- **Said:** 9/2 _"any other ideas for notifications?"_ (audio cue mentioned); 10/05 _"T3 mobile drops the connection; zero notifications"_ → built `Trading/tools/away-push.py` (ntfy via a Claude Code Stop hook); 10/06 asked about iMessage as an alternative because the mobile app's link to the Mac server isn't consistent.
- **Idea:** server-side push on the _final_ assistant message of a turn (and on `waiting`/permission requests) via a pluggable sink: ntfy topic, webhook URL, or APNs through T3 Connect. Fires from the server, so it doesn't need the phone's socket to be alive. Per-project filter (regex on the first line, e.g. trigger blocks only) so it stays quiet during build work.
- **Code:** `apps/server/src/relay/AgentAwarenessRelay.ts`, `apps/mobile/src/features/settings/SettingsNotificationsRouteScreen.tsx` (currently gated on T3 Connect).
- **Route:** fork; the generic "webhook on turn complete" is worth an upstream Ideas post.

## P1 — daily friction

### 4. Find-in-thread (Ctrl+F)

- **Said:** 8/29 _"T3 Code doesn't have a Ctrl+F find/search within threads, so i'm at a loss."_
- **Now:** global thread search exists (command palette / sidebar, `apps/web/src/state/queries.ts`), bounded, cross-thread. No in-thread find with match navigation, and the fold hides matches inside collapsed work.
- **Idea:** Ctrl+F opens an in-thread find bar; matches inside folds auto-unfold; mobile gets the same under the thread menu.
- **Route:** fork, then upstream Ideas.

### 5. Mobile ↔ desktop history out of sync / partial load

- **Said:** 8/8 _"signed into T3 Code from mobile and it's not syncing all of our context"_; 10/01 _"T3 Code mobile doesn't fully load conversations … last visible message is from 1:18pm"_; 10/01 _"not sure why iOS messages aren't in sync with desktop."_
- **Idea:** reproduce against `threadHistoryPaging` / `boundedThreadSnapshotHttp`; likely a paging/resume gap after a dropped socket. A visible "history incomplete — tap to reload" state would beat silent truncation.
- **Code:** `packages/client-runtime/src/state/threadHistoryController.ts`, `threadHistoryMerge.ts`, `apps/server/src/orchestration-v2/threadHistoryPaging.ts`.
- **Route:** upstream bug report (with repro) — this is a reliability fix, their most-welcome class.

### 6. Reconnect robustness on mobile

- **Said:** 10/06 _"sustaining the connection to the Mac server's T3 Code isn't consistent in the T3 Code mobile app."_
- **Idea:** measure first (how long until reconnect after backgrounding; does Tailscale vs LAN matter), then: aggressive resume on foreground, catch-up fetch of missed items, connection-state banner.
- **Route:** upstream bug report after measurement.

### 7. Provider re-auth surfaced late

- **Said:** 9/4 _"had to reauthenticate into claude, an annoyance with T3 Code"_ (missed a trade during a meeting); 9/17 _"reauthenticated, try again."_
- **Idea:** detect Claude Code auth expiry before a turn fails (a cheap probe at server start and hourly), show it in the thread header, and push it through the notification sink from idea 3. Document the `claude auth login` path from the Mac server when driving from Windows/phone.
- **Route:** fork probe + upstream Ideas.

### 8. Device cue on prompts

- **Said:** 9/2 _"we might want to consider appending a cue to signal to you what device I'm messaging from → to do list."_
- **Idea:** server tags each user message with the client kind (desktop / web / mobile) and the agent sees it (system-reminder or prompt suffix). Lets the agent shorten replies on mobile and skip visuals that don't render there.
- **Route:** fork. Small: client already identifies itself at pairing.

### 9. Custom / backup models in the provider list

- **Said:** 9/29 Theo demoed GLM 5.3 Flash via Codex inside T3 Code; _"think we can add some of our backups there?"_ The repo's delegate skill routes to opencode `zai/glm-5.3-flash`, `openai/gpt-5.6-sol`, `gpt-6-astra/sol/luna`.
- **Idea:** config-file entries for custom Codex/OpenCode models so they show in the composer and in `orchestrator_capabilities`. Check `apps/server/src/codexModelOptions.ts` / `claudeModelOptions.ts` first — this may already be supported and only need documenting for our setup.
- **Route:** configuration first; fork only if the UI needs it.

## P2 — nice to have

### 10. Headless Mac-server mode documented for this setup

- **Said:** 9/15 _"spin up a T3 Code CLI instance that I can connect to via Tailscale instead of the desktop application."_ The Mac is a server; work happens from the Windows PC and phone.
- **Now:** `t3 service install` + Tailscale sharing exist. Write our own runbook in `fork/` (service plist, ports, pairing, what breaks on reboot).

### 11. Secrets / key rotation UI

- **Said:** 9/14 _"how do I actually set the keys myself? should consider an interface/TUI/GUI for updating and rotating keys."_
- **Now:** `request_secret` exists for one-shot secrets. Idea: a settings page listing provider keys/env with last-rotated dates. Low priority.

### 12. Audio cue on turn complete (desktop/web)

- **Said:** 9/2, in passing. Trivial once idea 3's "turn complete" event exists.

## Not T3's problem (recorded so they aren't re-raised here)

- Trigger IDs as letters read as grades · account line placement · markdown-vs-code blocks — these are reply-format rules on Claude's side and live in `Trading/CLAUDE.md` + memory.

## Process

- Keep patches small and behind settings; the smaller the diff, the cheaper the nightly rebase.
- Anything generic → open an Ideas discussion upstream before building big; their CONTRIBUTING requires prior approval for features and says reliability fixes are the most welcome.
- When a fork idea lands upstream, drop our patch and let the rebase take theirs.
