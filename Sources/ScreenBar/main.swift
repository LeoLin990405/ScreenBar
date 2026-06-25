import Foundation

// 入口分发:带已知 CLI 命令 → 跑 CLI 并退出;否则 → 启动菜单栏 GUI。
let args = Array(CommandLine.arguments.dropFirst())
if let cmd = args.first, CLI.isCommand(cmd) {
    await CLI.run(cmd, Array(args.dropFirst()))
    exit(0)
} else {
    ScreenBarApp.main()
}
