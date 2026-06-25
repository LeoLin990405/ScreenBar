import Foundation

/// 导出到 ~/.config/screenbar/status.json 的结构(自描述 + 带时间戳,供状态墙/CLI/诊断复用)。
struct StatusDump: Codable, Sendable {
    var updated: String              // ISO8601 时间戳
    var devices: [Entry]

    struct Entry: Codable, Sendable {
        let id: String
        let label: String
        let modes: String
        let host: String
        let online: Bool
        let viewable: Bool
        let active: Bool
        let viewing: Bool
        let link: String   // direct / relay / unknown
    }
}
