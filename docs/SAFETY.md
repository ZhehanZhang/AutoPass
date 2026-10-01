# How AutoPass stays safe

AutoPass types a verification code into your browser, so it is careful about when it may do that. This page is the detail behind the short summary in the README.

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
