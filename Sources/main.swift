// MemBar — know when your Mac is short on memory, and what to close
// Copyright (C) 2026 Florent Bertiaux — GPL-3.0, see LICENSE and NOTICE
import AppKit

let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "mem":
    CLI.run(top: args.count > 1 ? Int(args[1]) ?? 6 : 6)
    exit(0)
case "--enable-login", "--disable-login":
    LoginItem.set(args[0] == "--enable-login")
    exit(0)
default:
    break
}

// One status item is enough
if let id = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 { exit(0) }

let app = NSApplication.shared
let delegate = MenuBar()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
