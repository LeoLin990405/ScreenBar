import Foundation
import ServiceManagement

/// 开机自启(SMAppService)。仅在以正式 .app bundle 运行时生效。
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            Log.info("launch-at-login set \(on)")
        } catch {
            Log.error("launch-at-login failed: \(error.localizedDescription)")
        }
    }
}
