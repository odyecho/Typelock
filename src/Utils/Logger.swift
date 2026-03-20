import Foundation
import os.log

/// Typelock 日志系统
class Logger {

    // MARK: - Singleton

    nonisolated(unsafe) static let shared = Logger()

    // MARK: - Properties

    private let subsystem = "com.typelock.macos"
    private let osLog: OSLog
    private let fileLogger: FileLogger

    /// 当前日志级别
    var logLevel: LogLevel = .info {
        didSet {
            fileLogger.logLevel = logLevel
        }
    }

    /// 是否启用控制台输出
    var enableConsoleOutput = true

    /// 是否启用文件输出
    var enableFileOutput = true

    // MARK: - Initialization

    private init() {
        osLog = OSLog(subsystem: subsystem, category: "general")
        fileLogger = FileLogger()

        // 从设置中加载日志级别
        loadLogLevel()
    }

    // MARK: - Public Methods

    /// 调试日志
    func debug(
        _ message: String,
        category: String = "general",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// 信息日志
    func info(
        _ message: String,
        category: String = "general",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// 警告日志
    func warning(
        _ message: String,
        category: String = "general",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// 错误日志
    func error(
        _ message: String,
        category: String = "general",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    /// 错误日志（带 Error 对象）
    func error(
        _ error: Error,
        message: String? = nil,
        category: String = "general",
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let errorMessage = message ?? "发生错误"
        let fullMessage = "\(errorMessage): \(error.localizedDescription)"
        log(fullMessage, level: .error, category: category, file: file, function: function, line: line)
    }

    // MARK: - Private Methods

    /// 核心日志方法
    private func log(_ message: String, level: LogLevel, category: String, file: String, function: String, line: Int) {
        // 检查日志级别
        guard level.rawValue >= logLevel.rawValue else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.displayName)] [\(category)] \(fileName):\(line) \(function) - \(message)"

        // 控制台输出
        if enableConsoleOutput {
            outputToConsole(logMessage, level: level)
        }

        // 文件输出
        if enableFileOutput {
            fileLogger.log(logMessage, level: level)
        }

        // 系统日志
        outputToOSLog(message, level: level, category: category)
    }

    /// 输出到控制台
    private func outputToConsole(_ message: String, level: LogLevel) {
        switch level {
        case .debug:
            print("🔍 \(message)")
        case .info:
            print("ℹ️ \(message)")
        case .warning:
            print("⚠️ \(message)")
        case .error:
            print("❌ \(message)")
        }
    }

    /// 输出到系统日志
    private func outputToOSLog(_ message: String, level: LogLevel, category: String) {
        let categoryLog = OSLog(subsystem: subsystem, category: category)

        switch level {
        case .debug:
            os_log("%{public}@", log: categoryLog, type: .debug, message)
        case .info:
            os_log("%{public}@", log: categoryLog, type: .info, message)
        case .warning:
            os_log("%{public}@", log: categoryLog, type: .default, message)
        case .error:
            os_log("%{public}@", log: categoryLog, type: .error, message)
        }
    }

    /// 加载日志级别设置
    private func loadLogLevel() {
        if let levelString = UserDefaults.standard.string(forKey: "TypelockLogLevel"),
           let level = LogLevel(rawValue: levelString) {
            logLevel = level
        }
    }

    /// 保存日志级别设置
    func saveLogLevel() {
        UserDefaults.standard.set(logLevel.rawValue, forKey: "TypelockLogLevel")
    }
}

// MARK: - FileLogger

private class FileLogger {
    private let logDirectory: URL
    private let logFileName: String
    private let maxFileSize: Int64 = 10 * 1_024 * 1_024 // 10MB
    private let maxLogFiles = 5
    private let queue = DispatchQueue(label: "com.typelock.logger", qos: .utility)

    var logLevel: LogLevel = .info

    init() {
        // 创建日志目录
        let logsPath = NSString(string: Constants.Paths.logs).expandingTildeInPath
        logDirectory = URL(fileURLWithPath: logsPath)

        // 日志文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        logFileName = "typelock-\(dateFormatter.string(from: Date())).log"

        // 创建日志目录
        createLogDirectoryIfNeeded()
    }

    func log(_ message: String, level: LogLevel) {
        guard level.rawValue >= logLevel.rawValue else { return }

        queue.async { [weak self] in
            self?.writeToFile(message)
        }
    }

    private func createLogDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectoryIfNeeded(at: logDirectory)
        } catch {
            print("创建日志目录失败: \(error)")
        }
    }

    private func writeToFile(_ message: String) {
        let logFileURL = logDirectory.appendingPathComponent(logFileName)
        let logEntry = message + "\n"

        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                // 检查文件大小
                if let fileSize = FileManager.default.fileSize(at: logFileURL),
                   fileSize > maxFileSize {
                    rotateLogFiles()
                }

                // 追加到现有文件
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logEntry.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                // 创建新文件
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("写入日志文件失败: \(error)")
        }
    }

    private func rotateLogFiles() {
        do {
            let fileManager = FileManager.default
            let logFiles = try fileManager.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: []
            )
            .filter { $0.pathExtension == "log" }
            .sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date
                    .distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date
                    .distantPast
                return date1 > date2
            }

            // 删除多余的日志文件
            if logFiles.count >= maxLogFiles {
                for i in (maxLogFiles - 1)..<logFiles.count {
                    try fileManager.removeItem(at: logFiles[i])
                }
            }
        } catch {
            print("日志文件轮转失败: \(error)")
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Convenience Extensions

extension Logger {
    /// 输入法相关日志
    func inputSource(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: "InputSource", file: file, function: function, line: line)
    }

    /// 锁定引擎相关日志
    func lockEngine(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: "LockEngine", file: file, function: function, line: line)
    }

    /// 权限相关日志
    func permission(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: "Permission", file: file, function: function, line: line)
    }

    /// UI 相关日志
    func ui(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: "UI", file: file, function: function, line: line)
    }

    /// 性能相关日志
    func performance(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: "Performance", file: file, function: function, line: line)
    }
}
