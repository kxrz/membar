// Memory readings: pressure, compression, swap and per-app footprint
import Foundation
import Darwin

struct AppUsage {
    let name: String
    let bytes: UInt64
    let bundlePath: String?   // set when the process lives inside a .app
}

struct Snapshot {
    let level: Int            // kernel pressure level: 1 normal, 2 elevated, 4 critical
    let freePercent: Int
    let compressed: UInt64
    let swapUsed: UInt64
    let physical: UInt64
    let apps: [AppUsage]
}

enum Memory {
    static let webContentKey = "com.apple.WebKit"

    static func sysctlInt(_ name: String) -> Int64 {
        var v: Int64 = 0, size = MemoryLayout<Int64>.size
        return sysctlbyname(name, &v, &size, nil, 0) == 0 ? v : 0
    }

    static func swapUsed() -> UInt64 {
        var s = xsw_usage(), size = MemoryLayout<xsw_usage>.size
        return sysctlbyname("vm.swapusage", &s, &size, nil, 0) == 0 ? s.xsu_used : 0
    }

    // Same figure as Activity Monitor's "Memory" column (phys_footprint),
    // with helper processes added to the .app they belong to
    static func usageByApp() -> [AppUsage] {
        var pids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var totals: [String: (bytes: UInt64, path: String?)] = [:]
        var buf = [CChar](repeating: 0, count: 4096)

        for pid in pids.prefix(max(count, 0)) where pid > 0 {
            var info = rusage_info_v2()
            let ok = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
            }
            guard ok == 0, proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { continue }
            let path = String(cString: buf)

            let key: String, bundle: String?
            if let r = path.range(of: ".app/") {
                bundle = String(path[..<r.lowerBound]) + ".app"
                key = ((bundle! as NSString).lastPathComponent as NSString).deletingPathExtension
            } else if path.contains("/com.apple.WebKit.") {
                (key, bundle) = (webContentKey, nil)
            } else {
                (key, bundle) = (toolName(path), nil)
            }
            totals[key, default: (0, bundle)].bytes += info.ri_phys_footprint
        }
        return totals.map { AppUsage(name: $0.key, bytes: $0.value.bytes, bundlePath: $0.value.path) }
            .sorted { $0.bytes > $1.bytes }
    }

    // Versioned CLI installs (…/claude/versions/2.1.303) are named after their tool, not their version
    static func toolName(_ path: String) -> String {
        let generic: Set<String> = ["versions", "bin", "libexec", "current"]
        return path.split(separator: "/").reversed().map(String.init).first {
            !generic.contains($0) && $0.range(of: #"^v?[0-9][0-9.]*$"#, options: .regularExpression) == nil
        } ?? (path as NSString).lastPathComponent
    }

    static func snapshot(withApps: Bool = true) -> Snapshot {
        Snapshot(level: Int(sysctlInt("kern.memorystatus_vm_pressure_level")),
                 freePercent: Int(sysctlInt("kern.memorystatus_level")),
                 compressed: UInt64(sysctlInt("vm.compressor_bytes_used")),
                 swapUsed: swapUsed(),
                 physical: ProcessInfo.processInfo.physicalMemory,
                 apps: withApps ? usageByApp() : [])
    }

    static func isElectron(_ bundlePath: String) -> Bool {
        FileManager.default.fileExists(atPath: bundlePath + "/Contents/Frameworks/Electron Framework.framework")
    }
}
