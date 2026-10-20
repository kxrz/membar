// Once a day, ask GitHub for the latest release number. Nothing about your Mac is sent.
// Turn it off with: defaults write io.github.kxrz.membar checkUpdates -bool NO
import Foundation

enum Updater {
    static let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    static private(set) var available: String?
    static private var lastCheck: Date?

    static var enabled: Bool { UserDefaults.standard.object(forKey: "checkUpdates") as? Bool ?? true }

    static func checkIfDue() {
        guard enabled, lastCheck.map({ $0 < Date(timeIntervalSinceNow: -86400) }) ?? true else { return }
        lastCheck = Date()
        let url = URL(string: "https://api.github.com/repos/kxrz/membar/releases/latest")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            DispatchQueue.main.async {
                available = latest.compare(current, options: .numeric) == .orderedDescending ? latest : nil
            }
        }.resume()
    }

    // Rebuild from source with the regular installer, in its own session so it outlives
    // MemBar (the installer quits it) and launchd's clean-up of the login item
    static func install() {
        let log = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/MemBar-update.log").path
        let cmd = "curl -fsSL https://raw.githubusercontent.com/kxrz/membar/main/install.sh | zsh > '\(log)' 2>&1"
        var env = ProcessInfo.processInfo.environment
        env["MEMBAR_APP_DIR"] = Bundle.main.bundleURL.deletingLastPathComponent().path
        env["MEMBAR_UPDATE"] = "1"
        let argv = ["/bin/zsh", "-c", cmd].map { strdup($0) } + [nil]
        let envp = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + envp).forEach { free($0) } }
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSID))
        var pid = pid_t()
        posix_spawn(&pid, "/bin/zsh", nil, &attr, argv, envp)
        posix_spawnattr_destroy(&attr)
    }
}
