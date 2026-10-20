<div align="center">

<img src="docs/icon.svg" alt="MemBar icon" width="128">

# MemBar

### Your 8 GB Mac, explained in one glance, with one fix per click.

A tiny menu bar app for Macs with little memory. It shows how much pressure your memory is under,<br>
names the apps that cause it, and suggests what to close.<br>
Made on and for the **MacBook Neo**. It works on any Mac running macOS 14 or later.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square)](#install)
[![Memory used: 11 MB](https://img.shields.io/badge/memory%20used-11%20MB-000000?style=flat-square)](#how-light-is-it)
[![Dependencies: 0](https://img.shields.io/badge/dependencies-0-000000?style=flat-square)](#how-light-is-it)
[![Languages: 5](https://img.shields.io/badge/languages-EN%20%C2%B7%20FR%20%C2%B7%20ES%20%C2%B7%20JA%20%C2%B7%20ZH-000000?style=flat-square)](#languages)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-000000?style=flat-square)](LICENSE)

**[Install](#install)** · [How it decides](#how-it-decides) · [Terminal](#in-the-terminal-mem) · [Version française](README.fr.md)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/menu-dark.svg">
  <img src="docs/menu-light.svg" alt="MemBar menu: memory pressure, biggest consumers, and what to do" width="100%">
</picture>

<sub>Mockup of the real menu, drawn from a live reading on a MacBook Neo (8 GB).</sub>

</div>

---

## Why

The MacBook Neo comes with **8 GB of memory, soldered and not upgradable**. For mail, a browser and a few apps that's enough. A Notion window, a Slack window and an AI app later, your Mac is quietly writing gigabytes of swap to the SSD.

macOS rarely tells you when this happens. Activity Monitor shows a small graph and a pile of numbers, but it never tells you what to close. On GitHub, the "RAM optimizers" fall into three groups:
- **dashboards** that show more numbers;
- **cleaners** that run `purge`, which only empties a cache for a few seconds;
- **hacks** that turn swap off, which on an 8 GB Mac means apps get killed.

MemBar does one thing: it **turns the numbers into advice you can act on**.

## What it shows

| | |
|---|---|
| **● 2.4G** in the menu bar | A dot for the kernel's own memory-pressure level: **● green, ◐ orange, ▲ red**. The shape changes too, so it reads without colour. Followed by the swap in use, which you can hide. Refreshed every 15 seconds. |
| **Swap curve** | The last 30 minutes of swap, one bar per reading, coloured by pressure. You see at a glance whether it's climbing or holding. |
| **Biggest consumers** | Apps sized the way Activity Monitor's *Memory* column sizes them, with every helper process added to its parent app. One line for Notion instead of fourteen. **Click an app to quit it.** |
| **Electron tag** | Shows which apps bundle their own copy of Chrome. These are usually the heaviest ones. |
| **What to do** | Short tips worked out from what is actually running right now. Some of them are one click. |
| **Lighten macOS** | On Macs with 16 GB or less: the system settings worth a look, with their current state and a badge for what's left to do. [More below](#lighten-macos). |
| **Open in Terminal** | The same reading as text, through `mem`. |

## How it decides

Two tips come up whatever the pressure, because they're worth knowing early:

| You see | Because | One click does |
|---|---|---|
| *Firefox grew by 700 MB in 40 min* | An app gained at least 500 MB and 50% over its lowest reading of the past hour, with at least 10 minutes of history. Usually a runaway tab or a leak. | Quits the app, so reopening it starts fresh. |
| *3 apps unused for over 2 h hold 900 MB* | Open apps that haven't been in front for 2 hours, counted from when MemBar started. Terminals, music players and call apps are never counted, since quitting them would cut something off. | Quits them (each may ask you to save first). |

When pressure is **normal** and swap is low, the rest stays quiet: *"Nothing to do, all good 👍"*. Otherwise:

| You see | Because | One click does |
|---|---|---|
| *Notion uses 1.5 GB: switch to the web version* | A desktop app over 150 MB has an identical web version (Notion, Slack, Discord, Teams, Figma, Linear, Spotify, Claude, ChatGPT). | Quits the app (it may ask you to save first) and opens the web version in your browser. |
| *3 Electron apps use 2.1 GB* | Two or more Electron apps are running, each with its own Chrome engine. | — |
| *Swap grew by 1.2 GB in 25 min* | Swap that keeps growing while you work is the real sign of trouble. A large but stable swap is not. | — |
| *Firefox uses 2.3 GB: close or unload tabs* | Pressure is elevated and one browser uses over 800 MB. | — |
| *Swap is at 3.4 GB: a restart will clear it* | Swap is above 40% of your RAM. | — |

There are no hidden tricks: no `purge`, no `sudo`, no swap tweaks, no kernel settings. You stay in control.

## Lighten macOS

This submenu shows up on Macs with **16 GB or less**. On **8 GB** Macs, a badge counts the settings that are still worth switching on. MemBar detects whether you're on a laptop and adjusts each hint.

| Setting | What you really gain |
|---|---|
| **Reduce transparency** | A little less work for the graphics chip, and a bit more battery on a laptop. |
| **Reduce motion** | Same: fewer animations to draw. |
| **Hide widgets on the desktop** | Each widget runs as its own small process. |
| **Login items and background apps** | **The biggest win.** Apps that launch silently at every startup and sit in memory all day. |

**Why does it open System Settings instead of flipping the switch?** macOS blocks apps from changing these settings (`defaults write com.apple.universalaccess` fails with *"Could not write domain"*). The only way around it is to ask for Full Disk Access or Accessibility control, which is far too much for a 400-line tool. So MemBar shows you the **current state** and opens **the exact pane** in one click, and you flip the switch.

There are no exaggerated promises here either: visual effects cost a few dozen MB at most. On a laptop, they matter more for the battery than for memory.

## Install

Copy this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/kxrz/membar/main/install.sh | zsh
```

About 5 seconds later, the dot is in your menu bar and will open at every login.

The script **compiles MemBar on your Mac** from the ~400 lines in [`Sources/`](Sources). It downloads no binary, needs no admin rights, and triggers no Gatekeeper warning. Read it before you run it: [`install.sh`](install.sh).

If macOS asks for the *Command Line Tools*, accept, or run `xcode-select --install` first. It's Apple's free compiler.

<details>
<summary>Install from a clone, or somewhere else</summary>

```sh
git clone https://github.com/kxrz/membar && cd membar && ./install.sh
```

The app goes into `~/Applications` and the `mem` command into `~/.local/bin`. To change either location, set `MEMBAR_APP_DIR` or `MEMBAR_BIN_DIR`.
</details>

**Uninstall:** `./uninstall.sh`, or delete `~/Applications/MemBar.app`, `~/.local/bin/mem` and `~/Library/LaunchAgents/io.github.kxrz.membar.plist`.

## In the terminal: `mem`

```
$ mem
● Memory pressure: elevated  ·  37% free · 2.7 GB compressed · 2.4 GB swap
  3.3 GB   Web pages (Safari, Mail…)
  1.5 GB   Notion  · Electron
  1.3 GB   Claude  · Electron
  374 MB   claude
  346 MB   Microsoft Outlook
  301 MB   Safari

What to do
  • Notion uses 1.5 GB: switch to the web version (quits the app)
  • Claude uses 1.3 GB: switch to the web version (quits the app)
  • Web pages (Safari, Mail…) uses 3.3 GB: close or unload tabs
  • Quit (⌘Q) apps you are not using, closing the window is not enough
```

`mem 10` shows the top 10 apps. It's the same binary as the menu bar app, so the advice is always the same.

## How light is it?

- **11 MB of memory** while running, measured with `footprint` on a MacBook Neo. A tool for an 8 GB Mac can't be part of the problem.
- **0 dependencies.** Plain Swift and AppKit, with readings straight from the kernel (`sysctl`, `proc_pid_rusage`). It doesn't run `top` or `ps` in a loop.
- **No network, no analytics, no account.** The only thing that ever opens a URL is you clicking a "web version" tip.
- **~400 lines** that you can read in a coffee break.

## Languages

MemBar speaks **English, Français, Español, 日本語 and 简体中文**. It follows the language order set in *System Settings → General → Language & Region* and falls back to English. Each language is a single file in [`Resources/`](Resources). Fixes from native speakers are very welcome.

## FAQ

**Is it only for the MacBook Neo?** No. It was built on a Neo because 8 GB is where the problem shows first. It's just as useful on any 8 or 16 GB Mac with Apple Silicon, and it should run on Intel Macs too (untested so far).

**Why build from source instead of downloading an app?** A downloaded app needs a paid Apple notarization to open without a warning. Building locally avoids that, and you can read the code before it runs.

**Should I worry about swap at all?** Apple Silicon SSDs are fast, so some swap is normal. What matters is the dot's colour and whether swap **keeps growing**. MemBar watches both.

**Does it connect to the internet?** Once a day, to ask GitHub for the latest version number. Nothing about your Mac is sent. When a new version is out, an *Update* line appears in the menu: one click rebuilds MemBar from source, like the installer, and it's back within a minute. To turn the check off: `defaults write io.github.kxrz.membar checkUpdates -bool NO`.

**Can it free memory by itself?** No, on purpose. The only way to really free memory is to quit something, and you're the one who knows what you need.

## Contributing

Issues and pull requests are welcome, especially:
- new desktop apps with a web twin, added to `Advisor.webAlternatives`;
- translation fixes;
- real screenshots from your own Mac.

To keep it small, MemBar will stay at **five languages and one screen**.

## License

[GPL-3.0](LICENSE) © 2026 LesWWW.com (Florent Bertiaux). Any redistributed version must keep the attribution *"Based on MemBar by LesWWW.com"*, as described in [NOTICE](NOTICE).

---

<div align="center"><sub>Made by <b><a href="https://leswww.com">LesWWW.com</a></b>. Why. What. Which way.</sub></div>
