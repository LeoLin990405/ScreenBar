<div align="center">

# ScreenBar

**从菜单栏,把网络里任意一台 Mac 变成你的副屏 —— 或直接查看它的屏幕。**

[![English](https://img.shields.io/badge/Lang-English-555555?style=for-the-badge)](README.md)&nbsp;&nbsp;[![中文](https://img.shields.io/badge/Lang-中文-2ea44f?style=for-the-badge)](README.zh-CN.md)

[![CI](https://github.com/LeoLin990405/ScreenBar/actions/workflows/ci.yml/badge.svg)](https://github.com/LeoLin990405/ScreenBar/actions/workflows/ci.yml)
&nbsp;![Platform](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)
&nbsp;![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
&nbsp;![License](https://img.shields.io/badge/License-MIT-blue)

</div>

ScreenBar 是一个原生 SwiftUI 菜单栏小工具,把你 [Tailscale](https://tailscale.com) 网络(或任何可达局域网)里的 Mac **双向**连起来:

- **当副屏** —— 主力 Mac 造一块虚拟屏,另一台 Mac 通过屏幕共享连入,成为扩展显示器。
- **远程查看** —— 在主力 Mac 上显示另一台 Mac 的屏幕(无头 Mac mini 也能看)。

它读取真实连接状态,告诉你哪条链路够快能真用,并附带命令行与自检。

## ✨ 功能

- **实时状态** —— 在线 / 可查看 / 正当副屏 / 正被查看,由真实连接(`netstat`)得出,不是会过期的标记。
- **链路质量** —— Tailscale **直连 vs 中继**,一眼看出哪台流畅、哪台当副屏会卡。
- **每设备独立虚拟屏**,各自分辨率 / HiDPI。
- **自动连接 & 重连** —— 标记的设备一上线就自动挂上。
- **连接后验证** 与 **孤儿虚拟屏自动清理**。
- **Wake-on-LAN** 唤醒、**开机自启**。
- **Jump Desktop(Fluid)** 查看通道,给中继设备用 —— VNC 走中继卡时它更顺。
- **内置 CLI** 与 `doctor` 自检。

## 📦 依赖

- macOS 14 及以上
- [`betterdisplaycli`](https://github.com/waydabber/BetterDisplay) —— `brew install waydabber/betterdisplay/betterdisplaycli`
- 目标 Mac 可达(如同一 [Tailscale](https://tailscale.com) tailnet)+ SSH 密钥免密

## 🚀 构建 & 安装

```bash
swift build            # 调试构建
swift test             # 运行单元测试
Scripts/build-app.sh   # release → ~/Applications/ScreenBar.app + 开机自启
```

## ⚙️ 配置

- **设备** —— 在 **设置 → 设备管理** 里增删改;存于 `~/.config/screenbar/devices.json`。
- **本机的 Tailscale IP** —— 副屏方向时对方要连的地址;写到 `~/.config/screenbar/m5host`。

两个文件都不进仓库。

## 💻 命令行

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

## 📋 一次性设置(macOS 屏幕共享固有)

1. 首次连接某台设备时,勾选 **记住密码**。
2. 当副屏时在对方 Mac 选 **标准** 模式 —— *别* 选高质量,那会独占并使你的主屏黑屏。
3. 真·多显示器:在对方 Mac 的屏幕共享 **显示器** 菜单里,选对应的 `ScreenBar-<id>` 虚拟屏一次(会被记住)。

## 📐 架构

<details>
<summary>项目结构</summary>

```
Sources/ScreenBar/
  ScreenBarApp.swift       @main —— MenuBarExtra 面板 + 设置(+ CLI 分发)
  Model/                   Device · DeviceMode · DeviceStatus · StatusDump
  Store/ConfigStore.swift  JSON 持久化 + 首次运行种子
  State/AppModel.swift     @MainActor @Observable 中枢 —— 轮询 / 网络 / 自动连接
  Services/                Shell · Reachability · Tailscale · VirtualDisplay ·
                           RemoteControl · Connector · LaunchAtLogin · Diagnostics
  UI/                      MenuView · PreferencesView · DeviceEditView
  CLI/CLI.swift            同一二进制的命令行
Tests/                     netstat · Tailscale · WoL · 配置 · CLI
Scripts/build-app.sh       打包 .app + 装 LaunchAgent
```

Swift 6(严格并发)、SwiftPM。所有系统交互(ssh / netstat / betterdisplaycli / open)都在 app 内 —— 不依赖外部 shell 脚本。
</details>

## 📄 许可

[MIT](LICENSE) © Leo Lin
