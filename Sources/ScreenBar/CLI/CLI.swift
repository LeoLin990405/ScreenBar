import Foundation

/// 命令行接口。同一二进制:带已知命令走 CLI,否则启 GUI。
/// 用法:`ScreenBar status` / `connect <id>` / `view <id>` …(可 symlink 成 `screenbar`)。
enum CLI {
    static let commands: Set<String> = [
        "status", "list", "connect", "disconnect", "view", "unview", "jump", "wake", "doctor", "help", "-h", "--help",
    ]
    static func isCommand(_ s: String) -> Bool { commands.contains(s) }

    static func run(_ cmd: String, _ rest: [String]) async {
        let devices = ConfigStore.loadDevices()
        func find(_ id: String?) -> Device? {
            guard let id else { return nil }
            return devices.first { $0.id == id }
        }

        switch cmd {
        case "list":
            for d in devices {
                print("\(d.id)\t\(d.label)\t\(d.modes.rawValue)\t\(d.host)\t\(d.note)")
            }

        case "status":
            let st = await Reachability.refresh(devices)
            print("ScreenBar 设备状态:")
            for d in devices {
                let s = st[d.id] ?? DeviceStatus()
                let state = s.active ? "副屏中" : (s.viewing ? "查看中" : (s.online ? "在线" : "离线"))
                let extra = (d.modes.canView && s.viewable) ? " · 可查看" : ""
                let link = s.online && !s.link.label.isEmpty ? " · \(s.link.label)" : ""
                print("  \(d.id.padded(8)) \(d.label.padded(12)) \(state)\(extra)\(link)")
            }

        case "connect":
            guard let d = find(rest.first) else { return usage("connect <id>") }
            await Connector.connectScreen(d)
            print("已触发「\(d.label)」当 M5 副屏(记得在对方机器选「标准」)")

        case "disconnect":
            guard let d = find(rest.first) else { return usage("disconnect <id>") }
            let st = await Reachability.refresh(devices)
            let others = devices.contains { $0.id != d.id && (st[$0.id]?.active ?? false) }
            await Connector.disconnectScreen(d, anyOtherActive: others)
            print("已断开「\(d.label)」")

        case "view":
            guard let d = find(rest.first) else { return usage("view <id>") }
            await Connector.startViewing(d)
            print("已在 M5 上打开查看「\(d.label)」")

        case "unview":
            await RemoteControl.viewClose()
            print("已关闭 M5 上的所有查看窗口")

        case "jump":
            guard let d = find(rest.first) else { return usage("jump <id>") }
            guard let jid = d.jumpID, !jid.isEmpty else { print("「\(d.label)」没配 jumpID(设备管理里填 Jump 电脑 ID)"); return }
            await RemoteControl.jumpView(d)
            print("已用 Jump 打开「\(d.label)」(Fluid,中继也流畅)")

        case "doctor":
            let (env, devs) = await Diagnostics.run(devices)
            print("ScreenBar 自检\n\n环境:")
            for c in env { print("  \(c.level.rawValue) \(c.name) — \(c.detail)") }
            print("\n设备:")
            for (d, cs) in devs {
                print("  ▸ \(d.label)(\(d.id))")
                for c in cs { print("      \(c.level.rawValue) \(c.name) — \(c.detail)") }
            }

        case "wake":
            guard let d = find(rest.first) else { return usage("wake <id>") }
            guard let mac = d.macAddress else { print("「\(d.label)」无 MAC,无法唤醒"); return }
            print(RemoteControl.wake(mac: mac) ? "已发送唤醒包给「\(d.label)」" : "唤醒发送失败")

        default:
            printHelp()
        }
    }

    private static func usage(_ u: String) { print("用法: screenbar \(u)") }

    private static func printHelp() {
        print("""
        ScreenBar CLI — M5 副屏 / 投屏控制(无参数则启动菜单栏 GUI)
          status            查看所有设备状态
          list              列出设备(id 名 方向 host 备注)
          connect <id>      让设备当 M5 副屏
          disconnect <id>   断开副屏
          view <id>         在 M5 上查看该设备屏幕(VNC)
          unview            关闭 M5 上的查看
          jump <id>         用 Jump Desktop 查看(Fluid,中继也流畅)
          wake <id>         Wake-on-LAN 唤醒
          doctor            自检环境 + 每台设备就绪度(连不上先跑这个)
        """)
    }
}

private extension String {
    func padded(_ n: Int) -> String {
        count >= n ? self : self + String(repeating: " ", count: n - count)
    }
}
