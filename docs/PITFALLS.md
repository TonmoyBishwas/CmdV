# Pitfalls & Common Traps

Every one of these was actually hit while building v1.0.0. Check here **before**
debugging from scratch — the symptom you're seeing is probably in this list.
Format: symptom → cause → fix.

## Permissions & signing (TCC)

### Accessibility permission keeps disappearing
- **Symptom**: auto-paste stops working after a rebuild; `AXIsProcessTrusted()` returns
  false even though CmdV is listed in System Settings → Accessibility.
- **Cause**: TCC keys the grant to the app's code-signing identity. Ad-hoc signatures
  (`-`) change on **every build**, so every rebuild invalidates the grant.
- **Fix (dev)**: re-toggle CmdV in System Settings, or `tccutil reset Accessibility
  com.tonmoybishwas.CmdV` and re-grant. **Fix (real)**: a stable signing identity —
  the self-signed "CmdV Signing" cert (`scripts/dev-sign-setup.sh`) or Developer ID.

### Self-signed certificate cannot be created headlessly
- **Symptom**: certs created via `security`/`openssl` CLI show
  `CSSMERR_TP_NOT_TRUSTED` and `security find-identity -p codesigning` reports
  0 valid identities.
- **Cause**: macOS requires the cert to be *trusted for code signing*, which needs an
  interactive admin dialog. There is no headless path.
- **Fix**: Keychain Access → Certificate Assistant (30 s, GUI). `dev-sign-setup.sh`
  walks the user through it; `release.sh` auto-detects the cert once it exists.
  Don't burn time trying to automate this — it was verified impossible.

### Can't verify UI or send keystrokes from the agent shell
- **Symptom**: `osascript ... keystroke` fails with "not allowed to send keystrokes",
  `screencapture` produces a black/empty image.
- **Cause**: the terminal lacks Accessibility / Screen Recording TCC grants, and
  granting them needs the GUI.
- **Fix**: don't fight TCC. Use the built-in headless hooks instead — Darwin
  notifications (`notifyutil -p com.tonmoybishwas.CmdV.toggleShelf` /
  `.togglePasteStack`), `log stream`, and read-only sqlite3 peeks at the store
  (recipes in CLAUDE.md). Anything genuinely visual needs the user's eyes.

## Swift 6 strict concurrency

### `kAXTrustedCheckOptionPrompt` — "not concurrency-safe"
- **Cause**: the C global isn't `Sendable`.
- **Fix**: use the literal string `"AXTrustedCheckOptionPrompt"` as the dictionary key
  (already done in `AccessibilityPermission.swift` with a comment). The literal is the
  key's actual value; behavior is identical.

### QLPreviewPanel delegate/dataSource conformance errors
- **Symptom**: "main-actor-isolated method cannot satisfy nonisolated protocol
  requirement" on `QLPreviewPanelDataSource`/`Delegate`.
- **Fix**: conform with `@preconcurrency QLPreviewPanelDataSource` (see
  `QuickLookPreview.swift`).

### "'async' call in an autoclosure that is not marked async"
- **Symptom**: `cached ?? (await fetch())` fails to compile — `??`'s right side is an
  autoclosure.
- **Fix**: restructure into explicit `if let ... else { await ... }`.

## Build system & tooling

### SourceKit "Cannot find type 'X' in scope" everywhere after adding a file
- **Cause**: the committed `.xcodeproj` is *generated*; a new file isn't in it yet, so
  editor diagnostics go red. These are **not real errors**.
- **Fix**: `make gen`, then trust `make build` output only. Never hand-edit the pbxproj.

### Test target fails codesigning: "does not have an Info.plist"
- **Cause**: XcodeGen doesn't synthesize one for the test bundle by default.
- **Fix**: `GENERATE_INFOPLIST_FILE: YES` in the CmdVTests settings in `project.yml`
  (already present — don't remove it).

### `log show` / `log stream` shows nothing from CmdV
- **Cause**: the app logs at `.info` level; the `log` tool drops info/debug messages
  unless explicitly asked.
- **Fix**: always pass `--info`:
  `log stream --info --predicate 'subsystem == "com.tonmoybishwas.CmdV"'`.

### create-dmg "fails" with exit code 2
- **Cause**: create-dmg exits 2 for success-with-warnings (e.g. no code-sign of the DMG).
- **Fix**: `make-dmg.sh` already tolerates it (`|| [ -f "$OUT" ]`) and falls back to
  plain `hdiutil` UDZO if create-dmg is missing. Check the DMG exists before declaring
  failure.

### zsh scripting differences
- **Symptom**: loops using `set -- $spec` style word-splitting silently do nothing.
- **Cause**: zsh doesn't word-split unquoted variables like bash.
- **Fix**: scripts use `#!/usr/bin/env bash` with explicit commands; for ad-hoc shell,
  prefer explicit per-item commands or write an actual `.sh` file (compound one-liners
  with redirects also parsed badly in the interactive zsh).

## Runtime logic traps

### Paste Stack triggers itself in an infinite loop
- **Symptom**: one ⌘V during an active stack pastes several entries or loops.
- **Cause**: the stack claims ⌘V as a hotkey, then *sends a synthetic ⌘V* — which the
  hotkey itself would swallow/re-trigger.
- **Fix** (in `PasteStackController`): pop entry → copy → **unbind `.stackPaste`** →
  send synthetic ⌘V → re-arm after 0.3 s (or deactivate when empty). Also clear any
  stale `.stackPaste` binding at launch (a crash while active would otherwise leave ⌘V
  permanently claimed). Preserve this dance if you touch the stack.

### CmdV records its own pastes as new history items
- **Cause**: writing to the pasteboard bumps `changeCount`; the monitor sees it as a
  fresh copy. Registering the expectation *after* writing is a race — the poll can fire
  in between.
- **Fix**: `PasteEngine` calls `monitor.expectSelfCopy()` (registers the expected
  changeCount) **synchronously before** `NSPasteboard.clearContents()/write`. Keep that
  ordering.

### Shelf steals focus and paste lands nowhere
- **Cause**: anything that activates the app (`NSApp.activate()`, a regular NSWindow,
  `canBecomeMain = true`) makes CmdV frontmost, so ⌘V goes to CmdV instead of the
  target app.
- **Fix**: the panel recipe in `ShelfPanel.swift` (`.nonactivatingPanel`,
  `canBecomeKey = true`, `canBecomeMain = false`, `.floating`) and the
  hide → re-activate previous app → 0.12 s delay → paste sequence in
  `ShelfPanelController`. Don't "simplify" any of it.

### App state initialized twice
- **Symptom**: two monitors polling, duplicate captures.
- **Cause**: `@main` struct had both a property initializer and an `init` creating
  `AppState`.
- **Fix**: single `_appState = State(initialValue: state)` in `CmdVApp.init`.

### Glass effects tank scrolling performance
- **Rules learned**: one `GlassEffectContainer` for the card strip; `LazyHStack`;
  pre-rendered thumbnails at capture time (never full images in cards);
  `glassEffectID` morph animations **only** in the small stack overlay.

## Verification honesty

`make build` + `make test` + headless hooks prove logic, capture, and state. They do
**not** prove: Liquid Glass appearance, paste-at-cursor into real apps, Quick Look
rendering, drag-out. When only headless checks ran, report exactly that and list what
still needs the user's hands.
