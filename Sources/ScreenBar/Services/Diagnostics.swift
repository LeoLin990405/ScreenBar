import Foundation

/// 一键自检:环境前置 + 每台设备「能不能连、卡在哪」。供 CLI `screenbar doctor`。
enum Diagnostics {
    struct Check: Sendable {
        enum Level: String, Sendable { case ok = "✓", warn = "⚠", fail = "✗" }
        let level: Level
        let name: String
        let detail: String
    }

    static func run(_ devices: [Device]) async -> (env: [Check], devices: [(Device, [Check])]) {
        var env: [Check] = []

        // BetterDisplay(副屏方向需要)
        let bd = FileManager.default.isExecutableFile(atPath: Constants.betterDisplayCLI)
        env.append(.init(level: bd ? .ok : .fail, name: "BetterDisplay CLI",
                         detail: bd ? Constants.betterDisplayCLI : "缺失,副屏方向不可用"))

        // Tailscale(链路检测 / Jump 依赖)
        let links = await Tailscale.links()
        env.append(.init(level: links.isEmpty ? .warn : .ok, name: "Tailscale",
                         detail: links.isEmpty ? "拿不到 peer(检查 CLI/代理)" : "\(links.count) peers"))

        // Jump 查看端(查看方向走 Jump 时需要)
        let jumpApp = ["\(NSHomeDirectory())/Applications/Jump Desktop.app", "/Applications/Jump Desktop.app"]
            .contains { FileManager.default.fileExists(atPath: $0) }
        env.append(.init(level: jumpApp ? .ok : .warn, name: "Jump 查看端",
                         detail: jumpApp ? "已装" : "未装(Jump 路不可用,VNC 不受影响)"))

        // M5 自身屏幕共享(供对方「当副屏」连入 M5:5900)
        let m5 = await localPortListening(5900)
        env.append(.init(level: m5 ? .ok : .warn, name: "M5 屏幕共享(供对方当副屏连入)",
                         detail: m5 ? ":5900 在监听" : "M5:5900 没开?对方当副屏会连不上"))

        var devChecks: [(Device, [Check])] = []
        for d in devices {
            var cs: [Check] = []
            let online = await Reachability.portOpen(d.host, d.sshPort)
            cs.append(.init(level: online ? .ok : .warn, name: "在线",
                            detail: online ? "TS \(d.host):\(d.sshPort) 通" : "不可达(离线/休眠)"))
            if online {
                let link = links[d.host] ?? .unknown
                cs.append(.init(level: link == .direct ? .ok : .warn, name: "链路",
                                detail: link == .direct ? "直连(低延迟)"
                                      : link == .relay ? "中继(当副屏会卡;查看可忍/建议走 Jump)"
                                      : "未知"))
                if d.modes.canScreen {
                    let trig = d.triggerOn != nil || (d.sshTarget != "-" && !d.sshTarget.isEmpty)
                    cs.append(.init(level: trig ? .ok : .fail, name: "当副屏就绪",
                                    detail: trig ? "有触发方式" : "无 ssh-target/trigger,连不了"))
                }
                if d.modes.canView {
                    let hasJump = (d.jumpID ?? "").isEmpty == false
                    let vnc = await Reachability.portOpen(d.host, 5900)
                    if hasJump {
                        cs.append(.init(level: .ok, name: "查看就绪", detail: "Jump(Fluid)已配 jumpID"))
                    } else if vnc {
                        cs.append(.init(level: .ok, name: "查看就绪", detail: "VNC :5900 开(密码=对方屏幕共享密码)"))
                    } else {
                        cs.append(.init(level: .warn, name: "查看就绪", detail: "对方没开屏幕共享、也没配 jumpID"))
                    }
                }
            }
            devChecks.append((d, cs))
        }
        return (env, devChecks)
    }

    private static func localPortListening(_ port: Int) async -> Bool {
        let r = await Shell.run(Constants.netstat, ["-an"])
        return r.stdout.split(separator: "\n").contains { line in
            let f = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            return f.count >= 6 && f[5] == "LISTEN" && f[3].hasSuffix(".\(port)")
        }
    }
}
