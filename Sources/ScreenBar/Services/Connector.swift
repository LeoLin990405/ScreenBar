import Foundation

/// 编排连/断:M5 侧资源(caffeinate 防睡 / 虚拟屏)+ 对方触发。
enum Connector {
    // MARK: 副屏方向
    static func connectScreen(_ d: Device) async {
        await caffeinateStart()
        await VirtualDisplay.ensure(name: d.virtualScreenName, resolution: d.resolution, hiDPI: d.hiDPI)
        await RemoteControl.screenConnect(d)
        notify("\(d.label) 副屏已触发 — 在对方机器选「标准」别选「高质量」(否则 M5 黑屏)")
    }

    /// anyOtherActive: 除本设备外是否还有别的设备在当副屏(决定是否收回 M5 侧 caffeinate)。
    static func disconnectScreen(_ d: Device, anyOtherActive: Bool) async {
        await RemoteControl.screenDisconnect(d)
        await VirtualDisplay.disconnect(name: d.virtualScreenName)
        if !anyOtherActive { await releaseCaffeine() }
        notify("\(d.label) 已断开")
    }

    // MARK: 查看方向
    static func startViewing(_ d: Device) async {
        await RemoteControl.viewOpen(d)
        notify("正在 M5 上查看 \(d.label)（M5 是查看端,不会黑屏;选「标准」即可）")
    }
    static func stopViewing(_ d: Device) async {
        await RemoteControl.viewClose()
        notify("已关闭查看 \(d.label)（会关掉 M5 上所有查看窗口）")
    }

    // MARK: M5 侧防息屏
    private static func caffeinateStart() async {
        _ = await Shell.bash("pkill -f 'caffeinate .*-d' 2>/dev/null; nohup caffeinate -d >/dev/null 2>&1 &")
    }
    /// 收回 M5 侧 caffeinate(无设备在当副屏时调用,含孤儿清理)。
    static func releaseCaffeine() async {
        _ = await Shell.bash("pkill -f 'caffeinate .*-d' 2>/dev/null")
    }

    // MARK: 通知
    static func notify(_ body: String) {
        let safe = body.replacingOccurrences(of: "\"", with: "“")
        Task { _ = await Shell.run("/usr/bin/osascript", ["-e", "display notification \"\(safe)\" with title \"ScreenBar\""]) }
    }
}
