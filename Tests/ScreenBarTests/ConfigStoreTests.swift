import Testing
import Foundation
@testable import ScreenBar

@Suite("配置种子与编码")
struct ConfigStoreTests {
    @Test("示例种子:id 唯一 + 覆盖三种 modes + trigger 覆盖")
    func seed() {
        let s = ConfigStore.seed
        #expect(s.count == 3)
        #expect(Set(s.map(\.id)).count == s.count)
        #expect(s.first { $0.id == "mini1" }?.modes == .view)   // 无头机仅查看
        #expect(s.first { $0.id == "mac1" }?.modes == .both)
        #expect(s.first { $0.id == "mac2" }?.triggerOn != nil)  // 自定义触发覆盖示例
    }

    @Test("Device JSON 往返一致")
    func codableRoundTrip() throws {
        let d = Device(id: "x", label: "X", modes: .both, host: "1.2.3.4",
                       sshTarget: "alias", note: "n", resolution: "1920x1080", hiDPI: true,
                       autoConnect: true, macAddress: "AA:BB:CC:DD:EE:FF")
        let data = try JSONEncoder().encode(d)
        let back = try JSONDecoder().decode(Device.self, from: data)
        #expect(back == d)
    }

    @Test("虚拟屏名按 id")
    func vName() {
        #expect(Device(id: "mbp_a", label: "A", modes: .screen, host: "h").virtualScreenName == "ScreenBar-mbp_a")
    }
}
