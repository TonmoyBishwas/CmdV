# Roadmap

Prioritized plan for CmdV after v1.0.0 (released 2026-07-07). Work top-down unless the
user redirects. Companion docs: [CODEBASE.md](CODEBASE.md), [PITFALLS.md](PITFALLS.md).

## Tier 1 — Now / next patch release (v1.0.x – v1.1)

1. **First real-world QA pass** (needs the user's hands — agent can only fix what's
   reported): auto-paste into various apps, Quick Look, drag-out, Liquid Glass visuals,
   Paste Stack in real workflows. Bugs found here outrank everything below.
2. **README screenshots** — the repo sells itself visually or not at all. Needs the user
   (or a GUI session with Screen Recording granted): shelf open over an app, Paste Stack
   overlay, settings. Add a GIF of ⇧⌘V → search → paste if possible.
3. **"CmdV Signing" certificate** — 30 seconds of user GUI time
   (`scripts/dev-sign-setup.sh`) so updates stop resetting users' Accessibility grants.
   Do this **before** shipping the next release; release.sh picks it up automatically.
4. **Crash/edge hardening from usage**: very large clipboard payloads, rapid copy bursts,
   store migration safety when models change (SwiftData lightweight migration — add
   defaults to new properties, never rename without a migration plan).

## Tier 2 — Near-term features (all local, all in Paste)

Ordered by value ÷ effort:

1. **Drag INTO the shelf** — drop text/images/files onto the shelf (or a pinboard chip)
   to save them as items. Natural inverse of the existing drag-out; `dropDestination`
   on the card strip, ingest via the existing `ClipStore.ingest` path.
2. **Export / import history** — JSON (+ referenced image files) for backup and machine
   moves. Cheap insurance for users, and makes "clear history" less scary.
3. **Compact shelf mode** — a `compactMode` Defaults key already exists; implement a
   single-row, smaller-card layout toggled from Settings/menu.
4. **Per-pinboard quick access** — hotkey or menu section to open the shelf pre-filtered
   to a pinboard (the filter plumbing already exists in `ShelfViewModel`).
5. **Paste formatting rules** — per-app "always paste as plain text" list, reusing the
   excluded-apps UI pattern.

## Tier 3 — Medium-term

- **Sparkle auto-updates** — the biggest UX gap of no-App-Store distribution; works fine
  with self-signed apps (EdDSA-signed appcast). Adds a dependency — justified, but keep
  it the *second and last* one unless something changes.
- **Homebrew cask** (`brew install --cask cmdv`) — easy once releases are stable;
  widens the funnel beyond DMG downloads.
- **Localization** — extract strings to a catalog first; ship English + 1–2 languages.
- **Menu-bar mini history** — recent N items directly in the MenuBarExtra menu.

## If a paid Apple Developer account ever arrives

1. Developer ID signing + notarization — uncomment the `notarytool` block in
   `scripts/release.sh`, set `CMDV_SIGN_IDENTITY`; removes the right-click→Open dance
   and the Accessibility-reset problem entirely.
2. Only then are **iCloud sync** and shared pinboards even possible (CloudKit
   entitlement requires a paid account). Revisit scope with the user first — sync was
   an explicit v1 exclusion, not an oversight.

## Non-goals (explicit user requirements — do not add)

- AI features of any kind (the reason this app exists is Paste-without-AI-subscription)
- Accounts, telemetry, analytics, network calls beyond optional link previews
- Intel Macs, macOS < 26, Windows/Linux
- Mac App Store distribution — the sandbox forbids CGEvent posting, which kills
  paste-at-cursor; not negotiable technically
- Feature bloat that costs simplicity: when in doubt, leave it out

## Engineering ground rules for all future work

- Swift 6 strict concurrency stays at zero warnings; don't downgrade isolation to make
  errors go away (known-legit workarounds are in PITFALLS.md).
- Pure logic gets unit tests; UI logic stays thin enough not to need them.
- `make gen && make build && make test` must pass on a fresh clone — CI enforces it.
- Verify headlessly (hooks/logs/sqlite3) before claiming anything works; name what
  still needs human eyes.
- Version bumps: release.sh stamps `MARKETING_VERSION`; tag = `v<version>`; DMG name =
  `CmdV-<version>.dmg`. Update `scripts/release-notes-template.md` highlights per release.
- Any schema change to `Models.swift`: new properties need defaults (SwiftData
  lightweight migration); test upgrade against a copy of a real store before release.
