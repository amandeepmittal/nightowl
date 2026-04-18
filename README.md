<p align="center">
  <img src="screenshots/app-icon.png" width="128" height="128" alt="NightOwl icon" />
</p>

<h1 align="center">NightOwl</h1>

<p align="center">
  A tiny macOS menu bar app that keeps your Mac awake for overnight AI agent runs, without the jargon.
</p>

<p align="center">
  <img src="https://img.shields.io/github/downloads/amandeepmittal/nightowl/total?style=flat-square&label=downloads" alt="GitHub Downloads" />
</p>

## Why

You walk away from your Mac while an AI agent, long job, or overnight script is still running. macOS helpfully sleeps the display, locks the screen, and in some cases logs you out. Your job dies. NightOwl is one toggle in the menu bar that prevents idle sleep cleanly, using Apple's public power-management API, and warns you about system settings that could still interrupt the run (battery, clamshell, auto-logout, screen lock).

## Features

- **One-click keep-awake** - flip a single menu bar toggle to hold a system-wide sleep assertion until you release it
- **Awake modes** - Indefinite, Until 8:00 AM, For 1 / 4 / 8 / 12 hours, or a custom release time
- **Keep display awake too** - optional second assertion that also blocks display sleep (disabled by default so the screen still dims)
- **Smart warnings** - surfaces system conditions that could still end your run: on battery, lid closed, auto-logout enabled, screen will lock; each links straight to the relevant System Settings pane
- **Device-aware** - battery and clamshell warnings only appear on MacBooks; hidden on Mac Studio, mini, and iMac
- **Status line** - shows when the current session started, when it releases, and how long is left
- **Launch at login** - register with macOS via `SMAppService` from Settings
- **No dock icon** - lives entirely in the menu bar via `NSStatusItem` with activation policy `.accessory`
- **Pure IOKit** - uses `IOPMAssertionCreateWithName` directly; no shelling out to `caffeinate`, no background processes

## How it works

- **Sleep prevention.** IOKit `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleSystemSleep`, plus an independent second assertion for `kIOPMAssertionTypePreventUserIdleDisplaySleep` when "Keep display awake too" is enabled. Both assertion IDs are held separately so the display toggle is cleanly additive.
- **Auto-release.** A `DispatchSourceTimer` fires at the scheduled release time and calls `release()` on the sleep assertion.
- **Power-state warnings.** `IOPSCopyPowerSourcesList` detects portable vs desktop; `IOPSNotificationCreateRunLoopSource` observes AC/battery transitions and refreshes the warnings list on change.
- **System settings.** `CFPreferencesCopyValue` reads `com.apple.loginwindow autoLogOutDelay` and `com.apple.screensaver askForPassword` / `askForPasswordDelay` to surface the auto-logout and screen-lock warnings.

## Install

1. Download `NightOwl-vX.X.X.zip` from the [latest release](https://github.com/amandeepmittal/nightowl/releases/latest)
2. Unzip and move `NightOwl.app` to your Applications folder
3. Remove the quarantine flag (required once for unsigned builds):
   ```bash
   xattr -cr /Applications/NightOwl.app
   ```
4. Open `NightOwl.app` from Applications or Spotlight

## Verify it is working

While NightOwl's toggle is ON, run:

```bash
pmset -g assertions | grep NightOwl
```

You should see `PreventUserIdleSystemSleep` held by `NightOwl keep-awake`, and (if Keep display awake too is on) a second `PreventUserIdleDisplaySleep` assertion named `NightOwl keep-display-awake`. Flip the toggle off, re-run the command, and both should be gone.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ (to build from source)

## Tech Stack

- Swift 5.9, SwiftUI
- `NSStatusItem` + `NSPopover` for menu bar integration
- IOKit (`IOPMAssertionCreateWithName`, `IOPSCopyPowerSourcesList`, `IOPSNotificationCreateRunLoopSource`) for sleep prevention and power-source monitoring
- `CFPreferences` for reading system login and screensaver settings
- `SMAppService` for launch-at-login on macOS 13+
- `DispatchSourceTimer` for auto-release scheduling
- CoreGraphics + ImageIO for the generated app and menu bar icons (see `NightOwl/Assets.xcassets/AppIcon.appiconset/_generate_icons.swift`)
- No third-party dependencies

## License

Apache-2.0

## Author

[Aman Mittal](https://amanhimself.dev)
