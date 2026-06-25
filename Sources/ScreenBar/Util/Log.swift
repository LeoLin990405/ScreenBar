import Foundation
import os

/// 统一日志(os.Logger)。Console.app 里按 subsystem com.leo.screenbar 过滤。
enum Log {
    private static let logger = Logger(subsystem: Constants.bundleID, category: "app")
    static func info(_ m: String) { logger.info("\(m, privacy: .public)") }
    static func error(_ m: String) { logger.error("\(m, privacy: .public)") }
    static func debug(_ m: String) { logger.debug("\(m, privacy: .public)") }
}
