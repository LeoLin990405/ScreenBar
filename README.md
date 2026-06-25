<div align="center">

# ScreenBar

**Use any Mac on your network as a second display — or view its screen — right from your menu bar.**

[![English](https://img.shields.io/badge/Lang-English-2ea44f?style=for-the-badge)](README.md)&nbsp;&nbsp;[![中文](https://img.shields.io/badge/Lang-中文-555555?style=for-the-badge)](README.zh-CN.md)

[![CI](https://github.com/LeoLin990405/ScreenBar/actions/workflows/ci.yml/badge.svg)](https://github.com/LeoLin990405/ScreenBar/actions/workflows/ci.yml)
&nbsp;![Platform](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)
&nbsp;![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
&nbsp;![License](https://img.shields.io/badge/License-MIT-blue)

</div>

ScreenBar is a native SwiftUI menu-bar app that links the Macs on your [Tailscale](https://tailscale.com) network (or any reachable LAN) in **two directions**:

- **As a second screen** — your main Mac spins up a virtual display; another Mac connects over Screen Sharing and becomes an extra monitor.
- **As a remote view** — show another Mac's screen on your main Mac (great for headless Mac minis).

It reads real connection state, tells you which links are fast enough to actually use, and ships with a CLI and self-diagnostics.

## ✨ Features

- **Live status** — online / viewable / acting-as-screen / being-viewed, derived from real connections (`netstat`), not stale flags.
- **Link quality** — Tailscale **direct vs relay**, so you know which devices are smooth and which will lag as a second screen.
- **Per-device virtual displays** with independent resolution / HiDPI.
- **Auto-connect & reconnect** — flagged devices attach the moment they come online.
- **Post-connect verification** and **orphan virtual-screen cleanup**.
- **Wake-on-LAN** and **launch-at-login**.
- **Jump Desktop (Fluid)** view path for relayed devices — smooth where VNC lags.
- **Built-in CLI** plus a `doctor` self-check.

## 📦 Requirements

- macOS 14 or later
- [`betterdisplaycli`](https://github.com/waydabber/BetterDisplay) — `brew install waydabber/betterdisplay/betterdisplaycli`
- Target Macs reachable (e.g. the same [Tailscale](https://tailscale.com) tailnet) with key-based SSH

## 🚀 Build & Install

```bash
swift build            # debug build
swift test             # run unit tests
Scripts/build-app.sh   # release → ~/Applications/ScreenBar.app + launch-at-login
```

## ⚙️ Configuration

- **Devices** — add or edit them in **Settings → Device Management**; stored in `~/.config/screenbar/devices.json`.
- **This Mac's Tailscale IP** — the address other Macs dial for the second-screen direction; set it in `~/.config/screenbar/m5host`.

Neither file is committed to the repo.

## 💻 CLI

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

## 📋 One-time setup (inherent to macOS Screen Sharing)

1. On the first connection to a device, tick **Remember password**.
2. As a second screen, choose **Standard** mode on the other Mac — *not* High Quality, which dedicates (and blanks) your main display.
3. For true multi-display, pick the matching `ScreenBar-<id>` virtual display once in the other Mac's Screen Sharing **Displays** menu.

## 📐 Architecture

<details>
<summary>Project layout</summary>

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

Swift 6 with strict concurrency, SwiftPM. All system interaction (ssh / netstat / betterdisplaycli / open) lives in the app — no external shell scripts.
</details>

## 📄 License

[MIT](LICENSE) © Leo Lin
