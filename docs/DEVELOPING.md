# Developing AutoPass

Building from source, how the translations work, and a reference for what the app does. The README is for people who just want to use AutoPass.

## Building

You need the Xcode Command Line Tools (Xcode itself isn't required).

```bash
Scripts/build-app.sh          # builds build/AutoPass.app, signed with your Developer ID if you have one
Scripts/test.sh               # runs the unit tests
```

`open build/AutoPass.app --args --pane=security` opens Settings straight on a pane (`autopass`, `security` or `general`), which is handy when checking a layout.

Use the same signing identity for every build: Accessibility permission is tied to the code signature, so ad-hoc builds lose it on each rebuild. The build script stamps the real SDK version into the binary, so macOS gives the app the current glass design, and it verifies that the app has no entitlements.

To make a release (universal, Developer ID signed with a secure timestamp, notarized and stapled, written to `dist/`):

```bash
AUTOPASS_NOTARY_PROFILE=<profile> Scripts/release.sh
```

The profile is a `notarytool` keychain profile; the script header says how to create one. `Scripts/make-icon.sh` turns `Resources/AppIcon.svg` into `Resources/AppIcon.icns`.

### Layout

```
Sources/AutoPassCore/   pure logic, unit-tested: policy rules, code parsing, trusted browsers, translation lookup,
                        reader for Apple's supported-browser list (the helper's parent launch constraint)
Sources/AutoPass/       menu bar app: engine, Accessibility scanners, key injection, approval, SwiftUI settings
Resources/              Info.plist, the app icon (AppIcon.svg, AppMark.svg for the mark alone, AppIcon.icns),
                        and one folder per language (fr.lproj, ja.lproj, …) with its Localizable.strings
Scripts/                build-app.sh, release.sh, make-icon.sh, test.sh
tools/ax-probe.swift    read-only probe used during the feasibility study (masks digits, never types)
```

Decisions are written to the system log (never the code, never page addresses), so you can see why AutoPass did or didn't act:

```bash
log stream --info --predicate 'subsystem == "com.zhehanz.AutoPass"'
```

## Translating

AutoPass follows your Mac's language, or you can pick one under **General → Language**. The change applies straight away, in the window, the menu bar menu, alerts and notifications, and the Activity list.

| Language | Code | | Language | Code |
|---|---|---|---|---|
| English | `en` | | 日本語 (Japanese) | `ja` |
| 简体中文 (Simplified Chinese) | `zh-Hans` | | 한국어 (Korean) | `ko` |
| 繁體中文 (Traditional Chinese) | `zh-Hant` | | Português (Brasil) | `pt-BR` |
| Español (Spanish) | `es` | | Русский (Russian) | `ru` |
| Français (French) | `fr` | | Italiano (Italian) | `it` |
| Deutsch (German) | `de` | | | |

Names that aren't AutoPass's own stay as they are: *iCloud Passwords* is the extension's name in your browser, and *Touch ID* is Apple's. System terms (Accessibility, System Settings, Login Items, …) use the wording macOS uses in that language. The system log stays in English so reports are easy to read.

The translations were written with care, but not every one has been reviewed by a native speaker. Corrections are very welcome: open an issue or a pull request that edits the file for your language.

### How it works

Each language is a `Resources/<code>.lproj/Localizable.strings` file, copied into the app by `Scripts/build-app.sh`. **The English text is the key**, so the code reads naturally (`tr("Pair Now")`) and a missing translation simply shows English. A `%@` marks a name or a number, and a translation may reorder them with `%1$@`, `%2$@`.

Most of what the Activity list says is put together in English by the engine ("Paired with Google Chrome"). `Localizer` (in `AutoPassCore`) translates those at display time by matching them against the same file: the template `Paired with %@` matches that sentence, and each piece it captures is translated too. So the engine never needs to know about languages.

### Adding or fixing a language

1. Copy `Resources/en.lproj` to `Resources/<code>.lproj` (use the language's code from the table above, or a new one such as `pt-PT`) and translate the right-hand side of each line. Keep every `%@`, and keep the key (the left-hand side) exactly as it is.
2. Add the language to `L10n.languages` in `Sources/AutoPass/L10n.swift` (its own name, written in that language) and to `CFBundleLocalizations` in `Resources/Info.plist`.
3. Run `Scripts/test.sh`. It checks that every language has exactly the same keys as English, no empty translations, and the same number of placeholders in every string.
4. Build with `Scripts/build-app.sh`, choose the language under General → Language, and look through the three panes. Long words (German, Russian) are the usual cause of cramped rows.
5. Translate the README too: copy one of the files in `docs/readme/` to `docs/readme/README.<code>.md`, translate it, and add the language to the selector line at the top of every README (`README.md` and all the files in `docs/readme/`). The technical docs in `docs/` stay in English.

New text in the app goes through `tr("…")` (or `L10n.message(…)` for a sentence built elsewhere), and its English line is added to every `.lproj`; the tests fail until each language has it.

## Behavior reference

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
- **General** has the **Language**, Open at login, the menu bar icon and notifications, a **Permissions** card that shows what macOS currently allows (Accessibility, Notifications and, when macOS needs your OK, Login Items) with a button to fix each one that isn't, and the version and license. It updates live while the window is open, so you see a change as soon as you make it in System Settings.

A lock indicator in the top right corner of the AutoPass and Security panes shows whether browsers and security settings are locked. Clicking it, or any locked control, asks for Touch ID or your password. Touch ID is fingerprint only. Password is the system prompt, which also accepts Touch ID. On a Mac without Touch ID (or with no fingerprints enrolled), choosing Touch ID asks for your password instead, and the Security pane says so, so a setting never turns into "no check" or locks you out of your own settings.

## Status and caveats

Verified live on macOS 27.0 with Chrome, and with Edge through its Extensions menu when iCloud Passwords isn't pinned: AutoPass waited for a pause, opened iCloud Passwords, read Apple's code window, typed and confirmed the six digits, and saw pairing complete, with no prompt and the popup gone afterwards. Unit tests cover the policy logic, and the supported-browser list is read from Apple's helper on this Mac.

Not yet exercised live: the install and turn-on prompt, pairing started by the in-page "Enable Password AutoFill" prompt, and the Touch ID approval path (including a prompt that makes the browser close its popup, which AutoPass handles by remembering the approval). Everything fails safe by not typing, and says why in Activity.

- The toolbar button is found by its "iCloud" name, so a browser UI in another language may need that to match.
- A freshly started browser has no Apple helper until something opens the extension, so AutoPass treats "no helper" as "not paired yet".
- Apple's helper changes between macOS releases; the supported-browser list is re-read from it at each launch.
