import Foundation

/// 执行外部命令(ssh / netstat / betterdisplaycli / open)。无隔离,可从任意上下文 await。
enum Shell {
    struct Result: Sendable {
        let status: Int32
        let stdout: String
        let stderr: String
        var ok: Bool { status == 0 }
    }

    /// 直接执行(args 不经 shell 二次解析)。env 非 nil 时覆盖子进程环境。
    @discardableResult
    static func run(_ launchPath: String, _ args: [String], env: [String: String]? = nil, timeout: TimeInterval? = nil) async -> Result {
        await withCheckedContinuation { (cont: CheckedContinuation<Result, Never>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: launchPath)
            p.arguments = args
            if let env { p.environment = env }
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            do {
                try p.run()
            } catch {
                cont.resume(returning: Result(status: -1, stdout: "", stderr: error.localizedDescription))
                return
            }
            if let t = timeout {
                DispatchQueue.global().asyncAfter(deadline: .now() + t) { if p.isRunning { p.terminate() } }
            }
            DispatchQueue.global().async {
                let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                p.waitUntilExit()
                cont.resume(returning: Result(status: p.terminationStatus, stdout: o, stderr: e))
            }
        }
    }

    /// 经 /bin/bash -lc 执行复合命令行(含管道/嵌套引号,如 trigger 覆盖、双跳 ssh)。
    @discardableResult
    static func bash(_ command: String, timeout: TimeInterval? = nil) async -> Result {
        await run("/bin/bash", ["-lc", command], timeout: timeout)
    }
}
