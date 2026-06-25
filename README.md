# ScreenBar

A macOS menu-bar app to use **other Macs as second screens** for this Mac — or **view their screens here** — over Tailscale (or any reachable network). Native SwiftUI, bidirectional, with a CLI.

一个 macOS 菜单栏小工具:把**别的 Mac 当本机的副屏**,或**在本机查看它们的屏幕** —— 走 Tailscale(或任何可达网络)。原生 SwiftUI、双向、带命令行。

**English** · [中文](#中文)

---

## English

### Two directions

- **Use another Mac as a second screen** — this Mac creates a virtual display (via BetterDisplay); the other Mac connects over Screen Sharing and shows it full-screen, becoming an extra monitor.
- **View another Mac's screen here** — this Mac acts as a Screen Sharing / Jump Desktop client and shows the remote desktop (works for headless Mac minis too).

### Features

- **Live status** per device: online / viewable / acting-as-screen / being-viewed — derived from `netstat` (inbound vs outbound `:5900`), not stale marker files.
- **Link quality**: Tailscale **direct vs relay** — relay = high latency (laggy as a second screen), so you can tell at a glance which devices work well.
- **Per-device virtual displays** (BetterDisplay), each with its own resolution / HiDPI.
- **Auto-connect + auto-reconnect**: a device flagged `autoConnect` is attached as a second screen as soon as it comes online.
- **Post-connect verification** and **orphan virtual-screen cleanup**.
- **Wake-on-LAN**, **launch-at-login** (SMAppService).
- **Optional Jump Desktop (Fluid)** view path for relayed devices — much smoother than VNC over relay.
- **CLI in the same binary** + self-diagnostics (`doctor`).
- Exports `~/.config/screenbar/status.json` (observability / dashboards).

### Requirements

- macOS 14+
- [`betterdisplaycli`](https://github.com/waydabber/BetterDisplay) — `brew install waydabber/betterdisplay/betterdisplaycli` (for the second-screen direction)
- Devices reachable (e.g. on the same [Tailscale](https://tailscale.com) tailnet) with key-based SSH

### Build / Install

```bash
swift build            # debug
swift test             # unit tests
Scripts/build-app.sh   # release -> ~/Applications/ScreenBar.app + launch-at-login
```

### Configuration

- Devices: managed in **Settings / Device Management** (the menu's gear), persisted to `~/.config/screenbar/devices.json` (not in the repo).
- This Mac's own Tailscale IP (the address other Macs connect to for the second-screen direction): put it in `~/.config/screenbar/m5host`.

### CLI

```bash
screenbar status            # all devices: online / viewable / in-use / link
screenbar list              # id, name, mode, host
screenbar connect <id>      # use device as a second screen
screenbar disconnect <id>
screenbar view <id>         # view the device's screen here (VNC)
screenbar unview
screenbar jump <id>         # view via Jump Desktop (Fluid; smooth over relay)
screenbar wake <id>         # Wake-on-LAN
screenbar doctor            # self-check environment + per-device readiness
```

### One-time manual steps (inherent to macOS Screen Sharing)

1. First connection to each device: tick "remember password" in the login prompt.
2. As a second screen, pick **Standard** mode on the other Mac (not High Quality / High Performance — that dedicates this Mac's physical display and blanks it).
3. True multi-display: in the other Mac's Screen Sharing **Displays** menu, pick the matching `ScreenBar-<id>` virtual display once (it's remembered).

### Architecture

```
Sources/ScreenBar/
  ScreenBarApp.swift     @main: MenuBarExtra panel + Settings window (+ CLI dispatch)
  Model/                 Device / DeviceMode / DeviceStatus / StatusDump (Codable, Sendable)
  Store/ConfigStore.swift JSON persistence + first-run seed
  State/AppModel.swift   @MainActor @Observable hub: poll / network-change / auto-connect
  Services/              Shell, Reachability, Tailscale, VirtualDisplay, RemoteControl,
                         Connector, LaunchAtLogin, Diagnostics
  UI/                    MenuView (panel) / PreferencesView / DeviceEditView
  CLI/CLI.swift          same-binary command-line interface
Tests/                   netstat / Tailscale / WoL / config / CLI unit tests
Scripts/build-app.sh     bundle .app + install LaunchAgent
```

Swift 6 (strict concurrency), SwiftPM. All logic (ssh / netstat / betterdisplaycli / open) lives in the app — no external shell scripts.

### License

[MIT](LICENSE)

---

## 中文

### 两个方向

- **把别的 Mac 当副屏** —— 本机用 BetterDisplay 造一块虚拟屏,对方 Mac 通过屏幕共享连入并全屏显示,成为本机的扩展显示器。
- **在本机查看别的 Mac** —— 本机作为屏幕共享 / Jump Desktop 客户端,显示远程桌面(无头 Mac mini 也能看)。

### 功能

- **每台设备实时状态**:在线 / 可查看 / 正当副屏 / 正被查看 —— 由 `netstat` 区分入向/出向 `:5900` 得出,不是会过期的标记文件。
- **链路质量**:Tailscale **直连 vs 中继** —— 中继=高延迟(当副屏会卡),一眼看出哪台适合当副屏。
- **每设备独立虚拟屏**(BetterDisplay),各自分辨率 / HiDPI。
- **自动连接 + 自动重连**:标记 `autoConnect` 的设备一上线就自动挂为副屏。
- **连接后验证** + **孤儿虚拟屏自动清理**。
- **Wake-on-LAN** 唤醒、**开机自启**(SMAppService)。
- **可选 Jump Desktop(Fluid)** 查看通道,给中继设备用 —— 比 VNC 走中继流畅得多。
- **同一二进制内置 CLI** + 自检(`doctor`)。
- 导出 `~/.config/screenbar/status.json`(可观测性 / 状态墙)。

### 依赖

- macOS 14+
- [`betterdisplaycli`](https://github.com/waydabber/BetterDisplay) —— `brew install waydabber/betterdisplay/betterdisplaycli`(副屏方向用)
- 设备可达(如同一 [Tailscale](https://tailscale.com) tailnet)+ SSH 密钥免密

### 构建 / 安装

```bash
swift build            # 调试
swift test             # 单元测试
Scripts/build-app.sh   # release 打包 → ~/Applications/ScreenBar.app + 开机自启
```

### 配置

- 设备:在**设置 / 设备管理**(菜单里)增删改,存到 `~/.config/screenbar/devices.json`(不进仓库)。
- 本机自己的 Tailscale IP(副屏方向时对方要连的地址):写到 `~/.config/screenbar/m5host`。

### CLI

```bash
screenbar status            # 所有设备:在线 / 可查看 / 使用中 / 链路
screenbar list              # id、名称、方向、host
screenbar connect <id>      # 让设备当副屏
screenbar disconnect <id>
screenbar view <id>         # 在本机查看该设备屏幕(VNC)
screenbar unview
screenbar jump <id>         # 用 Jump Desktop 查看(Fluid,中继也流畅)
screenbar wake <id>         # Wake-on-LAN 唤醒
screenbar doctor            # 自检环境 + 每台设备就绪度
```

### 一次性手动步骤(macOS 屏幕共享固有,非本工具限制)

1. 首次连接每台设备:在登录框勾「记住密码」。
2. 当副屏时在对方 Mac 选「**标准**」模式(别选「高质量」—— 那会独占本机物理屏并使其黑屏)。
3. 真·多显示器:在对方 Mac 的屏幕共享「**显示器**」菜单里选对应的 `ScreenBar-<id>` 虚拟屏一次(会被记住)。

### 架构

```
Sources/ScreenBar/
  ScreenBarApp.swift     @main:MenuBarExtra 面板 + 设置窗口(+ CLI 分发)
  Model/                 Device / DeviceMode / DeviceStatus / StatusDump(Codable/Sendable)
  Store/ConfigStore.swift JSON 持久化 + 首次运行种子
  State/AppModel.swift   @MainActor @Observable 中枢:轮询 / 网络变化 / 自动连接
  Services/              Shell、Reachability、Tailscale、VirtualDisplay、RemoteControl、
                         Connector、LaunchAtLogin、Diagnostics
  UI/                    MenuView(面板)/ PreferencesView / DeviceEditView
  CLI/CLI.swift          同一二进制的命令行接口
Tests/                   netstat / Tailscale / WoL / 配置 / CLI 单元测试
Scripts/build-app.sh     打包 .app + 装 LaunchAgent
```

Swift 6(严格并发)、SwiftPM。所有逻辑(ssh / netstat / betterdisplaycli / open)都在 app 内,不依赖外部 shell 脚本。

### 许可

[MIT](LICENSE)
