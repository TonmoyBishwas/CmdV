# CLAUDE.md

CmdV is a **free, open-source clipboard manager for macOS** — a feature clone of the paid
Paste app (pasteapp.io) minus its AI/cloud features. Apple Silicon only, macOS 26.0+ only,
native Liquid Glass UI, GPL-3.0. Repo and releases: https://github.com/TonmoyBishwas/CmdV
(v1.0.0 shipped 2026-07-07). Everything is 100% local: no accounts, no telemetry, no cloud.

## Read these before non-trivial work

- `docs/CODEBASE.md` — module-by-module architecture and the non-obvious design decisions
- `docs/PITFALLS.md` — every trap hit during v1.0 development (symptom → cause → fix). **Check here first when something behaves strangely.**
- `docs/ROADMAP.md` — prioritized future plan, non-goals, and engineering ground rules

## Non-negotiable constraints (user decisions — do not relitigate)

- **No paid Apple Developer account.** Releases are ad-hoc/self-signed; users right-click → Open. Notarization slot exists in `scripts/release.sh` for later.
- **Lightweight and simple** beats feature count. No AI features, no accounts, no telemetry, ever.
- **Only third-party dependency is `sindresorhus/KeyboardShortcuts`.** Adding another needs a strong reason.
- macOS 26+ / arm64 only — no fallbacks, no Intel.

## Commands

```sh
make gen      # regenerate CmdV.xcodeproj — REQUIRED after adding/removing/renaming source files
make build    # Debug build (headless xcodebuild)
make test     # unit tests (Swift Testing, hosted in the app)
make run      # kill running instance, build, launch
./scripts/release.sh <version>   # build → sign → DMG → tag → GitHub release
```

`project.yml` is the source of truth; the generated `.xcodeproj` is committed. Edit
`project.yml`, never the pbxproj.

## Hard rules

- **Swift 6 strict concurrency is on.** Keep the build at zero warnings. Don't weaken isolation to "fix" an error — see PITFALLS for the known legit workarounds.
- **`ClipStore` (@ModelActor) is the ONLY SwiftData writer.** UI reads via `@Query` on the main context. Pass `ClipboardCapture` snapshots across actors, never `@Model` objects.
- **Never call `NSApp.activate()` from shelf code.** The shelf is a non-activating panel; the target app must stay frontmost or paste-at-cursor breaks.
- **`PrivacyGate.evaluate` order must not change**: self-copy → transient/concealed types → excluded apps.
- SourceKit "Cannot find type" diagnostics after adding files are stale-project noise — run `make gen`; trust only `make build`.
- Keep pure logic (gate, classifier, retention, stack queue) dependency-free and unit-tested.

## Headless verification (no GUI hands in this environment)

The agent shell cannot see the screen, and osascript keystroke / screencapture are blocked
by TCC. Verify like this instead:

```sh
# drive the UI
notifyutil -p com.tonmoybishwas.CmdV.toggleShelf
notifyutil -p com.tonmoybishwas.CmdV.togglePasteStack

# watch behavior (--info is REQUIRED or .info logs are silently dropped)
log stream --info --predicate 'subsystem == "com.tonmoybishwas.CmdV"'

# verify capture without UI (read-only!)
sqlite3 "file:$HOME/Library/Application Support/CmdV/CmdV.store?mode=ro" \
  "SELECT ZKINDRAW, substr(ZPLAINTEXT,1,40) FROM ZCLIPITEM ORDER BY ZCREATEDAT DESC LIMIT 5;"
```

Visual appearance, auto-paste at cursor, Quick Look, and drag-out can only be confirmed by
the user — say so explicitly instead of claiming them verified.

## How to continue this project

1. Read `docs/ROADMAP.md`; work top tier first unless the user says otherwise.
2. Keep milestone discipline: every change compiles (`make build`), tests stay green
   (`make test`), and behavior is verified headlessly before you call it done.
3. New pure logic gets unit tests in `CmdVTests/` (Swift Testing `@Test`/`#expect`).
4. A fresh clone must always work with `make gen && make build && make test` — CI
   (`.github/workflows/ci.yml`, macos-26 runners) enforces this on every push.
5. Releases only via `./scripts/release.sh <version>`; smoke-test the published DMG by
   downloading it back (real quarantine attribute) before announcing.
