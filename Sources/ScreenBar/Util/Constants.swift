import Foundation

/// 全局常量与路径。
enum Constants {
    /// 本机(运行 ScreenBar 的 Mac)的 Tailscale IP —— 副屏方向时对方 `open vnc://` 连这里。
    /// 从 ~/.config/screenbar/m5host 读(不进仓库);缺省占位,请改成本机 Tailscale IP。
    static var m5VNCHost: String {
        let f = configDir + "/m5host"
        if let s = try? String(contentsOfFile: f, encoding: .utf8) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return "100.64.0.1"   // 占位:写本机 Tailscale IP 到 ~/.config/screenbar/m5host
    }

    static let betterDisplayCLI = "/opt/homebrew/bin/betterdisplaycli"
    static let netstat = "/usr/sbin/netstat"   // ⚠ 在 /usr/sbin 不是 /usr/bin

    static let configDir = NSHomeDirectory() + "/.config/screenbar"
    static let configJSON = configDir + "/devices.json"

    /// 状态轮询间隔(秒)。
    static let pollInterval: TimeInterval = 12

    static let bundleID = "com.leo.screenbar"
}
