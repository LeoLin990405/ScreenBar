<div align="center">

[![English](https://img.shields.io/badge/Language-English-555555?style=for-the-badge)](README.md) &nbsp; [![中文](https://img.shields.io/badge/语言-中文-2ea44f?style=for-the-badge)](README.zh-CN.md)

# ScreenBar

### 把网络里任意一台 Mac 变成副屏 —— 或在本机查看它的桌面 —— 走 Tailscale

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS%2014%2B-black?style=for-the-badge&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/语言-Swift%206-F05138?style=for-the-badge&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/方向-2-purple?style=for-the-badge" />
  <img src="https://img.shields.io/badge/测试-17%20通过-brightgreen?style=for-the-badge" />
  <a href="https://github.com/LeoLin990405/ScreenBar/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/LeoLin990405/ScreenBar/ci.yml?branch=main&style=for-the-badge&label=CI" /></a>
  <img src="https://img.shields.io/badge/License-MIT-yellowgreen?style=for-the-badge" />
</p>

</div>

> 你的 tailnet 里往往躺着好几台闲置的 Mac(公司机、家里的、无头 mini)。ScreenBar 让它们一键变成主力机的扩展屏,或反过来在主力机上看它们的桌面 —— 全部从菜单栏,走 Tailscale,跨网也能用。

---

## 概览

ScreenBar 是一个原生 SwiftUI 菜单栏工具,把你 [Tailscale](https://tailscale.com) 网络(或任何可达局域网)里的 Mac **双向**连起来。它由**真实连接**(`netstat`)推导状态、用 **直连/中继** 告诉你哪条链路够快能真用,并自带命令行与 `doctor` 自检。所有系统交互都在 app 内,不依赖外部 shell 脚本。

---

## 1. 两个方向

| 方向 | 谁显示谁 | 机制 |
|---|---|---|
| **当副屏** | 对方 Mac 显示**本机** | 本机造一块虚拟屏(BetterDisplay),对方用屏幕共享连入并全屏 → 成为扩展显示器 |
| **远程查看** | **本机**显示对方 | 本机作 Screen Sharing / Jump Desktop 客户端 → 显示远程桌面(无头 Mac mini 也能看) |

---

## 2. 功能

- **实时状态** — 在线 · 可查看 · 副屏中 · 查看中,由真实连接(入/出向 `:5900`)得出,不是会过期的标记文件。
- **链路质量** — Tailscale **直连 vs 中继**;中继=高延迟(当副屏会卡),一眼看出哪台能用。
- **每设备独立虚拟屏** — 各自分辨率 / HiDPI。
- **自动连接 & 重连** — 标记的设备一上线就自动挂上。
- **连接后验证 + 孤儿清理** — 连不上给可操作提示;无人查看的虚拟屏自动收回。
- **唤醒(Wake-on-LAN)与开机自启。**
- **Jump Desktop(Fluid)查看通道** — 给中继设备用,VNC 卡时它更顺。
- **内置 CLI + `doctor` 自检**;导出 `~/.config/screenbar/status.json`(可观测性 / 状态墙)。

---

## 3. 系统要求

- macOS 14+ / Swift 6
- [`betterdisplaycli`](https://github.com/waydabber/BetterDisplay) — `brew install waydabber/betterdisplay/betterdisplaycli`(副屏方向用)
- 目标 Mac 可达(如同一 [Tailscale](https://tailscale.com) tailnet)+ SSH 密钥免密

---

## 4. 安装

```bash
swift build            # 调试构建
swift test             # 单元测试
Scripts/build-app.sh   # release → ~/Applications/ScreenBar.app + 开机自启
```

---

## 5. 配置

- **设备** — 在 **设置 → 设备管理** 里增删改;存于 `~/.config/screenbar/devices.json`。
- **本机的 Tailscale IP** — 副屏方向时对方要连的地址;写到 `~/.config/screenbar/m5host`。

两个文件都不进仓库。

---

## 6. 命令行

同一个二进制兼作 CLI(软链到 `~/bin/screenbar`):

```bash
screenbar status          # 所有设备:在线 / 可查看 / 使用中 / 链路
screenbar list            # id · 名称 · 方向 · host
screenbar connect <id>    # 让设备当副屏
screenbar disconnect <id>
screenbar view <id>       # 在本机查看该设备屏幕(VNC)
screenbar unview
screenbar jump <id>       # 用 Jump Desktop 查看(Fluid)
screenbar wake <id>       # Wake-on-LAN 唤醒
screenbar doctor          # 自检环境 + 每台设备就绪度
```

---

## 7. 一次性设置

> macOS 屏幕共享固有,非本工具限制。

1. 首次连接每台设备:在登录框勾 **记住密码**。
2. 当副屏时在对方 Mac 选 **标准** 模式 —— *别* 选高质量,那会独占并使本机主屏黑屏。
3. 真·多显示器:在对方 Mac 的屏幕共享 **显示器** 菜单选对应的 `ScreenBar-<id>` 虚拟屏一次(会被记住)。

---

## 8. 架构

```
Sources/ScreenBar/
  ScreenBarApp.swift       @main — MenuBarExtra 面板 + 设置(+ CLI 分发)
  Model/                   Device · DeviceMode · DeviceStatus · StatusDump
  Store/ConfigStore.swift  JSON 持久化 + 首次运行种子
  State/AppModel.swift     @MainActor @Observable 中枢 — 轮询 / 网络变化 / 自动连接
  Services/                Shell · Reachability · Tailscale · VirtualDisplay ·
                           RemoteControl · Connector · LaunchAtLogin · Diagnostics
  UI/                      MenuView · PreferencesView · DeviceEditView
  CLI/CLI.swift            同一二进制的命令行
Tests/                     netstat · Tailscale · WoL · 配置 · CLI
Scripts/build-app.sh       打包 .app + 装 LaunchAgent
```

Swift 6(严格并发)、SwiftPM。`@MainActor @Observable` 状态层之下是无副作用的异步 service 层,所有系统调用(`netstat` / `nc` / `tailscale` / `betterdisplaycli` / `ssh` / `open`)经 `Shell` 封装。

---

## 许可

[MIT](LICENSE) © 2026 Leo Lin
