<p align="center">
  <img src="docs/icon.png" width="128" alt="AutoPass app icon">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  No more manual 6-digit code entry. Secure utility to automate iCloud Passwords pairing for third-party browsers on macOS.
</p>

<p align="center">
  <b>English</b> · <a href="docs/readme/README.zh-Hans.md">简体中文</a> · <a href="docs/readme/README.zh-Hant.md">繁體中文</a> · <a href="docs/readme/README.es.md">Español</a> · <a href="docs/readme/README.fr.md">Français</a> · <a href="docs/readme/README.de.md">Deutsch</a> · <a href="docs/readme/README.ja.md">日本語</a> · <a href="docs/readme/README.ko.md">한국어</a> · <a href="docs/readme/README.pt-BR.md">Português (Brasil)</a> · <a href="docs/readme/README.ru.md">Русский</a> · <a href="docs/readme/README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="docs/screenshot.png" width="820" alt="The AutoPass window: status, the list of browsers with pair and pause buttons, and recent activity">
</p>

## What it does

Apple's iCloud Passwords extension for Chrome, Edge, Vivaldi, Brave, Arc and other browsers pairs with your Mac by showing a 6-digit code that you have to retype. It happens after every browser restart and every few hours. AutoPass types the code for you, with checks that make it about as safe as doing it by hand.

- **Starts by itself.** About a second after you start browsing and pause, AutoPass opens iCloud Passwords, types the code and closes the popup again.
- **Works with several browsers at once**, each with its own pair and pause buttons. Add any browser that Apple's helper supports.
- **Quick and quiet.** Apple's code window is on screen for only a few milliseconds, and AutoPass picks up where it left off if you type or switch windows meanwhile.
- **Lives in the menu bar.** The icon is solid when you're paired, so you can tell at a glance.
- **In 11 languages**, following your Mac or your choice.

## Install

1. **Download** the latest `AutoPass-x.y.z.zip` from [Releases](https://github.com/ZhehanZhang/AutoPass/releases), unzip it and move AutoPass to Applications. It's signed and notarized by Apple and runs on macOS 14 or later, on Apple silicon and Intel.
2. **Add iCloud Passwords to your browser.** If it isn't there, AutoPass offers to install it or turn it on for you. Pinning it to the toolbar is optional.
3. **Open AutoPass and allow Accessibility** when it asks. AutoPass can't see Apple's code window or type without it, and it carries on by itself as soon as you turn it on in System Settings.

That's all. Start your browser and carry on browsing.

## Is it safe?

AutoPass types only when every one of these is true:

- The code comes from Apple's own signed helper, and goes only into Apple's iCloud Passwords popup.
- The browser is one you trust, recognized by its code signature, and it's the app in front.
- You've stopped typing.
- Optionally, you approved with Touch ID or your password. You can require this before typing, and before changing settings.

The clipboard is never used, codes are never stored or logged, and AutoPass has no networking code. The details are in [docs/SAFETY.md](docs/SAFETY.md) (English).

## Languages

AutoPass follows your Mac's language, or you can choose one under **Settings → General → Language**: English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano. This page is available in each of them using the links at the top.

## For developers

Building from source, the safety model in detail, and how to add or fix a translation are in [docs/DEVELOPING.md](docs/DEVELOPING.md) and [docs/SAFETY.md](docs/SAFETY.md) (English).

## License

AutoPass is free software under the [GNU Affero General Public License 3.0](LICENSE). Source code: <https://github.com/ZhehanZhang/AutoPass>. More from the author: <https://zhehanz.com>.
