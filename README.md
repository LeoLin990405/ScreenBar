# ScreenBar

M5 的菜单栏小工具(CodexBar 式),一键把机队里的机器接成 M5 的**副屏**,或把它们的屏幕**投到 M5 查看**。双向、配置驱动、原生 SwiftUI。

## 两个方向

- **当 M5 副屏**(对方显示 M5):M5 出一块虚拟屏,对方机器用屏幕共享连入并全屏显示 → 对方成为 M5 的扩展显示器。
- **投屏到 M5 查看**(M5 显示对方):M5 当屏幕共享客户端 `open vnc://对方` → 在 M5 上看对方桌面(无头 Mac mini 也能看)。

## 功能

- 实时状态:每台机器 在线 / 可查看 / 正当副屏 / 正被查看(`netstat` 区分入向/出向 5900 连接,非标记文件)。
- 链路质量:Tailscale 直连 / 中继(中继=高延迟,当副屏会卡)—— 一眼看出哪台能当低延迟副屏。
- 设备管理 GUI(设置窗口):增删改设备、选方向、调分辨率/HiDPI、开机自启。
- 真·多显示器:每台设备一块独立命名虚拟屏(`ScreenBar-<id>`),各自分辨率/HiDPI。
- 自动连接:`autoConnect` 设备一上线即自动挂为副屏;掉线后再上线自动重连;用户手动断开则暂不抢回。
- 唤醒(Wake-on-LAN)+ 一键尝试开对方屏幕共享;在线时自动抓 MAC。
- 防呆:连接通知提示「选标准别选高质量」(否则 M5 物理屏会被独占黑屏)。

## 架构

```
Sources/ScreenBar/
  ScreenBarApp.swift     @main,MenuBarExtra + Settings 窗口
  Model/                 Device / DeviceMode / DeviceStatus(Codable/Sendable)
  Store/ConfigStore.swift JSON 持久化(~/.config/screenbar/devices.json)+ 默认种子
  State/AppModel.swift   @MainActor @Observable 中枢:轮询/网络变化/自动连接
  Services/              Shell / Reachability / VirtualDisplay / RemoteControl / Connector / LaunchAtLogin
  UI/                    MenuView / PreferencesView / DeviceEditView
Tests/ScreenBarTests/    netstat 解析 / WoL 包 / 配置种子 / Codable 往返
Scripts/build-app.sh     构建 .app + 装 LaunchAgent
```

Swift 6 语言模式,严格并发。所有逻辑(ssh/netstat/betterdisplaycli/open)统一进 app,不再依赖外部 bash 脚本。

## 构建 / 安装

```bash
swift build            # 调试
swift test             # 单元测试
Scripts/build-app.sh   # release 打包 → ~/Applications/ScreenBar.app + 开机自启
```

依赖:`betterdisplaycli`(`brew install waydabber/betterdisplay/betterdisplaycli`)、各设备 Tailscale 可达、SSH 免密。

## CLI(同一二进制双模式:带命令走 CLI,无参启 GUI)

装机后 `~/bin/screenbar` 软链可用:

```bash
screenbar status            # 所有设备 在线/可查看/副屏中/查看中
screenbar list              # id 名 方向 host 备注
screenbar connect <id>      # 让设备当 M5 副屏
screenbar disconnect <id>   # 断开副屏
screenbar view <id>         # 在 M5 上查看该设备屏幕
screenbar unview            # 关闭查看
screenbar wake <id>         # Wake-on-LAN
```

可脚本化 / 接状态墙(也可直接读 `~/.config/screenbar/status.json`)。

## 一次性手动步骤(macOS 屏幕共享固有,非 app 限制)

1. 首次连接每台设备:弹登录框勾「记住密码」,之后免登录。
2. 当副屏时在对方机器选「**标准**」模式(别选「高质量」,否则独占 M5 物理屏致黑屏)。
3. 真·多显示器:在对方机器的屏幕共享「显示器」菜单里选对应的 `ScreenBar-<id>` 虚拟屏一次(会被记住)。
