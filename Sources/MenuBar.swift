// The status item: a coloured dot plus swap in use, and a menu rebuilt on every open
import AppKit

final class MenuBar: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var samples: [(date: Date, swap: UInt64)] = []   // last 30 minutes of swap readings
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        menu.delegate = self
        item.menu = menu
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.tick() }
    }

    func color(_ level: Int) -> NSColor {
        switch level { case 1: .systemGreen; case 2: .systemOrange; default: .systemRed }
    }

    func tick() {
        let s = Memory.snapshot(withApps: false)
        samples.append((Date(), s.swapUsed))
        samples.removeAll { $0.date < Date(timeIntervalSinceNow: -1800) }

        let t = NSMutableAttributedString(string: "●", attributes: [.foregroundColor: color(s.level)])
        t.append(NSAttributedString(string: String(format: " %.1fG", Double(s.swapUsed) / Double(1 << 30)),
                                    attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)]))
        item.button?.attributedTitle = t
        item.button?.toolTip = L("tooltip", L("pressure.\(min(s.level, 4))"))
    }

    // Swap gained since the lowest reading of the last 30 minutes, once we have 5 minutes of history
    var swapGrowth: (bytes: UInt64, minutes: Int)? {
        guard let first = samples.first, let last = samples.last,
              last.date.timeIntervalSince(first.date) >= 300,
              let low = samples.map(\.swap).min(), last.swap > low else { return nil }
        return (last.swap - low, Int(last.date.timeIntervalSince(first.date) / 60))
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let s = Memory.snapshot()
        menu.removeAllItems()

        let head = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        head.attributedTitle = NSAttributedString(string: "● " + L("header", L("pressure.\(min(s.level, 4))")),
            attributes: [.foregroundColor: color(s.level), .font: NSFont.boldSystemFont(ofSize: 13)])
        menu.addItem(head)
        menu.addItem(info(CLI.stats(s)))

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: L("top")))
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for a in s.apps.prefix(5) {
            let tag = a.bundlePath.map(Memory.isElectron) == true ? "  · Electron" : ""
            let i = info("")
            let quittable = running.first(where: { $0.bundleURL?.path == a.bundlePath })
            i.attributedTitle = columns(size(a.bytes), displayName(a) + tag, dimmed: quittable == nil)
            // Real apps can be quit from here; background processes stay greyed out
            if let app = quittable {
                i.isEnabled = true
                i.action = #selector(quitApp(_:))
                i.target = self
                i.representedObject = app
                i.toolTip = L("top.quit", a.name)
            }
            menu.addItem(i)
        }

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: L("tips")))
        let tips = Advisor.tips(for: s, swapGrowth: swapGrowth)
        if tips.isEmpty { menu.addItem(info(L("tip.ok"))) }
        for t in tips {
            let i = info(t.text)
            if let fix = t.fix {
                i.isEnabled = true
                i.action = #selector(runFix(_:))
                i.target = self
                i.representedObject = fix
            }
            menu.addItem(i)
        }

        menu.addItem(.separator())
        menu.addItem(action(L("menu.terminal"), #selector(openTerminal), "t"))
        menu.addItem(action(L("menu.activity"), #selector(openActivityMonitor), "a"))
        let login = action(L("menu.login"), #selector(toggleLogin))
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(action(L("menu.about"), #selector(openAbout)))
        let quit = NSMenuItem(title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    // Size, tab, name: keeps the sizes in a clean column with the proportional menu font
    func columns(_ left: String, _ right: String, dimmed: Bool) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.tabStops = [NSTextTab(textAlignment: .right, location: 52), NSTextTab(textAlignment: .left, location: 62)]
        return NSAttributedString(string: "\t\(left)\t\(right)", attributes: [
            .paragraphStyle: p, .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: dimmed ? NSColor.secondaryLabelColor : NSColor.labelColor])
    }

    func info(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    func action(_ title: String, _ sel: Selector, _ key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc func quitApp(_ sender: NSMenuItem) { (sender.representedObject as? NSRunningApplication)?.terminate() }
    @objc func runFix(_ sender: NSMenuItem) { (sender.representedObject as? () -> Void)?() }
    @objc func toggleLogin() { LoginItem.set(!LoginItem.isEnabled) }
    @objc func openAbout() { NSWorkspace.shared.open(URL(string: "https://github.com/kxrz/membar")!) }

    @objc func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    @objc func openTerminal() {
        guard let cmd = Bundle.main.url(forResource: "mem", withExtension: "command") else { return }
        NSWorkspace.shared.open([cmd], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                configuration: NSWorkspace.OpenConfiguration())
    }
}

// Start at login through a per-user LaunchAgent: no helper app, no admin rights
enum LoginItem {
    static let plist = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/io.github.kxrz.membar.plist")

    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plist.path) }

    static func set(_ on: Bool) {
        guard on else { try? FileManager.default.removeItem(at: plist); return }
        let agent: NSDictionary = ["Label": "io.github.kxrz.membar",
                                   "ProgramArguments": [Bundle.main.executablePath ?? ""],
                                   "RunAtLoad": true]
        try? FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        agent.write(to: plist, atomically: true)
    }
}
