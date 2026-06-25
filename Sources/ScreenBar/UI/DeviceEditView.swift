import SwiftUI

/// 新增/编辑一台设备的表单。
struct DeviceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var device: Device
    let isNew: Bool
    let onSave: (Device) -> Void

    var body: some View {
        Form {
            Section("基本") {
                TextField("ID（短标识,如 m2）", text: $device.id).disabled(!isNew)
                TextField("显示名", text: $device.label)
                Picker("方向", selection: $device.modes) {
                    ForEach(DeviceMode.allCases) { Text($0.label).tag($0) }
                }
                TextField("备注", text: $device.note)
            }
            Section("网络") {
                TextField("Tailscale IP / 主机", text: $device.host)
                TextField("SSH 端口", value: $device.sshPort, format: .number)
                TextField("SSH 目标（别名或 user@ip;- 表示不用）", text: $device.sshTarget)
            }
            Section("副屏（虚拟屏)") {
                TextField("分辨率（如 1440x900）", text: $device.resolution)
                Toggle("HiDPI（Retina 清晰）", isOn: $device.hiDPI)
                Toggle("上线即自动连为副屏", isOn: $device.autoConnect)
            }
            Section("查看协议") {
                TextField("Jump 电脑 ID（填了「投过来看」走 Jump Fluid,中继也流畅;留空走 VNC）", text: Binding(
                    get: { device.jumpID ?? "" },
                    set: { device.jumpID = $0.isEmpty ? nil : $0 }))
            }
            Section("唤醒") {
                TextField("MAC（WoL,留空会在线时自动抓）", text: Binding(
                    get: { device.macAddress ?? "" },
                    set: { device.macAddress = $0.isEmpty ? nil : $0 }))
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 460)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { onSave(device); dismiss() }
                    .disabled(device.id.isEmpty || device.label.isEmpty || device.host.isEmpty)
            }
        }
    }
}
