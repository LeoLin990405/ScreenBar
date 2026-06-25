import Foundation

/// BetterDisplay 虚拟屏封装(副屏方向)。每设备一块独立命名虚拟屏 → 真·多显示器。
enum VirtualDisplay {
    private static var cli: String { Constants.betterDisplayCLI }

    /// 确保某设备的虚拟屏存在、按分辨率/HiDPI 配置好并连上。
    static func ensure(name: String, resolution: String, hiDPI: Bool) async {
        _ = await Shell.run("/usr/bin/open", ["-a", "BetterDisplay"])
        for _ in 0..<15 {
            if await Shell.run(cli, ["get", "-identifiers"]).ok { break }
            try? await Task.sleep(for: .seconds(1))
        }
        let ids = await Shell.run(cli, ["get", "-identifiers"])
        if !ids.stdout.contains("\"name\" : \"\(name)\"") {
            _ = await Shell.run(cli, ["create", "-type=VirtualScreen", "-virtualScreenName=\(name)"])
            try? await Task.sleep(for: .seconds(2))
        }
        _ = await Shell.run(cli, ["set", "-name=\(name)", "-useResolutionList=on", "-resolutionList=\(resolution)"])
        if hiDPI {
            _ = await Shell.run(cli, ["set", "-name=\(name)", "-virtualScreenHiDPI=on"])
        }
        _ = await Shell.run(cli, ["set", "-name=\(name)", "-resolution=\(resolution)"])
        _ = await Shell.run(cli, ["set", "-name=\(name)", "-connected=on"])
        Log.info("virtual screen \(name) ensured @\(resolution) hiDPI=\(hiDPI)")
    }

    static func disconnect(name: String) async {
        _ = await Shell.run(cli, ["set", "-name=\(name)", "-connected=off"])
        Log.info("virtual screen \(name) disconnected")
    }

    /// 彻底删除某虚拟屏(设备删除时清理)。
    static func discard(name: String) async {
        _ = await Shell.run(cli, ["discard", "-name=\(name)"])
    }
}
