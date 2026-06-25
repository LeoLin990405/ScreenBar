import Testing
import Foundation
@testable import ScreenBar

@Suite("Wake-on-LAN 魔术包")
struct RemoteControlTests {
    @Test("结构:6×0xFF + MAC×16 = 102 字节")
    func packetShape() throws {
        let p = try #require(RemoteControl.magicPacket(mac: "AA:BB:CC:DD:EE:FF"))
        #expect(p.count == 102)
        #expect(Array(p.prefix(6)) == [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
        #expect(Array(p[6..<12]) == [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
        #expect(Array(p.suffix(6)) == [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
    }

    @Test("支持连字符分隔")
    func dashSeparator() throws {
        let p = try #require(RemoteControl.magicPacket(mac: "01-23-45-67-89-ab"))
        #expect(Array(p[6..<12]) == [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB])
    }

    @Test("非法 MAC → nil")
    func invalid() {
        #expect(RemoteControl.magicPacket(mac: "zz:zz") == nil)
        #expect(RemoteControl.magicPacket(mac: "AA:BB:CC:DD:EE") == nil)   // 只 5 段
    }
}
