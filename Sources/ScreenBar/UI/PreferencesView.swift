import SwiftUI

/// 设置 / 设备管理 GUI(Settings 窗口)。增删改设备、开机自启、手动刷新。
struct PreferencesView: View {
    let model: AppModel
    @State private var editing: Device?
    @State private var isNew = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设备").font(.headline)
            Table(model.store.devices) {
                TableColumn("名称") { Text($0.label) }
                TableColumn("方向") { Text($0.modes.label) }
                TableColumn("主机") { Text($0.host).font(.system(.body, design: .monospaced)) }
                TableColumn("状态") { d in
                    let s = model.st(d.id)
                    Text(s.active ? "副屏中" : s.viewing ? "查看中" : s.online ? "在线" : "离线")
                        .foregroundStyle(s.online ? .green : .secondary)
                }
                TableColumn("操作") { d in
                    HStack {
                        Button("编辑") { isNew = false; editing = d }
                        Button("删除", role: .destructive) {
                            model.store.remove(id: d.id)
                            Task { await VirtualDisplay.discard(name: d.virtualScreenName) }
                        }
                    }
                }
            }
            .frame(minHeight: 240)

            HStack {
                Button("＋ 新增设备") {
                    isNew = true
                    editing = Device(id: "", label: "", modes: .both, host: "")
                }
                Spacer()
                Button("立即刷新状态") { Task { await model.refresh() } }
            }

            Divider()
            Toggle("开机自启动", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in LaunchAtLogin.set(on) }
            Text("提示:首次连接每台设备需在弹出的登录框勾「记住密码」+ 选「标准」模式;真·多显示器需在对方机器的屏幕共享里选对应的 ScreenBar-<id> 虚拟屏一次(会被记住)。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .sheet(item: $editing) { d in
            DeviceEditView(device: d, isNew: isNew) { model.store.upsert($0) }
        }
    }
}
