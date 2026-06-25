import Foundation

/// 设备支持的方向。
enum DeviceMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case screen   // 当 M5 副屏(对方显示 M5)
    case view     // 投到 M5 查看(M5 显示对方)
    case both

    var id: String { rawValue }
    var canScreen: Bool { self == .screen || self == .both }
    var canView: Bool { self == .view || self == .both }
    var label: String {
        switch self {
        case .screen: "当副屏"
        case .view: "查看"
        case .both: "副屏+查看"
        }
    }
}

/// 一台可投屏的设备。持久化为 JSON(取代旧 devices.conf)。
struct Device: Codable, Identifiable, Sendable, Hashable {
    var id: String              // 短 id,如 "m2"
    var label: String           // 菜单显示名
    var modes: DeviceMode
    var host: String            // Tailscale IP(可达探测 + 查看时 open vnc 的目标)
    var sshPort: Int = 22
    var sshTarget: String = "-" // M5→设备的 ssh 别名/user@ip;"-" 表示不用(走 trigger 覆盖或 view-only)
    var note: String = ""

    // —— 副屏方向:每设备独立虚拟屏参数(真·多显示器)——
    var resolution: String = "1440x900"
    var hiDPI: Bool = false

    // —— 自动连接(副屏方向):该设备一上线就自动挂为副屏 ——
    var autoConnect: Bool = false

    // —— 唤醒 ——
    var macAddress: String? = nil   // Wake-on-LAN 用

    // —— 查看协议:有 jumpID 则「投过来看」走 Jump Desktop(Fluid,中继也流畅);否则走 VNC ——
    var jumpID: String? = nil       // Jump Desktop 电脑 ID(UUID)

    // —— 特例:整条本机侧命令覆盖(如连接前先停某服务、或双跳 ssh)。nil = 走默认逻辑 ——
    var triggerOn: String? = nil
    var triggerOff: String? = nil

    /// 该设备专属虚拟屏名(真·多显示器:每台一块)。
    var virtualScreenName: String { "ScreenBar-\(id)" }
}
