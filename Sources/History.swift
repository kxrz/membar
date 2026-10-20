// What MemBar remembers between readings: swap over the last 30 minutes,
// each app's memory over the last hour, and when each app was last in front
import AppKit

final class History {
    let started = Date()
    private(set) var swap: [(date: Date, bytes: UInt64, level: Int)] = []
    private var apps: [(date: Date, bytes: [String: UInt64])] = []
    private var lastActive: [String: Date] = [:]   // bundle path → last time it was in front

    // Quitting these would cut something off: a running command, the music, a call
    static let neverIdle: Set<String> = [
        "com.apple.finder", "com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable",
        "com.apple.Music", "com.spotify.client", "com.apple.podcasts", "us.zoom.xos", "com.apple.FaceTime",
    ]

    init() {
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in
                guard let p = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleURL?.path else { return }
                self?.lastActive[p] = Date()
            }
        }
    }

    func record(_ s: Snapshot, at now: Date = Date()) {
        swap.append((now, s.swapUsed, s.level))
        swap.removeAll { $0.date < now - 1800 }
        guard !s.apps.isEmpty else { return }
        apps.append((now, Dictionary(uniqueKeysWithValues: s.apps.filter { $0.bytes >= 100 << 20 }.map { ($0.name, $0.bytes) })))
        apps.removeAll { $0.date < now - 3600 }
    }

    // Swap gained since the lowest reading of the last 30 minutes, once we have 5 minutes of history
    var swapGrowth: (bytes: UInt64, minutes: Int)? {
        guard let first = swap.first, let last = swap.last,
              last.date.timeIntervalSince(first.date) >= 300,
              let low = swap.map(\.bytes).min(), last.bytes > low else { return nil }
        return (last.bytes - low, Int(last.date.timeIntervalSince(first.date) / 60))
    }

    // The app whose memory climbed the most: at least +500 MB and +50 % over its lowest reading this hour
    func growing(in s: Snapshot) -> (app: AppUsage, bytes: UInt64, minutes: Int)? {
        s.apps.compactMap { u -> (app: AppUsage, bytes: UInt64, minutes: Int)? in
            guard let low = apps.compactMap({ r in r.bytes[u.name].map { (date: r.date, bytes: $0) } }).min(by: { $0.bytes < $1.bytes }),
                  u.bytes >= low.bytes + (500 << 20), u.bytes >= low.bytes * 3 / 2 else { return nil }
            let minutes = Int(-low.date.timeIntervalSinceNow / 60)
            return minutes >= 10 ? (u, u.bytes - low.bytes, minutes) : nil
        }.max { $0.bytes < $1.bytes }
    }

    // Open apps that haven't been in front for `hours`, counting from when MemBar started watching
    func idleApps(hours: Int) -> [NSRunningApplication] {
        let limit = Date(timeIntervalSinceNow: -Double(hours) * 3600)
        return NSWorkspace.shared.runningApplications.filter { a in
            guard a.activationPolicy == .regular, !a.isActive, let path = a.bundleURL?.path,
                  !History.neverIdle.contains(a.bundleIdentifier ?? "") else { return false }
            return (lastActive[path] ?? max(a.launchDate ?? started, started)) < limit
        }
    }
}
