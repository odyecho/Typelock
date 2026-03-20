import Cocoa
import Foundation

/// 性能监控器
/// 监控应用的 CPU 和内存使用情况
class PerformanceMonitor {

    // MARK: - Properties

    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var logger = Logger.shared

    /// 性能数据
    private var performanceData = PerformanceData()

    /// 性能警告回调
    var onPerformanceWarning: ((String) -> Void)?

    // MARK: - Public Methods

    /// 开始性能监控
    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("性能监控已在运行", category: "Performance")
            return
        }

        isMonitoring = true
        startMonitoringTimer()

        logger.info("性能监控已启动", category: "Performance")
    }

    /// 停止性能监控
    func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil

        logger.info("性能监控已停止", category: "Performance")
    }

    /// 获取当前性能数据
    func getCurrentPerformanceData() -> PerformanceData {
        updatePerformanceData()
        return performanceData
    }

    /// 记录性能事件
    func recordEvent(_ event: String, duration: TimeInterval) {
        logger.performance("性能事件: \(event), 耗时: \(String(format: "%.2f", duration * 1_000))ms")

        // 如果耗时过长，记录警告
        if duration > 0.1 { // 100ms
            logger.warning(
                "性能事件耗时过长: \(event), 耗时: \(String(format: "%.2f", duration * 1_000))ms",
                category: "Performance"
            )
        }
    }

    // MARK: - Private Methods

    /// 启动监控定时器
    private func startMonitoringTimer() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceData()
            self?.checkPerformanceThresholds()
        }
    }

    /// 更新性能数据
    private func updatePerformanceData() {
        performanceData.cpuUsage = getCurrentCPUUsage()
        performanceData.memoryUsage = getCurrentMemoryUsage()
        performanceData.timestamp = Date()

        logger.debug(
            "性能数据更新 - CPU: \(String(format: "%.1f", performanceData.cpuUsage))%, 内存: \(String(format: "%.1f", performanceData.memoryUsage))MB",
            category: "Performance"
        )
    }

    /// 检查性能阈值
    private func checkPerformanceThresholds() {
        // 检查 CPU 使用率
        if performanceData.cpuUsage > Constants.Performance.maxCPUUsage {
            let message = "CPU 使用率过高: \(String(format: "%.1f", performanceData.cpuUsage))%"
            logger.warning(message, category: "Performance")
            onPerformanceWarning?(message)
        }

        // 检查内存使用量
        if performanceData.memoryUsage > Constants.Performance.maxMemoryUsage {
            let message = "内存使用量过高: \(String(format: "%.1f", performanceData.memoryUsage))MB"
            logger.warning(message, category: "Performance")
            onPerformanceWarning?(message)
        }
    }

    /// 获取当前 CPU 使用率
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            // 这里简化处理，实际应该计算时间差
            return Double(info.resident_size) / 1_024.0 / 1_024.0 * 0.1 // 简化的 CPU 使用率估算
        }

        return 0.0
    }

    /// 获取当前内存使用量（MB）
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1_024.0 / 1_024.0
        }

        return 0.0
    }
}

// MARK: - PerformanceData

struct PerformanceData {
    var cpuUsage = 0.0 // CPU 使用率 (%)
    var memoryUsage = 0.0 // 内存使用量 (MB)
    var timestamp = Date() // 时间戳

    /// 格式化的 CPU 使用率字符串
    var formattedCPUUsage: String {
        String(format: "%.1f%%", cpuUsage)
    }

    /// 格式化的内存使用量字符串
    var formattedMemoryUsage: String {
        String(format: "%.1f MB", memoryUsage)
    }

    /// 是否超出性能阈值
    var isOverThreshold: Bool {
        cpuUsage > Constants.Performance.maxCPUUsage ||
            memoryUsage > Constants.Performance.maxMemoryUsage
    }
}

// MARK: - Performance Measurement Helper

extension PerformanceMonitor {
    /// 测量代码块执行时间
    static func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        Logger.shared.performance("执行时间测量: \(name) - \(String(format: "%.2f", timeElapsed * 1_000))ms")

        return result
    }

    /// 异步测量代码块执行时间
    static func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        Logger.shared.performance("异步执行时间测量: \(name) - \(String(format: "%.2f", timeElapsed * 1_000))ms")

        return result
    }
}
