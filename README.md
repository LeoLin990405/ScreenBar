<div align="center">

[![English](https://img.shields.io/badge/Language-English-2ea44f?style=for-the-badge)](README.md) &nbsp; [![中文](https://img.shields.io/badge/语言-中文-555555?style=for-the-badge)](README.zh-CN.md)

# ScreenBar

### Turn any Mac on your network into a second screen — or a window into its desktop — over Tailscale

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-black?style=for-the-badge&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/Language-Swift%206-F05138?style=for-the-badge&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/Directions-2-purple?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Tests-17%20passing-brightgreen?style=for-the-badge" />
  <a href="https://github.com/LeoLin990405/ScreenBar/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/LeoLin990405/ScreenBar/ci.yml?branch=main&style=for-the-badge&label=CI" /></a>
  <img src="https://img.shields.io/badge/License-MIT-yellowgreen?style=for-the-badge" />
</p>

</div>

> The idle Macs on your tailnet are wasted glass. ScreenBar makes them extra displays — or windows into their desktops — in one menu-bar click. It runs over Tailscale, so it works across networks.

---

## Overview

ScreenBar is a native SwiftUI menu-bar app that links the Macs on your [Tailscale](https://tailscale.com) network (or any reachable LAN) in **two directions**. It reads *real* connection state instead of stale flags, tells you which links are fast enough to actually use (Tailscale **direct vs relay**), and ships with a CLI and a `doctor` self-check. All system interaction lives in the app — no external shell scripts.

---

## 1. Two Directions

| Direction | Who shows what | Mechanism |
|---|---|---|
| **Second screen** | the other Mac shows *this* Mac | this Mac spins up a virtual display (BetterDisplay); the other Mac connects over Screen Sharing and goes full-screen → an extra monitor |
| **Remote view** | *this* Mac shows the other | this Mac acts as a Screen Sharing / Jump Desktop client → remote desktop (headless Mac minis too) |

---

## 2. Features

- **Live status** — online · viewable · acting-as-screen · being-viewed, from real connections (inbound/outbound `:5900`), not stale marker files.
- **Link quality** — Tailscale **direct vs relay**; relay is laggy as a second screen, so you see which devices are usable at a glance.
- **Per-device virtual displays** with independent resolution / HiDPI.
- **Auto-connect & reconnect** — flagged devices attach the moment they come online.
- **Post-connect verification & orphan cleanup** — actionable hints on failure; unused virtual screens are reclaimed.
- **Wake-on-LAN & launch-at-login.**
- **Jump Desktop (Fluid)** view path for relayed devices — smooth where VNC lags.
- **Built-in CLI + `doctor` self-check**; exports `~/.config/screenbar/status.json` for dashboards.

---

## 3. Requirements

- macOS 14+ / Swift 6
- [`betterdisplaycli`](https://github.com/waydabber/BetterDisplay) — `brew install waydabber/betterdisplay/betterdisplaycli` (for the second-screen direction)
- Target Macs reachable (e.g. the same [Tailscale](https://tailscale.com) tailnet) with key-based SSH

---

## 4. Installation

```bash
swift build            # debug build
swift test             # unit tests
Scripts/build-app.sh   # release → ~/Applications/ScreenBar.app + launch-at-login
```

---

## 5. Configuration

- **Devices** — add or edit them in **Settings → Device Management**; stored in `~/.config/screenbar/devices.json`.
- **This Mac's Tailscale IP** — the address other Macs dial for the second-screen direction; set it in `~/.config/screenbar/m5host`.

Neither file is committed to the repo.

---

## 6. CLI

The same binary doubles as a CLI (symlinked to `~/bin/screenbar`):

```bash
screenbar status          # all devices: online / viewable / in-use / link
screenbar list            # id · name · mode · host
screenbar connect <id>    # use a device as a second screen
screenbar disconnect <id>
screenbar view <id>       # view a device's screen here (VNC)
screenbar unview
screenbar jump <id>       # view via Jump Desktop (Fluid)
screenbar wake <id>       # Wake-on-LAN
screenbar doctor          # check environment + per-device readiness
```

---

## 7. One-time Setup

> Inherent to macOS Screen Sharing, not a limitation of this app.

1. On the first connection to a device, tick **Remember password**.
2. As a second screen, choose **Standard** mode on the other Mac — *not* High Quality, which dedicates (and blanks) your main display.
3. For true multi-display, pick the matching `ScreenBar-<id>` virtual display once in the other Mac's Screen Sharing **Displays** menu.

---

## 8. Architecture

```
Sources/ScreenBar/
  ScreenBarApp.swift       @main — MenuBarExtra panel + Settings (+ CLI dispatch)
  Model/                   Device · DeviceMode · DeviceStatus · StatusDump
  Store/ConfigStore.swift  JSON persistence + first-run seed
  State/AppModel.swift     @MainActor @Observable hub — poll / network / auto-connect
  Services/                Shell · Reachability · Tailscale · VirtualDisplay ·
                           RemoteControl · Connector · LaunchAtLogin · Diagnostics
  UI/                      MenuView · PreferencesView · DeviceEditView
  CLI/CLI.swift            same-binary command line
Tests/                     netstat · Tailscale · WoL · config · CLI
Scripts/build-app.sh       bundle .app + install LaunchAgent
```

Swift 6 strict concurrency, SwiftPM. A `@MainActor @Observable` state layer over a stateless async service layer that wraps all system calls (`netstat` / `nc` / `tailscale` / `betterdisplaycli` / `ssh` / `open`) through `Shell`.

---

## License

[MIT](LICENSE) © 2026 Leo Lin
