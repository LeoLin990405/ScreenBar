import Testing
import Foundation
@testable import ScreenBar

@Suite("netstat 连接方向解析")
struct ReachabilityTests {
    @Test("入向:本地 5900 = 对方当本机副屏")
    func inbound() {
        let out = """
        Active Internet connections
        Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
        tcp4       0     66  192.0.2.1.5900         192.0.2.10.56936       ESTABLISHED
        tcp4       0      0  192.0.2.1.22           192.0.2.20.51000       ESTABLISHED
        """
        let c = Reachability.parseConnections(out)
        #expect(c.inbound.contains("192.0.2.10"))
        #expect(c.outbound.isEmpty)
        #expect(!c.inbound.contains("192.0.2.20"))   // :22 不算
    }

    @Test("出向:对端 5900 = 本机在查看对方")
    func outbound() {
        let out = """
        tcp4       0      0  192.0.2.1.55123        192.0.2.30.5900        ESTABLISHED
        tcp4       0      0  192.0.2.1.55124        192.0.2.20.5900        ESTABLISHED
        """
        let c = Reachability.parseConnections(out)
        #expect(c.outbound == ["192.0.2.30", "192.0.2.20"])
        #expect(c.inbound.isEmpty)
    }

    @Test("非 ESTABLISHED 忽略")
    func ignoresNonEstablished() {
        let out = "tcp4       0      0  192.0.2.1.5900         192.0.2.10.5000        LISTEN"
        let c = Reachability.parseConnections(out)
        #expect(c.inbound.isEmpty && c.outbound.isEmpty)
    }

    @Test("stripPort 去端口")
    func strip() {
        #expect(Reachability.stripPort("192.0.2.10.56936") == "192.0.2.10")
        #expect(Reachability.stripPort("nodot") == "nodot")
    }
}
