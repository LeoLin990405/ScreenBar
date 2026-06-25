import Foundation

/// 探测设备在线/可查看,并解析 netstat 得出真实连接方向。
enum Reachability {
    /// 纯函数:解析 `netstat -an` 输出 → (作为副屏连入 M5 的对端IP, 被 M5 查看的对端IP)。
    /// 入向:本地地址 `*.5900`(M5 当服务端=对方当副屏);出向:对端地址 `*.5900`(M5 当客户端=M5 在查看)。
    static func parseConnections(_ netstatOutput: String) -> (inbound: Set<String>, outbound: Set<String>) {
        var inb = Set<String>(), outb = Set<String>()
        for raw in netstatOutput.split(separator: "\n") {
            let f = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard f.count >= 6, f[5] == "ESTABLISHED" else { continue }
            let local = f[3], foreign = f[4]
            if local.hasSuffix(".5900") {
                inb.insert(stripPort(foreign))
            } else if foreign.hasSuffix(".5900") {
                outb.insert(stripPort(foreign))
            }
        }
        return (inb, outb)
    }

    /// 去掉 `IP.port` 末尾端口 → IP。
    static func stripPort(_ s: String) -> String {
        guard let dot = s.lastIndex(of: ".") else { return s }
        return String(s[s.startIndex..<dot])
    }

    static func connections() async -> (inbound: Set<String>, outbound: Set<String>) {
        let r = await Shell.run(Constants.netstat, ["-an"])
        return parseConnections(r.stdout)
    }

    /// nc -z 探端口(单次 -G5;DERP relay 冷路径要够长,靠 TCP 自身重传容忍丢包)。
    static func portOpen(_ host: String, _ port: Int) async -> Bool {
        await Shell.run("/usr/bin/nc", ["-z", "-G5", host, String(port)]).ok
    }

    /// 并行刷新全部设备状态。
    static func refresh(_ devices: [Device]) async -> [String: DeviceStatus] {
        let conns = await connections()
        let links = await Tailscale.links()
        return await withTaskGroup(of: (String, DeviceStatus).self) { group in
            for d in devices {
                group.addTask {
                    var st = DeviceStatus()
                    st.online = await portOpen(d.host, d.sshPort)
                    if st.online && d.modes.canView {
                        st.viewable = await portOpen(d.host, 5900)
                    }
                    st.active = conns.inbound.contains(d.host)
                    st.viewing = conns.outbound.contains(d.host)
                    st.link = st.online ? (links[d.host] ?? .unknown) : .unknown
                    return (d.id, st)
                }
            }
            var out: [String: DeviceStatus] = [:]
            for await (id, st) in group { out[id] = st }
            return out
        }
    }
}
