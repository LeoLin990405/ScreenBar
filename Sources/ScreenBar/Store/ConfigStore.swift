import Foundation
import Observation

/// 设备清单的持久化存储(JSON,取代旧 TSV devices.conf)。供菜单与设备管理 GUI 读写。
@MainActor
@Observable
final class ConfigStore {
    private(set) var devices: [Device] = []

    init() { load() }

    func load() {
        let url = URL(fileURLWithPath: Constants.configJSON)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Device].self, from: data) {
            devices = decoded
            Log.info("loaded \(decoded.count) devices from json")
        } else {
            devices = ConfigStore.seed
            save()
            Log.info("seeded default \(devices.count) devices")
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(atPath: Constants.configDir, withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try enc.encode(devices)
            try data.write(to: URL(fileURLWithPath: Constants.configJSON))
        } catch {
            Log.error("save config failed: \(error.localizedDescription)")
        }
    }

    func upsert(_ d: Device) {
        if let i = devices.firstIndex(where: { $0.id == d.id }) { devices[i] = d } else { devices.append(d) }
        save()
    }

    func remove(id: String) {
        devices.removeAll { $0.id == id }
        save()
    }

    func device(_ id: String) -> Device? { devices.first { $0.id == id } }

    /// 无隔离地读设备清单(供 CLI / 非 MainActor 场景)。无 json 则用种子。
    nonisolated static func loadDevices() -> [Device] {
        let url = URL(fileURLWithPath: Constants.configJSON)
        if let data = try? Data(contentsOf: url),
           let d = try? JSONDecoder().decode([Device].self, from: data) {
            return d
        }
        return seed
    }

    /// 首次运行的占位示例设备(演示三种 modes + trigger 覆盖)。
    /// 真实设备请在「设置 / 设备管理」里增改 —— 存 ~/.config/screenbar/devices.json(不进仓库)。
    /// IP 用 RFC5737 文档段 192.0.2.0/24;实际应填各机器的 Tailscale IP。
    nonisolated static var seed: [Device] {
        [
            // 既能当本机副屏、也能投过来看
            Device(id: "mac1", label: "Example-Mac", modes: .both, host: "192.0.2.10", sshTarget: "example-host",
                   note: "示例:副屏+查看", resolution: "1440x900"),
            // 无头机:只查看(在「设置」填 jumpID 可走 Jump Desktop Fluid)
            Device(id: "mini1", label: "Example-Headless", modes: .view, host: "192.0.2.11", sshTarget: "example-mini",
                   note: "示例:无头机,仅查看"),
            // 自定义触发覆盖(如先停某服务、双跳 ssh):填 triggerOn/triggerOff 整条命令
            Device(id: "mac2", label: "Example-Override", modes: .screen, host: "192.0.2.12", sshTarget: "-",
                   note: "示例:自定义触发", resolution: "1440x900",
                   triggerOn: #"ssh -o ConnectTimeout=12 example-host '~/bin/connect-as-second-screen'"#,
                   triggerOff: #"ssh -o ConnectTimeout=12 example-host '~/bin/stop-second-screen'"#),
        ]
    }
}
