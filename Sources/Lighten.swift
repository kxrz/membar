// "Lighten macOS": system settings worth a look on small Macs.
// macOS doesn't let apps flip these, so each item shows the current state and opens the exact pane.
import AppKit
import IOKit.ps

struct Setting {
    let title: String
    let symbol: String
    let isOn: Bool?          // nil when macOS doesn't tell us
    let hint: String
    let pane: String
}

enum Lighten {
    static let physical = ProcessInfo.processInfo.physicalMemory
    static var shown: Bool { physical <= 16 << 30 }
    static var suggested: Bool { physical <= 8 << 30 }

    static let isLaptop: Bool = {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return false }
        return list.contains { src in
            let d = IOPSGetPowerSourceDescription(info, src)?.takeUnretainedValue() as? [String: Any]
            return d?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }()

    static func settings() -> [(section: String, items: [Setting])] {
        let ws = NSWorkspace.shared
        let gpu = L(isLaptop ? "sub.gpu.battery" : "sub.gpu")
        let widgetsHidden = UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "StandardHideWidgets") ?? false
        return [
            (L("lighten.visual"), [
                Setting(title: L("lighten.transparency"), symbol: "square.on.square.dashed",
                        isOn: ws.accessibilityDisplayShouldReduceTransparency, hint: gpu,
                        pane: "com.apple.Accessibility-Settings.extension?Display"),
                Setting(title: L("lighten.motion"), symbol: "figure.walk.motion",
                        isOn: ws.accessibilityDisplayShouldReduceMotion, hint: gpu,
                        pane: "com.apple.Accessibility-Settings.extension?Display"),
            ]),
            (L("lighten.desktop"), [
                Setting(title: L("lighten.widgets"), symbol: "widget.small",
                        isOn: widgetsHidden, hint: L("sub.widgets"),
                        pane: "com.apple.Desktop-Settings.extension"),
            ]),
            (L("lighten.startup"), [
                Setting(title: L("lighten.loginItems"), symbol: "list.bullet",
                        isOn: nil, hint: L("sub.loginItems"),
                        pane: "com.apple.LoginItems-Settings.extension"),
            ]),
        ]
    }

    // Settings still worth switching on; only counted on 8 GB Macs, where every bit helps
    static var pending: Int {
        suggested ? settings().flatMap(\.items).filter { $0.isOn == false }.count : 0
    }

    static func open(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:" + pane)!)
    }
}
