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

// The dot changes shape as well as colour, so the level reads without colour vision
func levelGlyph(_ level: Int) -> String {
    switch level { case 1: "●"; case 2: "◐"; default: "▲" }
}

func levelColor(_ level: Int) -> NSColor {
    switch level { case 1: .systemGreen; case 2: .systemOrange; default: .systemRed }
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

    static let idleHours = 2

    // History is what the menu bar app has watched over time; the one-shot `mem` command has none
    static func tips(for s: Snapshot, history: History? = nil) -> [Tip] {
        let swapGrowth = history?.swapGrowth
        let growing = (swapGrowth?.bytes ?? 0) >= 512 << 20
        let heavySwap = s.swapUsed >= s.physical * 2 / 5
        let watched = watchedTips(for: s, history: history)
        if s.level == 1 && !growing && s.swapUsed < s.physical / 4 { return watched }

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

        tips += watched

        if s.level >= 2 {
            if let b = s.apps.first(where: { browsers.contains($0.name) && $0.bytes >= 800 << 20 }) {
                tips.append(Tip(text: L("tip.browser", displayName(b), size(b.bytes))))
            }
            tips.append(Tip(text: L("tip.quit")))
        }

        if heavySwap { tips.append(Tip(text: L("tip.restart", size(s.swapUsed)))) }
        return tips
    }

    // Worth knowing even when memory is fine: an app that keeps growing, and apps left open for nothing
    static func watchedTips(for s: Snapshot, history: History?) -> [Tip] {
        guard let history else { return [] }
        var tips: [Tip] = []
        let running = NSWorkspace.shared.runningApplications

        if let g = history.growing(in: s) {
            let app = g.app.bundlePath.flatMap { p in running.first { $0.bundleURL?.path == p && $0.activationPolicy == .regular } }
            tips.append(Tip(text: L(app == nil ? "tip.growing" : "tip.growing.quit", displayName(g.app), size(g.bytes), g.minutes),
                            fix: app.map { a in { a.terminate() } }))
        }

        let idle = history.idleApps(hours: idleHours).compactMap { a in
            s.apps.first { $0.bundlePath == a.bundleURL?.path }.map { (app: a, usage: $0) }
        }
        let total = idle.reduce(0) { $0 + $1.usage.bytes }
        if total >= 300 << 20 {
            let text = idle.count == 1
                ? L("tip.idle.one", idle[0].usage.name, idleHours, size(total))
                : L("tip.idle", idle.count, idleHours, size(total), idle.map(\.usage.name).joined(separator: ", "))
            tips.append(Tip(text: text) { idle.forEach { $0.app.terminate() } })
        }
        return tips
    }
}
