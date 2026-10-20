// Turns a snapshot into plain advice, each tip optionally with a one-click fix
import AppKit

// Numbers follow the language MemBar speaks (2,9 Go in French), not the region
let appLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: appLocale, arguments: args)
}

func size(_ bytes: UInt64) -> String {
    bytes >= 1 << 30 ? L("unit.gb", Double(bytes) / Double(1 << 30)) : L("unit.mb", Int(bytes >> 20))
}

func displayName(_ app: AppUsage) -> String {
    app.name == Memory.webContentKey ? L("app.webcontent") : app.name
}

struct Tip {
    let text: String
    var fix: (() -> Void)? = nil
}

enum Advisor {
    // Desktop apps that are a browser tab in disguise
    static let webAlternatives: [String: String] = [
        "notion.id": "https://www.notion.so",
        "com.tinyspeck.slackmacgap": "https://app.slack.com",
        "com.hnc.Discord": "https://discord.com/app",
        "com.microsoft.teams2": "https://teams.microsoft.com",
        "com.figma.Desktop": "https://www.figma.com/files",
        "com.linear": "https://linear.app",
        "com.spotify.client": "https://open.spotify.com",
        "com.anthropic.claudefordesktop": "https://claude.ai",
        "com.openai.chat": "https://chatgpt.com",
    ]
    static let browsers: Set<String> = ["Firefox", "Google Chrome", "Arc", "Brave Browser", "Microsoft Edge", "Vivaldi", "Opera", Memory.webContentKey]

    static func tips(for s: Snapshot, swapGrowth: (bytes: UInt64, minutes: Int)? = nil) -> [Tip] {
        let growing = (swapGrowth?.bytes ?? 0) >= 512 << 20
        let heavySwap = s.swapUsed >= s.physical * 2 / 5
        if s.level == 1 && !growing && s.swapUsed < s.physical / 4 { return [] }

        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        func runningApp(_ u: AppUsage) -> NSRunningApplication? {
            u.bundlePath.flatMap { p in running.first { $0.bundleURL?.path == p } }
        }
        var tips: [Tip] = []
        var covered: Set<String> = []

        for u in s.apps where u.bytes >= 150 << 20 {
            guard let app = runningApp(u), let id = app.bundleIdentifier,
                  let url = webAlternatives[id].flatMap(URL.init(string:)) else { continue }
            covered.insert(u.name)
            tips.append(Tip(text: L("tip.web", u.name, size(u.bytes))) {
                app.terminate()
                NSWorkspace.shared.open(url)
            })
        }

        let electron = s.apps.filter { u in
            !covered.contains(u.name) && runningApp(u) != nil && u.bundlePath.map(Memory.isElectron) == true
        }
        if electron.count >= 2 {
            let total = electron.reduce(0) { $0 + $1.bytes }
            tips.append(Tip(text: L("tip.electron", electron.count, size(total), electron.map(\.name).joined(separator: ", "))))
        }

        if growing, let g = swapGrowth, let top = s.apps.first {
            tips.append(Tip(text: L("tip.swapGrowth", size(g.bytes), g.minutes, displayName(top))))
        }

        if s.level >= 2 {
            if let b = s.apps.first(where: { browsers.contains($0.name) && $0.bytes >= 800 << 20 }) {
                tips.append(Tip(text: L("tip.browser", displayName(b), size(b.bytes))))
            }
            tips.append(Tip(text: L("tip.quit")))
        }

        if heavySwap { tips.append(Tip(text: L("tip.restart", size(s.swapUsed)))) }
        return tips
    }
}
