import Foundation
import OSLog

/// Wall-clock milestones from the first call to `bootstrap()` (call from `AppDelegate` as early as possible).
/// Filter Xcode console: `StartupTiming` or log subsystem `…StartupTiming`.
enum StartupTiming {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Wearhouse", category: "StartupTiming")
    private static var t0: CFAbsoluteTime?
    private static let lock = NSLock()

    /// Call once at the start of `application(_:didFinishLaunchingWithOptions:)` so later `+ms` values measure from real launch work.
    static func bootstrap() {
        lock.lock()
        defer { lock.unlock() }
        guard t0 == nil else { return }
        t0 = CFAbsoluteTimeGetCurrent()
        emit(ms: 0, label: "bootstrap (epoch)")
    }

    static func mark(_ label: String) {
        lock.lock()
        let base = t0 ?? CFAbsoluteTimeGetCurrent()
        if t0 == nil { t0 = base }
        lock.unlock()
        let ms = (CFAbsoluteTimeGetCurrent() - base) * 1000
        emit(ms: ms, label: label)
    }

    private static func emit(ms: Double, label: String) {
        let line = String(format: "[StartupTiming] +%.0f ms - %@", ms, label)
        log.info("\(line, privacy: .public)")
        #if DEBUG
        print(line)
        #endif
    }
}
