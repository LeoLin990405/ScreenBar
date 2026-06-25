import SwiftUI

/// 菜单栏弹窗面板(.window 样式 → @Observable 状态变化实时重绘,不再卡在启动快照)。
struct MenuView: View {
    let model: AppModel

    private var screenDevs: [Device] { model.store.devices.filter { $0.modes.canScreen } }
    private var viewDevs: [Device] { model.store.devices.filter { $0.modes.canView } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider()

            if model.store.devices.isEmpty {
                Text("无设备 — 点「设置 / 设备管理…」添加")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
            }
            if !screenDevs.isEmpty {
                sectionTitle("当 M5 副屏（对方显示 M5）")
                ForEach(screenDevs) { screenRow($0) }
            }
            if !viewDevs.isEmpty {
                if !screenDevs.isEmpty { Divider().padding(.vertical, 2) }
                sectionTitle("投屏到 M5 查看（M5 显示对方）")
                ForEach(viewDevs) { viewRow($0) }
            }

            Divider()
            Text("⚠︎ 当副屏时在对方机器选「标准」别选「高质量」")
                .font(.caption2).foregroundStyle(.orange)
            footer
        }
        .padding(12)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)   // 高度随内容,避免子视图被压塌
        .task { await model.refresh() }   // 弹窗出现即刷新
    }

    private var header: some View {
        HStack {
            Image(systemName: "display.2").foregroundStyle(model.anyConnected ? .green : .secondary)
            Text("ScreenBar").font(.headline)
            Spacer()
            Text(headerStatus).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var headerStatus: String {
        let a = model.store.devices.filter { model.st($0.id).active }.count
        let v = model.store.devices.filter { model.st($0.id).viewing }.count
        if a == 0 && v == 0 { return "未连接" }
        var p: [String] = []
        if a > 0 { p.append("副屏 \(a)") }
        if v > 0 { p.append("查看 \(v)") }
        return p.joined(separator: " · ")
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.caption).foregroundStyle(.secondary)
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }

    /// 直连/中继标签(中继=橙色提醒会卡)。
    @ViewBuilder
    private func linkTag(_ s: DeviceStatus) -> some View {
        if s.online, !s.link.label.isEmpty {
            Text(s.link.label).font(.caption2)
                .foregroundStyle(s.link == .direct ? Color.secondary : Color.orange)
        }
    }

    @ViewBuilder
    private func screenRow(_ d: Device) -> some View {
        let s = model.st(d.id)
        HStack(spacing: 8) {
            dot(s.active ? .green : s.online ? .green.opacity(0.45) : .gray.opacity(0.4))
            Text(d.label)
            linkTag(s)
            Spacer()
            if model.isBusy(d.id) {
                ProgressView().controlSize(.small)
            } else if s.active {
                Button("断开") { Task { await model.disconnectScreen(d) } }
            } else if s.online {
                Button("当副屏") { Task { await model.connectScreen(d) } }
            } else {
                Button("唤醒") { model.wake(d) }.disabled(d.macAddress == nil)
            }
        }
    }

    @ViewBuilder
    private func viewRow(_ d: Device) -> some View {
        let s = model.st(d.id)
        HStack(spacing: 8) {
            dot(s.viewing ? .green : s.viewable ? .green.opacity(0.45) : s.online ? .orange.opacity(0.6) : .gray.opacity(0.4))
            Text(d.label)
            linkTag(s)
            Spacer()
            if model.isBusy(d.id) {
                ProgressView().controlSize(.small)
            } else if s.viewing {
                Button("关闭查看") { Task { await model.stopViewing(d) } }
            } else if let jid = d.jumpID, !jid.isEmpty, s.online {
                Button("用 Jump 看") { Task { await model.jumpView(d) } }
            } else if s.viewable {
                Button("投过来看") { Task { await model.startViewing(d) } }
            } else if s.online {
                Button("开共享") { Task { await model.enableSharing(d) } }
            } else {
                Button("唤醒") { model.wake(d) }.disabled(d.macAddress == nil)
            }
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink { Text("设置 / 设备管理…") }
            Spacer()
            Button("刷新") { Task { await model.refresh() } }
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
        .font(.caption)
    }
}
