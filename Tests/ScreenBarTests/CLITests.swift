import Testing
@testable import ScreenBar

@Suite("CLI 命令识别")
struct CLITests {
    @Test("已知命令")
    func known() {
        for c in ["status", "list", "connect", "disconnect", "view", "unview", "jump", "wake", "doctor", "help"] {
            #expect(CLI.isCommand(c))
        }
    }
    @Test("未知 token 不当命令(→ 启 GUI)")
    func unknown() {
        #expect(!CLI.isCommand("foo"))
        #expect(!CLI.isCommand("m2"))
        #expect(!CLI.isCommand(""))
    }
}
