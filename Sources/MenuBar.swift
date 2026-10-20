// The status item: a coloured dot plus swap in use, and a menu rebuilt on every open
import AppKit

final class MenuBar: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    let history = History()
    var timer: Timer?
    var ticks = 0

    var showSwap: Bool {
        get { UserDefaults.standard.object(forKey: "showSwap") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showSwap") }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        menu.delegate = self
        item.menu = menu
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.tick() }
    }

    // Every 15 s: pressure and swap. Every minute: each app's memory, to spot the ones that keep growing
    func tick() {
        let s = Memory.snapshot(withApps: ticks % 4 == 0)
        ticks += 1
        history.record(s)
        render(s)
        Updater.checkIfDue()
    }

    func render(_ s: Snapshot) {
        let t = NSMutableAttributedString(string: levelGlyph(s.level), attributes: [.foregroundColor: levelColor(s.level)])
        if showSwap {
            t.append(NSAttributedString(string: String(format: " %.1fG", Double(s.swapUsed) / Double(1 << 30)),
                                        attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)]))
        }
        item.button?.attributedTitle = t
        item.button?.toolTip = L("tooltip", L("pressure.\(min(s.level, 4))"))
        item.button?.setAccessibilityLabel(L("header", L("pressure.\(min(s.level, 4))")) + ", " + CLI.stats(s))
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let s = Memory.snapshot()
        menu.removeAllItems()

        let head = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        head.attributedTitle = NSAttributedString(string: levelGlyph(s.level) + " " + L("header", L("pressure.\(min(s.level, 4))")),
            attributes: [.foregroundColor: levelColor(s.level), .font: NSFont.boldSystemFont(ofSize: 13)])
        menu.addItem(head)
        menu.addItem(info(CLI.stats(s)))
        if history.swap.count >= 8 { chartItems().forEach(menu.addItem) }

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
        let tips = Advisor.tips(for: s, history: history)
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
        if Lighten.shown { menu.addItem(lightenItem()) }
        menu.addItem(action(L("menu.terminal"), #selector(openTerminal), "t", symbol: "terminal"))
        menu.addItem(action(L("menu.activity"), #selector(openActivityMonitor), "a", symbol: "chart.bar.xaxis"))
        let login = action(L("menu.login"), #selector(toggleLogin), symbol: "power")
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        let swapOption = action(L("menu.showSwap"), #selector(toggleSwap))
        swapOption.state = showSwap ? .on : .off
        menu.addItem(swapOption)
        menu.addItem(.separator())
        if let v = Updater.available {
            let up = action(L("update", v), #selector(installUpdate), symbol: "arrow.down.circle")
            subtitle(up, L("update.sub"))
            menu.addItem(up)
        }
        let about = action(L("menu.about"), #selector(openAbout), symbol: "info.circle")
        subtitle(about, L("about.by"))
        menu.addItem(about)
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

    // "Lighten macOS ②": a badge counts the settings still worth switching on
    func lightenItem() -> NSMenuItem {
        let parent = NSMenuItem(title: L("lighten"), action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "leaf", accessibilityDescription: nil)
        let pending = Lighten.pending
        if pending > 0 { parent.badge = NSMenuItemBadge(count: pending) }

        let sub = NSMenu()
        let device = L(Lighten.isLaptop ? "device.laptop" : "device.desktop")
        sub.addItem(info(L("lighten.forThis", device, L("unit.gbInt", Int(Lighten.physical >> 30)))))
        for section in Lighten.settings() {
            sub.addItem(.separator())
            sub.addItem(.sectionHeader(title: section.section))
            for st in section.items {
                let i = action(st.title, #selector(openPane(_:)), symbol: st.symbol)
                i.representedObject = st.pane
                i.state = st.isOn == true ? .on : .off
                subtitle(i, st.isOn == true ? L("sub.on") : st.hint)
                sub.addItem(i)
            }
        }
        sub.addItem(.separator())
        let foot = info("")
        foot.attributedTitle = NSAttributedString(string: L("lighten.footer"), attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.tertiaryLabelColor])
        sub.addItem(foot)
        parent.submenu = sub
        return parent
    }

    // Swap over the last 30 minutes, one bar per reading, coloured by pressure
    func chartItems() -> [NSMenuItem] {
        let peak = history.swap.map(\.bytes).max() ?? 0
        let caption = info("")
        caption.attributedTitle = NSAttributedString(string: L("chart", size(peak)), attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor])
        let chart = NSMenuItem()
        chart.view = SwapChart(points: history.swap.map { ($0.bytes, $0.level) })
        chart.view?.setAccessibilityLabel(L("chart", size(peak)))
        return [caption, chart]
    }

    func subtitle(_ item: NSMenuItem, _ text: String) {
        if #available(macOS 14.4, *) { item.subtitle = text } else { item.toolTip = text }
    }

    func info(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    func action(_ title: String, _ sel: Selector, _ key: String = "", symbol: String? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        if let symbol { i.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return i
    }

    @objc func quitApp(_ sender: NSMenuItem) { (sender.representedObject as? NSRunningApplication)?.terminate() }
    @objc func runFix(_ sender: NSMenuItem) { (sender.representedObject as? () -> Void)?() }
    @objc func openPane(_ sender: NSMenuItem) { (sender.representedObject as? String).map(Lighten.open) }
    @objc func toggleLogin() { LoginItem.set(!LoginItem.isEnabled) }
    @objc func toggleSwap() { showSwap.toggle(); render(Memory.snapshot(withApps: false)) }
    @objc func installUpdate() { Updater.install() }
    // Standard About panel, signed LesWWW.com, with links to the studio and the source
    @objc func openAbout() {
        let small = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let p = NSMutableParagraphStyle()
        p.alignment = .center
        let credits = NSMutableAttributedString(string: L("about.by") + "\n", attributes: [.font: small, .paragraphStyle: p])
        credits.append(NSAttributedString(string: "Why. What. Which way.\n\n", attributes: [
            .font: small, .paragraphStyle: p, .foregroundColor: NSColor.secondaryLabelColor]))
        for (title, url) in [("leswww.com", "https://leswww.com"), ("github.com/kxrz/membar", "https://github.com/kxrz/membar")] {
            credits.append(NSAttributedString(string: title, attributes: [.font: small, .paragraphStyle: p, .link: URL(string: url)!]))
            credits.append(NSAttributedString(string: "\n", attributes: [.font: small, .paragraphStyle: p]))
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }

    @objc func openTerminal() {
        guard let cmd = Bundle.main.url(forResource: "mem", withExtension: "command") else { return }
        NSWorkspace.shared.open([cmd], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
                                configuration: NSWorkspace.OpenConfiguration())
    }
}

final class SwapChart: NSView {
    let points: [(bytes: UInt64, level: Int)]
    static let slots = 120   // 30 minutes of 15-second readings, newest on the right

    init(points: [(bytes: UInt64, level: Int)]) {
        self.points = points.suffix(SwapChart.slots)
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 40))
    }
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirty: NSRect) {
        let area = bounds.insetBy(dx: 14, dy: 4)
        let top = Double(max(points.map(\.bytes).max() ?? 0, 1 << 30))   // at least 1 GB tall, so small moves stay small
        let w = area.width / CGFloat(SwapChart.slots)
        NSGraphicsContext.current?.shouldAntialias = false   // no hairline seams between fractional-width bars
        for (i, p) in points.reversed().enumerated() {
            let h = max(1, area.height * CGFloat(Double(p.bytes) / top))
            levelColor(p.level).setFill()
            NSRect(x: area.maxX - CGFloat(i + 1) * w, y: area.minY, width: w, height: h).fill()
        }
        NSColor.separatorColor.setFill()
        NSRect(x: area.minX, y: area.minY, width: area.width, height: 1).fill()
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
