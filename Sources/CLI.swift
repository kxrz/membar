// `mem` in the terminal: the same reading and advice as the menu, as text
import Foundation

enum CLI {
    static func run(top: Int) {
        let s = Memory.snapshot()
        let tty = isatty(STDOUT_FILENO) != 0
        let ansi = [1: "32", 2: "33"][s.level] ?? "31"
        let dot = tty ? "\u{1B}[\(ansi)m\(levelGlyph(s.level))\u{1B}[0m" : levelGlyph(s.level)

        print("\(dot) \(L("header", L("pressure.\(min(s.level, 4))")))  ·  \(stats(s))")
        for a in s.apps.prefix(top) {
            let tag = a.bundlePath.map(Memory.isElectron) == true ? "  · Electron" : ""
            print("  " + size(a.bytes).padding(toLength: 9, withPad: " ", startingAt: 0) + displayName(a) + tag)
        }
        let tips = Advisor.tips(for: s)
        print("\n" + L("tips"))
        print(tips.isEmpty ? "  " + L("tip.ok") : tips.map { "  • " + $0.text }.joined(separator: "\n"))
    }

    static func stats(_ s: Snapshot) -> String {
        L("stats", s.freePercent, size(s.compressed), size(s.swapUsed))
    }
}
