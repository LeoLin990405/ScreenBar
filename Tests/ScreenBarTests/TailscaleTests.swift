import Testing
@testable import ScreenBar

@Suite("Tailscale 直连/中继解析")
struct TailscaleTests {
    let json = """
    {"Peer": {
      "k1": {"TailscaleIPs": ["100.64.0.10"], "CurAddr": "198.51.100.7:41641", "Relay": "lax", "Online": true},
      "k2": {"TailscaleIPs": ["100.64.0.20"], "CurAddr": "", "Relay": "sfo", "Online": true},
      "k3": {"TailscaleIPs": ["100.64.0.30"], "CurAddr": "", "Relay": "lax", "Online": false}
    }}
    """

    @Test("CurAddr 非空 = 直连")
    func direct() {
        #expect(Tailscale.parse(json)["100.64.0.10"] == .direct)
    }
    @Test("CurAddr 空 + 在线 = 中继")
    func relay() {
        #expect(Tailscale.parse(json)["100.64.0.20"] == .relay)
    }
    @Test("离线 = unknown")
    func offline() {
        #expect(Tailscale.parse(json)["100.64.0.30"] == .unknown)
    }
    @Test("坏 JSON → 空")
    func bad() {
        #expect(Tailscale.parse("not json").isEmpty)
    }
}
