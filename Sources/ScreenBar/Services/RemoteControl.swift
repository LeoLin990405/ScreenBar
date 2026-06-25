import Foundation

/// 远程控制:触发对方连回 M5 当副屏、M5 查看对方、唤醒(WoL)、开共享、抓 MAC。
enum RemoteControl {
    private static let sshOpts = ["-o", "ConnectTimeout=12", "-o", "BatchMode=yes"]

    // MARK: 副屏方向(对方机器连回 M5)
    static func screenConnect(_ d: Device) async {
        if let t = d.triggerOn, !t.isEmpty {
            _ = await Shell.bash(t, timeout: 30); return
        }
        guard d.sshTarget != "-", !d.sshTarget.isEmpty else { return }
        // 对方起一条记 PID 的 caffeinate(只防这条连接的息屏)+ open vnc 连回 M5
        let remote = "nohup caffeinate -d >/dev/null 2>&1 & echo $! > /tmp/.screenbar-caf; open vnc://\(Constants.m5VNCHost)"
        _ = await Shell.run("/usr/bin/ssh", sshOpts + [d.sshTarget, remote], timeout: 25)
    }

    static func screenDisconnect(_ d: Device) async {
        if let t = d.triggerOff, !t.isEmpty {
            _ = await Shell.bash(t, timeout: 30); return
        }
        guard d.sshTarget != "-", !d.sshTarget.isEmpty else { return }
        let remote = "[ -f /tmp/.screenbar-caf ] && kill $(cat /tmp/.screenbar-caf) 2>/dev/null; rm -f /tmp/.screenbar-caf; osascript -e 'quit app \"Screen Sharing\"'"
        _ = await Shell.run("/usr/bin/ssh", sshOpts + [d.sshTarget, remote], timeout: 25)
    }

    // MARK: 查看方向(M5 显示对方)
    static func viewOpen(_ d: Device) async {
        _ = await Shell.run("/usr/bin/open", ["vnc://\(d.host)"])
    }

    /// 用 Jump Desktop(Fluid 协议)查看 —— 中继链路也流畅。需 device.jumpID。
    static func jumpView(_ d: Device) async {
        guard let jid = d.jumpID, !jid.isEmpty else { return }
        _ = await Shell.run("/usr/bin/open", ["jump://connect?id=\(jid)"])
    }
    /// 关闭 Jump Desktop 的查看窗口(退出 app)。
    static func jumpClose() async {
        _ = await Shell.run("/usr/bin/osascript", ["-e", "tell application \"Jump Desktop\" to quit"])
    }
    static func viewClose() async {
        _ = await Shell.run("/usr/bin/osascript", ["-e", "tell application \"Screen Sharing\" to quit"])
    }

    // MARK: 唤醒(Wake-on-LAN)
    /// 构造 WoL 魔术包:6×0xFF + MAC×16。纯函数,可测。
    static func magicPacket(mac: String) -> Data? {
        let bytes = mac.split(whereSeparator: { $0 == ":" || $0 == "-" }).compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return nil }
        var data = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { data.append(contentsOf: bytes) }
        return data
    }

    @discardableResult
    static func wake(mac: String, broadcast: String = "255.255.255.255", port: UInt16 = 9) -> Bool {
        guard let packet = magicPacket(mac: mac) else { return false }
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, broadcast, &addr.sin_addr)
        let sent: Int = packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { ap in
                ap.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, raw.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        return sent > 0
    }

    /// 在线时抓对方 en0 MAC(自动填充,供 WoL)。
    static func fetchMAC(_ d: Device) async -> String? {
        guard d.sshTarget != "-", !d.sshTarget.isEmpty else { return nil }
        let r = await Shell.run("/usr/bin/ssh", sshOpts + [d.sshTarget, "ifconfig en0 | awk '/ether/{print $2}'"], timeout: 12)
        let mac = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return mac.count == 17 ? mac : nil
    }

    /// 一键尝试开对方屏幕共享。仅当对方 sudo 免密(NOPASSWD)时成功;否则失败 → UI 提示手动开。
    /// (本工具不经手任何密码;远端 sudo 策略由用户自行设定。)
    static func enableScreenSharing(_ d: Device) async -> Bool {
        guard d.sshTarget != "-", !d.sshTarget.isEmpty else { return false }
        let kick = "sudo -n /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -restart -agent -privs -all"
        return await Shell.run("/usr/bin/ssh", sshOpts + [d.sshTarget, kick], timeout: 20).ok
    }
}
