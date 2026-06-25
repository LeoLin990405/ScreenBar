import Foundation
import Observation
import Network

/// 中枢:持有设备清单 + 实时状态,驱动轮询/网络变化/自动连接,暴露给 UI 的动作。
@MainActor
@Observable
final class AppModel {
    let store: ConfigStore
    private(set) var status: [String: DeviceStatus] = [:]
    private(set) var busy: Set<String> = []        // 连/断进行中(防重复点击 + 菜单转圈)

    private var suppressedAuto: Set<String> = []    // 用户手动断开的,暂不自动重连(直到它下线再上线)
    private var macTried: Set<String> = []          // 本会话已尝试抓 MAC 的设备(避免每轮重试)
    private var managedVScreens: Set<String> = []   // app 为之连了虚拟屏的设备(孤儿清理用)
    private var orphanStrikes: [String: Int] = [:]  // 连续 N 轮未 active 计数(3 次=36s 宽限后清孤儿)
    private var timer: Timer?
    private var monitor: NWPathMonitor?

    init(store: ConfigStore = ConfigStore()) {
        self.store = store
        loadStatusDump()        // 启动即用上次状态,避免菜单首建闪「全离线」
        startTimer()
        startNetworkMonitor()
        Task { await refresh() }
    }

    private func loadStatusDump() {
        let url = URL(fileURLWithPath: Constants.configDir + "/status.json")
        guard let data = try? Data(contentsOf: url),
              let dump = try? JSONDecoder().decode(StatusDump.self, from: data) else { return }
        var s: [String: DeviceStatus] = [:]
        for e in dump.devices {
            s[e.id] = DeviceStatus(online: e.online, viewable: e.viewable, active: e.active, viewing: e.viewing)
        }
        status = s
    }

    func st(_ id: String) -> DeviceStatus { status[id] ?? DeviceStatus() }
    func isBusy(_ id: String) -> Bool { busy.contains(id) }
    var anyConnected: Bool { store.devices.contains { st($0.id).active || st($0.id).viewing } }

    // MARK: 轮询
    private func startTimer() {
        let t = Timer(timeInterval: Constants.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func startNetworkMonitor() {
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        m.start(queue: DispatchQueue.global(qos: .utility))
        monitor = m
    }

    func refresh() async {
        let devs = store.devices
        status = await Reachability.refresh(devs)
        writeStatusDump()
        await cleanupOrphanScreens()
        await backfillMACs()
        await evaluateAutoConnect()
    }

    /// 导出富状态到 ~/.config/screenbar/status.json(带时间戳+设备元数据,供状态墙/CLI/诊断)。
    private func writeStatusDump() {
        let entries = store.devices.map { d -> StatusDump.Entry in
            let s = st(d.id)
            return .init(id: d.id, label: d.label, modes: d.modes.rawValue, host: d.host,
                         online: s.online, viewable: s.viewable, active: s.active, viewing: s.viewing,
                         link: s.link.rawValue)
        }
        let dump = StatusDump(updated: ISO8601DateFormatter().string(from: Date()), devices: entries)
        let url = URL(fileURLWithPath: Constants.configDir + "/status.json")
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(dump) { try? data.write(to: url) }
    }

    /// 孤儿虚拟屏清理:app 连过虚拟屏的设备若连续 3 轮(~36s 宽限,避开登录中)未 active → 断其虚拟屏。
    private func cleanupOrphanScreens() async {
        for id in managedVScreens {
            if st(id).active { orphanStrikes[id] = 0; continue }
            orphanStrikes[id, default: 0] += 1
            if orphanStrikes[id, default: 0] >= 3 {
                if let d = store.device(id) {
                    await VirtualDisplay.disconnect(name: d.virtualScreenName)
                    Log.info("orphan virtual screen \(d.virtualScreenName) cleaned")
                }
                managedVScreens.remove(id); orphanStrikes[id] = nil
            }
        }
        if !store.devices.contains(where: { st($0.id).active }) && managedVScreens.isEmpty {
            await Connector.releaseCaffeine()
        }
    }

    /// 连接后验证:18s 内轮询是否真连上,连上报 ✓,否则给可操作提示(失败可见)。
    private func verifyConnection(_ d: Device, isView: Bool) async {
        for _ in 0 ..< 6 {
            try? await Task.sleep(for: .seconds(3))
            let c = await Reachability.connections()
            let ok = isView ? c.outbound.contains(d.host) : c.inbound.contains(d.host)
            if ok { Connector.notify("\(d.label) 已连上 ✓"); return }
        }
        let hint = isView ? "检查对方是否开了屏幕共享" : "完成对方登录框后会自动显示;否则检查屏幕共享 / 是否开盖"
        Connector.notify("\(d.label) 18s 内未检测到连上 — \(hint)")
    }

    /// 在线且没记 MAC 的设备,后台抓 en0 MAC 存上(供 WoL)。每设备本会话只试一次。
    private func backfillMACs() async {
        for d in store.devices where d.macAddress == nil && st(d.id).online && d.sshTarget != "-" && !macTried.contains(d.id) {
            macTried.insert(d.id)
            if let mac = await RemoteControl.fetchMAC(d) {
                var nd = d; nd.macAddress = mac; store.upsert(nd)
            }
        }
    }

    /// 自动连接 + 自动重连:autoConnect 设备一上线就挂为副屏。
    private func evaluateAutoConnect() async {
        for d in store.devices where d.autoConnect && d.modes.canScreen {
            let s = st(d.id)
            if !s.online { suppressedAuto.remove(d.id); continue }   // 下线 → 清除抑制,下次上线重新自动连
            if s.active || busy.contains(d.id) { continue }
            if suppressedAuto.contains(d.id) { continue }            // 用户手动断过,先别抢回来
            await connectScreen(d)
        }
    }

    // MARK: 动作
    func connectScreen(_ d: Device) async {
        guard !busy.contains(d.id) else { return }
        busy.insert(d.id)
        suppressedAuto.remove(d.id)
        managedVScreens.insert(d.id); orphanStrikes[d.id] = 0
        await Connector.connectScreen(d)
        busy.remove(d.id)
        await refresh()
        Task { await self.verifyConnection(d, isView: false) }   // 后台验证,不阻塞按钮
    }

    func disconnectScreen(_ d: Device) async {
        guard !busy.contains(d.id) else { return }
        busy.insert(d.id); defer { busy.remove(d.id) }
        let others = store.devices.contains { $0.id != d.id && st($0.id).active }
        await Connector.disconnectScreen(d, anyOtherActive: others)
        managedVScreens.remove(d.id); orphanStrikes[d.id] = nil
        suppressedAuto.insert(d.id)
        await refresh()
    }

    func startViewing(_ d: Device) async {
        guard !busy.contains(d.id) else { return }
        busy.insert(d.id)
        await Connector.startViewing(d)
        busy.remove(d.id)
        await refresh()
        Task { await self.verifyConnection(d, isView: true) }
    }

    /// 用 Jump Desktop(Fluid)查看 —— 中继链路流畅。注:Jump 走自有协议,
    /// 不经 5900,故 viewing 状态不点亮(无法用 netstat 检测),按钮始终为「用 Jump 看」。
    func jumpView(_ d: Device) async {
        guard let jid = d.jumpID, !jid.isEmpty else { return }
        await RemoteControl.jumpView(d)
        Connector.notify("正在用 Jump 看 \(d.label)（Fluid,中继也流畅）")
    }

    func stopViewing(_ d: Device) async {
        guard !busy.contains(d.id) else { return }
        busy.insert(d.id); defer { busy.remove(d.id) }
        await Connector.stopViewing(d)
        await refresh()
    }

    func wake(_ d: Device) {
        guard let mac = d.macAddress else {
            Connector.notify("\(d.label) 还没记录 MAC,无法唤醒(上线一次会自动抓取)")
            return
        }
        let ok = RemoteControl.wake(mac: mac)
        Connector.notify(ok ? "已发送唤醒包给 \(d.label)" : "唤醒发送失败 \(d.label)")
    }

    func enableSharing(_ d: Device) async {
        let ok = await RemoteControl.enableScreenSharing(d)
        Connector.notify(ok ? "\(d.label) 已开启屏幕共享" : "\(d.label) 需手动开屏幕共享(远端 sudo 非免密)")
        await refresh()
    }
}
