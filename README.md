<div align="center">

# ScreenBar — 把网络里任意一台 Mac 变成副屏(或远程查看)的菜单栏工具

### A menu-bar app that turns any Mac on your network into a second screen — or a window into its desktop — over Tailscale

<p align="center">
  <img src="https://img.shields.io/badge/平台%20Platform-macOS%2014%2B-black?style=for-the-badge&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/语言%20Language-Swift%206-F05138?style=for-the-badge&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/方向%20Directions-2-purple?style=for-the-badge" />
  <img src="https://img.shields.io/badge/测试%20Tests-17%20passing-brightgreen?style=for-the-badge" />
  <a href="https://github.com/LeoLin990405/ScreenBar/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/LeoLin990405/ScreenBar/ci.yml?branch=main&style=for-the-badge&label=CI" /></a>
  <img src="https://img.shields.io/badge/License-MIT-yellowgreen?style=for-the-badge" />
</p>

</div>

> **一句话**:你的 tailnet 里往往躺着好几台闲置的 Mac(公司机、家里的、无头 mini)。ScreenBar 让它们一键变成主力机的扩展屏,或反过来在主力机上看它们的桌面 —— 全部从菜单栏,走 Tailscale,跨网也能用。
>
> *The idle Macs on your tailnet are wasted glass. ScreenBar makes them extra displays — or windows into their desktops — in one menu-bar click.*

---

## 概览 Overview

**ScreenBar** is a native SwiftUI menu-bar app that links the Macs on your [Tailscale](https://tailscale.com) network (or any reachable LAN) in **two directions**, reads *real* connection state rather than stale flags, tells you which links are fast enough to actually use (Tailscale **direct vs relay**), and ships with a CLI and a `doctor` self-check. All system interaction lives in the app — no external shell scripts.

**ScreenBar** 是一个原生 SwiftUI 菜单栏工具,把你 [Tailscale](https://tailscale.com) 网络(或任何可达局域网)里的 Mac **双向**连起来。它由真实连接(`netstat`)推导状态、用 **直连/中继** 告诉你哪条链路够快能真用,并自带命令行与 `doctor` 自检。所有系统交互都在 app 内,不依赖外部 shell 脚本。

---

## 1. 两个方向 Two Directions

| 方向 Direction | 谁显示谁 Who shows what | 机制 Mechanism |
|---|---|---|
| **当副屏 As a second screen** | 对方 Mac 显示本机 / the other Mac shows *this* Mac | 本机造虚拟屏(BetterDisplay),对方用屏幕共享连入并全屏 → 成为扩展显示器 |
| **远程查看 As a remote view** | 本机显示对方 / *this* Mac shows the other | 本机作 Screen Sharing / Jump Desktop 客户端 → 显示远程桌面(无头 Mac mini 也能看) |

---

## 2. 功能 Features

- **实时状态 Live status** — 在线 · 可查看 · 副屏中 · 查看中,由真实连接(入/出向 `:5900`)得出,不是会过期的标记文件。
- **链路质量 Link quality** — Tailscale **直连 vs 中继**;中继=高延迟(当副屏会卡),一眼看出哪台能用。
- **每设备独立虚拟屏 Per-device virtual displays** — 各自分辨率 / HiDPI。
- **自动连接 & 重连 Auto-connect & reconnect** — 标记的设备一上线就自动挂上。
- **连接后验证 + 孤儿清理 Verify & cleanup** — 连不上给可操作提示;无人查看的虚拟屏自动收回。
- **唤醒与自启 Wake-on-LAN & launch-at-login**。
- **Jump Desktop(Fluid)查看通道** — 给中继设备用,VNC 卡时它更顺。
- **内置 CLI + `doctor` 自检 Built-in CLI & self-check**;导出 `~/.config/screenbar/status.json`(可观测性 / 状态墙)。

---

## 3. 系统要求 Requirements

- macOS 14+ / Swift 6
- [`betterdisplaycli`](https://github.com/waydabber/BetterDisplay) — `brew install waydabber/betterdisplay/betterdisplaycli`(副屏方向用 / for the second-screen direction)
- 目标 Mac 可达(如同一 [Tailscale](https://tailscale.com) tailnet)+ SSH 密钥免密 / reachable targets with key-based SSH

---

## 4. 安装 Installation

```bash
swift build            # 调试构建 / debug build
swift test             # 单元测试 / unit tests
Scripts/build-app.sh   # release → ~/Applications/ScreenBar.app + 开机自启 / launch-at-login
```

---

## 5. 配置 Configuration

- **设备 Devices** — 在 **设置 → 设备管理 / Settings → Device Management** 里增删改;存于 `~/.config/screenbar/devices.json`。
- **本机 Tailscale IP / This Mac's Tailscale IP** — 副屏方向时对方要连的地址;写到 `~/.config/screenbar/m5host`。

两个文件都不进仓库 / Neither file is committed.

---

## 6. 命令行 CLI

同一个二进制兼作 CLI(软链 `~/bin/screenbar`)/ The same binary doubles as a CLI:

```bash
screenbar status          # 所有设备:在线/可查看/使用中/链路 — all devices: online / viewable / in-use / link
screenbar list            # id · 名称 name · 方向 mode · host
screenbar connect <id>    # 让设备当副屏 — use a device as a second screen
screenbar disconnect <id>
screenbar view <id>       # 在本机查看该设备(VNC) — view a device's screen here
screenbar unview
screenbar jump <id>       # 用 Jump Desktop 查看(Fluid) — view via Jump Desktop
screenbar wake <id>       # Wake-on-LAN
screenbar doctor          # 自检环境 + 每台设备就绪度 — check environment + readiness
```

---

## 7. 一次性设置 One-time Setup

> macOS 屏幕共享固有,非本工具限制 / Inherent to macOS Screen Sharing, not a limitation of this app.

1. 首次连接每台设备:在登录框勾 **记住密码 / Remember password**。
2. 当副屏时在对方 Mac 选 **标准 / Standard** 模式 —— *别* 选高质量,那会独占并使本机主屏黑屏。
3. 真·多显示器:在对方 Mac 的屏幕共享 **显示器 / Displays** 菜单选对应的 `ScreenBar-<id>` 虚拟屏一次(会被记住)。

---

## 8. 架构 Architecture

```
Sources/ScreenBar/
  ScreenBarApp.swift       @main — MenuBarExtra 面板 + 设置(+ CLI 分发)
  Model/                   Device · DeviceMode · DeviceStatus · StatusDump
  Store/ConfigStore.swift  JSON 持久化 + 首次运行种子
  State/AppModel.swift     @MainActor @Observable 中枢 — 轮询 / 网络变化 / 自动连接
  Services/                Shell · Reachability · Tailscale · VirtualDisplay ·
                           RemoteControl · Connector · LaunchAtLogin · Diagnostics
  UI/                      MenuView · PreferencesView · DeviceEditView
  CLI/CLI.swift            同一二进制的命令行 / same-binary command line
Tests/                     netstat · Tailscale · WoL · config · CLI
Scripts/build-app.sh       打包 .app + 装 LaunchAgent
```

Swift 6(严格并发)、SwiftPM。State 层 `@MainActor @Observable`,Services 层无副作用纯异步(`netstat`/`nc`/`tailscale`/`betterdisplaycli`/`ssh`/`open` 经 `Shell` 封装)。

Swift 6 strict concurrency, SwiftPM. `@MainActor @Observable` state layer; stateless async service layer wrapping all system calls through `Shell`.

---

## 许可 License

[MIT](LICENSE) © 2026 Leo Lin
