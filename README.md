# CmdV

**A free, open-source clipboard manager for macOS — with the Liquid Glass look.**

CmdV keeps everything you copy — text, links, images, files, colors, code — and lets you find it and paste it again in seconds. It's a lightweight, privacy-respecting alternative to paid clipboard managers, built natively for Apple Silicon Macs running macOS 26 (Tahoe) or later.

> 🚧 **Work in progress** — v1.0 is under active development.

## Features (v1.0 goals)

- 📋 **Automatic clipboard history** — nothing you copy is ever lost
- 🔍 **Instant search** — just start typing; filter by type, app, or date
- 🗂 **Pinboards** — save snippets, templates, and links permanently
- 📚 **Paste Stack** — queue up copies, then paste them back one by one
- ⌨️ **Quick Paste** — ⌘1–⌘9 pastes any visible item instantly
- 🔒 **Privacy first** — passwords are never recorded; exclude any app; everything stays on your Mac
- 🪟 **Liquid Glass UI** — a native macOS 26 glass shelf that slides up from the bottom of your screen

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 26.0 (Tahoe) or later

## Install

Download the latest `.dmg` from [Releases](https://github.com/TonmoyBishwas/CmdV/releases), drag **CmdV** to Applications, then **right-click → Open** the first time (CmdV is a free open-source app and isn't notarized by Apple).

## Build from source

```sh
git clone https://github.com/TonmoyBishwas/CmdV.git
cd CmdV
make build   # or open CmdV.xcodeproj in Xcode 26+
make run
```

Regenerate the Xcode project after adding/removing files: `brew install xcodegen && make gen`.

## License

[GPL-3.0](LICENSE)
