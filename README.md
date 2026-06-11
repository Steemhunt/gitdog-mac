# GitDog for Mac

A pixel dog lives in your menu bar. Sometimes it brings you a repo to review —
you say what you think and earn Treats (USDC). Reviewer client for
[gitdog.xyz](https://gitdog.xyz).

Menu-bar-only (no Dock icon, no windows): `NSStatusItem` + `NSPopover` hosting
SwiftUI. This repo is the open-source client; it contains **no secrets** and
talks only to the gitdog server's versioned `/api/v1`
([contract](https://github.com/Steemhunt/gitdog/blob/main/docs/api-v1.md)).

## Build & run (no Xcode required)

Requires macOS 14+ and Swift 6 command line tools.

```bash
# dev loop
swift build && swift run            # status item appears; popover on click

# bundled app (needed for launch-at-login and the gitdog:// URL scheme)
./scripts/make-app.sh release
open dist/GitDog.app
```

Point at a non-default server with `GITDOG_SERVER=http://localhost:3000`.

## Architecture

| File | Owns |
|---|---|
| `main.swift` | NSApplication bootstrap, `.accessory` activation policy |
| `AppDelegate.swift` | app lifecycle |
| `StatusItemController.swift` | menu bar item, template icon, popover anchoring |
| `PopoverRootView.swift` | SwiftUI popover content |
| `AppConfig.swift` | server URL + version |
| `scripts/make-app.sh` | SwiftPM build → `dist/GitDog.app` bundle (CLT-only) |

Design reference (brand tokens, popover specs at 360px, sprite strips):
`design/` in the [server repo](https://github.com/Steemhunt/gitdog).

## Status

Scaffold (#2). Upcoming: animated sprite states (#3), GitHub sign-in via
`gitdog://` handoff (#4), Inbox (#5), feedback composer (#6), Treats (#7),
onboarding (#8), signed DMG (#9).
