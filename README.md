# GitDog for Mac

A pixel dog lives in your menu bar. Sometimes it brings you a repo to review —
you say what you think and earn Treats (USDC). Reviewer client for
[gitdog.xyz](https://gitdog.xyz).

Menu-bar-only (no Dock icon, no windows): `NSStatusItem` + `NSPopover` hosting
SwiftUI. This repo is the open-source client; it contains **no secrets** and
talks only to the gitdog server's versioned `/api/v1`
([contract](https://github.com/Steemhunt/gitdog/blob/main/docs/api-v1.md)).

## Build & run (no Xcode required)

Requires macOS 14+ and Swift 6 command line tools (`xcode-select --install`).

```bash
# UI dev loop — status item appears, popover on click.
# No app bundle, so the gitdog:// scheme isn't registered: fine for tweaking
# views, but sign-in can't complete this way.
swift build && swift run

# Full bundled app — registers the gitdog:// auth callback + launch-at-login.
# Use this for anything involving sign-in.
./scripts/make-app.sh release
open dist/GitDog.app
```

Point at a non-default server with `GITDOG_SERVER` (absolute http(s) URL). Bake
it into the bundle at build time, then launch normally — `open` does not forward
your shell environment, so the bake is what makes it stick:

```bash
GITDOG_SERVER=https://your-server.example.com ./scripts/make-app.sh
open dist/GitDog.app
```

### Joining a test session

For a shared pre-deploy test, the host runs the server behind a tunnel and
shares its URL. Build against it and launch:

```bash
git clone https://github.com/Steemhunt/gitdog-mac && cd gitdog-mac
GITDOG_SERVER=<tunnel-url-from-host> ./scripts/make-app.sh
open dist/GitDog.app          # pixel dog appears in the menu bar
```

Click the dog → enter your GitHub username → the browser hands you back to the
app and your real breed is revealed. A locally built app isn't quarantined, so
Gatekeeper won't get in the way (no signing needed). If the host's tunnel URL
changes, re-run the last two commands with the new URL.

## Architecture

| File | Owns |
|---|---|
| `main.swift` | NSApplication bootstrap, `.accessory` activation policy |
| `AppDelegate.swift` | app lifecycle |
| `StatusItemController.swift` | menu bar item, template icon, popover anchoring |
| `PopoverRootView.swift` | SwiftUI popover content |
| `AppConfig.swift` | server URL (`GITDOG_SERVER` override) + version |
| `AuthManager.swift` | sign-in lifecycle, `gitdog://` callback, Keychain session |
| `SignInView.swift` / `OnboardingReveal.swift` | sign-in hero, analyze→breed reveal |
| `InboxView.swift` / `ComposerView.swift` / `TreatsView.swift` | reviewer surfaces |
| `BreedLadderView.swift` | breed ladder (from `/api/v1/breeds`) |
| `Sprites.swift` / `SpriteAnimator.swift` | menu bar dog animation |
| `scripts/make-app.sh` | SwiftPM build → `dist/GitDog.app` bundle (CLT-only) |

Design lives in the team's `z-design/gitdog-design` package (brand tokens,
popover specs at 360px, breed art), not in this repo. Runtime breed images are
served by the server from `public/breeds`.

## Status

Reviewer experience is built: sign-in handoff, analyze→breed reveal onboarding,
Inbox, feedback composer, Treats, breed ladder, animated menu bar sprite.
Remaining before public release: signed/notarized DMG (#9) and the production
auth/deploy gates on the server side.
