import Foundation

/// Tailscale 链路类型:直连(同局域网/打洞成功,低延迟,适合当副屏)/ 中继(走 DERP,高延迟,当副屏会卡)。
enum LinkType: String, Codable, Sendable {
    case direct   // 直连
    case relay    // 中继
    case unknown  // 未知/离线

    var label: String {
        switch self {
        case .direct: "直连"
        case .relay: "中继·会卡"
        case .unknown: ""
        }
    }
}

/// 一台设备的实时状态(由 Reachability 每轮刷新)。
struct DeviceStatus: Sendable, Equatable, Codable {
    var online = false    // Tailscale :sshPort 可达(在线)
    var viewable = false  // 对方 :5900 开着 → M5 可查看它
    var active = false    // 对方此刻正当 M5 副屏(它显示 M5)
    var viewing = false   // M5 此刻正查看该设备(M5 显示它)
    var link: LinkType = .unknown  // 直连 / 中继(决定当副屏跟不跟手)
}
