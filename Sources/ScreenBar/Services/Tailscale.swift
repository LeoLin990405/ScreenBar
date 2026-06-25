import Foundation

/// 查询 Tailscale 各 peer 的链路类型(直连/中继),判断「能不能当低延迟副屏」。
enum Tailscale {
    /// App Store 版二进制直接跑会「GUI failed to start」(要 GUI 的 XPC);
    /// 标准 CLI(/usr/local/bin 的 zsh wrapper 等)在 launchd 守护进程环境可用。优先用它。
    static var cli: String {
        let candidates = [
            "/usr/local/bin/tailscale",
            NSHomeDirectory() + "/bin/tailscale",
            "/opt/homebrew/bin/tailscale",
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    }

    private struct Status: Decodable { let Peer: [String: Peer]? }
    private struct Peer: Decodable {
        let TailscaleIPs: [String]?
        let CurAddr: String?
        let Relay: String?
        let Online: Bool?
    }

    /// 纯函数:解析 `tailscale status --json` → { TS IP: 链路类型 }。可测。
    static func parse(_ json: String) -> [String: LinkType] {
        guard let data = json.data(using: .utf8),
              let st = try? JSONDecoder().decode(Status.self, from: data) else { return [:] }
        var out: [String: LinkType] = [:]
        for (_, p) in st.Peer ?? [:] {
            guard let ip = p.TailscaleIPs?.first(where: { !$0.contains(":") }) else { continue }
            if p.Online != true {
                out[ip] = .unknown
            } else if let cur = p.CurAddr, !cur.isEmpty {
                out[ip] = .direct
            } else if let relay = p.Relay, !relay.isEmpty {
                out[ip] = .relay
            } else {
                out[ip] = .unknown
            }
        }
        return out
    }

    static func links() async -> [String: LinkType] {
        // Tailscale CLI(Go)会走 ALL_PROXY 去连本地 daemon → launchd 继承的全局代理会让它失败。
        // 调用时剥掉代理变量。
        var env = ProcessInfo.processInfo.environment
        for k in ["ALL_PROXY", "all_proxy", "HTTP_PROXY", "http_proxy", "HTTPS_PROXY", "https_proxy"] {
            env.removeValue(forKey: k)
        }
        let r = await Shell.run(cli, ["status", "--json"], env: env)
        guard r.ok else { return [:] }
        return parse(r.stdout)
    }
}
