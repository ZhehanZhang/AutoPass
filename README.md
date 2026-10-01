<p align="center">
  <img src="docs/icon.png" width="128" alt="AutoPass app icon">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  A small macOS menu bar app that types the 6-digit iCloud Passwords verification code into your browser for you.
</p>

<p align="center">
  <img src="docs/screenshot.png" width="820" alt="The AutoPass window: a status icon beside a list of browsers, with pair and pause buttons for each, and a short activity list">
</p>

Apple's iCloud Passwords extension for Chrome (and Edge, Vivaldi, Brave, Arc, …) pairs with macOS by showing a code in a system window that you retype into the extension popup. This happens after every browser restart and every few hours. AutoPass does the retyping, with checks that make it about as safe as doing it by hand.

## Install

1. **Download** the latest notarized `AutoPass-x.y.z.zip` from the [Releases](https://github.com/ZhehanZhang/AutoPass/releases) page, unzip it and move `AutoPass.app` to Applications. It runs on macOS 14 or later, on Apple silicon and Intel.
2. **Install iCloud Passwords in your browser.** Pinning it to the toolbar is optional. If it's pinned, AutoPass presses its button. If it isn't, AutoPass opens the Extensions (puzzle piece) menu and picks it from the list. If it can't find the extension in either place, it offers to install it or turn it on.
3. **Open AutoPass and allow Accessibility.** The window opens on its own the first time, with the status showing "Needs access" and a plain explanation. Click **Allow**, then turn on AutoPass in System Settings → Privacy & Security → Accessibility. AutoPass carries on by itself as soon as it's on, and *Pair Now* stays off until then. Nothing else is asked for up front: notifications are requested the first time AutoPass has something to tell you (or when you press Allow under General → Permissions).

That's all. Start your browser, begin browsing, and about a second after you pause, AutoPass has opened iCloud Passwords, typed the code and closed the popup again.

To build it yourself instead, see [Building](#building).

## What it does

- **Starts pairing when browsing starts.** Once a trusted browser has been up a second, a web page is showing and you've paused, AutoPass opens iCloud Passwords from the toolbar button or the Extensions menu (at most twice per session; if Apple's helper never shows a code it stops and says why in Activity). Turn this off under Security → Pairing.
- **Fills in the code whenever Apple's code window appears**, however it was started: the toolbar button, the in-page "Enable Password AutoFill" prompt, or *Pair Now*. The code is typed as soon as every check below passes.
- **Closes the popup after filling in the code**, whoever opened it.
- **Several browsers at once.** Chrome, Edge, Vivaldi and friends are tracked side by side, each with its own paired state (remembered across restarts) and its own pair and pause buttons. Add browsers from the list of installed ones that Apple's helper accepts on this Mac. Browsers that draw their toolbar as web content (Vivaldi) are supported.
- **Nearly invisible.** Apple's code window is on screen for a few tens of milliseconds: AutoPass is told the instant the helper opens it, reads the code, and presses its Done button before typing. AutoPass never moves Apple's window, and it keeps the browser's popup out of sight until pairing finishes (anything hidden is put back if a pairing doesn't finish).
- **Recovers from interruptions.** If you type, switch windows or the popup closes on its own, AutoPass waits and tries again. It never gives up for good over an interruption, and only real failures count toward its attempt limit.
- **If iCloud Passwords isn't in a browser**, that browser's row says so and offers Install and Turn On.
- **Menu bar icon** is the AutoPass mark in plain monochrome. It's solid when AutoPass is done (paired), the dots are fainter than the key while something is pending, the whole mark is fainter when idle or paused, and a small dot appears in the corner when AutoPass needs you.
- **Activity** is always shown on the home page, in plain language, and never contains a verification code.

### Settings

A System Settings–style window in Liquid Glass (flat materials before macOS 26) with three panes:

- **AutoPass** shows the status beside your browsers, each with buttons to pair now and pause. *Pair Now* and *Pause* in the sidebar act on every browser at once.
- **Security** has **Authentication** (**Before typing** and **Edit browsers and security settings**, each Off, Touch ID or Password), whether pairing starts when you start browsing, and the safeguards below.
- **General** has Open at login, the menu bar icon and notifications, a **Permissions** card that shows what macOS currently allows (Accessibility, Notifications and, when macOS needs your OK, Login Items) with a button to fix each one that isn't, and the version and license. It updates live while the window is open, so you see a change as soon as you make it in System Settings.

A lock indicator in the top right corner of the AutoPass and Security panes shows whether browsers and security settings are locked. Clicking it, or any locked control, asks for Touch ID or your password. Touch ID is fingerprint only. Password is the system prompt, which also accepts Touch ID. On a Mac without Touch ID (or with no fingerprints enrolled), choosing Touch ID asks for your password instead, and the Security pane says so, so a setting never turns into "no check" or locks you out of your own settings.

## Safety model

AutoPass types only when **all** of these hold, re-checked after any approval prompt and before every digit:

| Check | Why |
|---|---|
| Code window belongs to Apple's signed helper (`com.apple.PasswordManagerBrowserExtensionHelper`) started for one of Apple's two extension IDs | the code can't be spoofed by another app's window |
| The browser that started the helper matches a trusted entry by **code signature** (identifier + Apple-issued team ID) | renamed or copied apps aren't trusted |
| Browser wasn't launched with `--user-data-dir`, `--remote-debugging-*`, `--load-extension`, `--headless`, … (on by default, can be turned off) | a throwaway browser can host a forged extension, which a code signature alone can't rule out |
| Exactly one extension popup is open, at `chrome-extension://<Apple's ID>/page_popup.html`, with six empty boxes and the first focused | typing only into Apple's page |
| The browser is the frontmost app (always required) and you've stopped typing | you're present and not interleaving keystrokes |
| Touch ID or password approval before typing (off by default; remembered for a short, configurable time) | a human decided |
| At most N codes per M minutes | no retry loops hammering the helper's lockout |

Delivery: digits go straight to the browser process (`postToPid`), one at a time. Each is confirmed in the popup's field before the next, and typing aborts if focus moves or a real keystroke arrives. The clipboard is never used, codes are never logged or stored (only a salted-in-memory fingerprint to avoid retyping the same code), and the app has no networking code.

With approval off (the default), the other checks are the whole gate; turn approval on if you want a human check on every pairing.

The app itself: hardened runtime, **no entitlements** (no debugger attach, no DYLD injection, no unsigned libraries), no auto-updater. Security settings are stored in your keychain (readable only by AutoPass without a prompt).

**Out of scope:** malware that fully controls your user account, or a compromised trusted browser, can do what you can do. AutoPass raises the bar to "must satisfy Apple's checks plus yours"; it doesn't make Accessibility permission harmless. Grant it only to software you trust, and keep this app small.

## Building

You need the Xcode Command Line Tools (Xcode itself isn't required).

```bash
Scripts/build-app.sh          # builds build/AutoPass.app, signed with your Developer ID if you have one
Scripts/test.sh               # runs the unit tests
```

Use the same signing identity for every build: Accessibility permission is tied to the code signature, so ad-hoc builds lose it on each rebuild. The build script stamps the real SDK version into the binary, so macOS gives the app the current glass design, and it verifies that the app has no entitlements.

To make a release (universal, Developer ID signed with a secure timestamp, notarized and stapled, written to `dist/`):

```bash
AUTOPASS_NOTARY_PROFILE=<profile> Scripts/release.sh
```

The profile is a `notarytool` keychain profile; the script header says how to create one. `Scripts/make-icon.sh` turns `Resources/AppIcon.svg` into `Resources/AppIcon.icns`.

### Layout

```
Sources/AutoPassCore/   pure logic, unit-tested: policy rules, code parsing, trusted browsers,
                        reader for Apple's supported-browser list (the helper's parent launch constraint)
Sources/AutoPass/       menu bar app: engine, Accessibility scanners, key injection, approval, SwiftUI settings
Resources/              Info.plist, the app icon (AppIcon.svg, AppMark.svg for the mark alone, AppIcon.icns)
Scripts/                build-app.sh, release.sh, make-icon.sh, test.sh
tools/ax-probe.swift    read-only probe used during the feasibility study (masks digits, never types)
```

Decisions are written to the system log (never the code, never page addresses), so you can see why AutoPass did or didn't act:

```bash
log stream --info --predicate 'subsystem == "com.zhehanz.AutoPass"'
```

## Status and caveats

Verified live on macOS 27.0 with Chrome, and with Edge through its Extensions menu when iCloud Passwords isn't pinned: AutoPass waited for a pause, opened iCloud Passwords, read Apple's code window, typed and confirmed the six digits, and saw pairing complete, with no prompt and the popup gone afterwards. Unit tests cover the policy logic, and the supported-browser list is read from Apple's helper on this Mac.

Not yet exercised live: the install and turn-on prompt, pairing started by the in-page "Enable Password AutoFill" prompt, and the Touch ID approval path (including a prompt that makes the browser close its popup, which AutoPass handles by remembering the approval). Everything fails safe by not typing, and says why in Activity.

- The toolbar button is found by its "iCloud" name, so a browser UI in another language may need that to match.
- A freshly started browser has no Apple helper until something opens the extension, so AutoPass treats "no helper" as "not paired yet".
- Apple's helper changes between macOS releases; the supported-browser list is re-read from it at each launch.

## License

AutoPass is free software under the [GNU Affero General Public License 3.0](LICENSE) (also at <https://www.gnu.org/licenses/agpl-3.0.html>). Source: <https://github.com/ZhehanZhang/AutoPass>. More from the author at <https://zhehanz.com>.
