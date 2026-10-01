<p align="center">
  <img src="../icon.png" width="128" alt="AutoPass 应用图标">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  无需再手动输入 6 位验证码。一款安全的 macOS 实用工具，可为第三方浏览器自动完成 iCloud Passwords 配对。
</p>

<p align="center">
  <a href="../../README.md">English</a> · <b>简体中文</b> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a> · <a href="README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="AutoPass 窗口：状态、带配对和暂停按钮的浏览器列表，以及最近活动">
</p>

## 功能

Apple 的 iCloud Passwords 扩展程序（适用于 Chrome、Edge、Vivaldi、Brave、Arc 等浏览器）会通过显示一个 6 位验证码来与你的 Mac 配对，你需要手动重新输入。每次重启浏览器后、以及每隔几个小时都会发生一次。AutoPass 会替你输入验证码，并通过多重检查，让它几乎与手动输入一样安全。

- **自动开始。** 开始浏览并停顿约一秒后，AutoPass 会打开 iCloud Passwords、输入验证码，并再次关闭弹出窗口。
- **同时支持多个浏览器**，每个浏览器都有各自的配对和暂停按钮。可添加 Apple 辅助程序支持的任何浏览器。
- **快速而安静。** Apple 的验证码窗口只会在屏幕上停留几毫秒；如果你在此期间输入或切换窗口，AutoPass 会稍后接着完成。
- **常驻菜单栏。** 配对完成后图标会变为实心，一眼就能看出状态。
- **支持 11 种语言**，可跟随你的 Mac，也可自行选择。

## 安装

1. **下载** [Releases](https://github.com/ZhehanZhang/AutoPass/releases) 页面中最新的 `AutoPass-x.y.z.zip`，解压后将 AutoPass 移到“应用程序”。它已由 Apple 签名并公证，支持 macOS 14 或更高版本，适用于 Apple 芯片和 Intel。
2. **在浏览器中添加 iCloud Passwords。** 如果尚未添加，AutoPass 会提示你安装或为你开启。将它固定到工具栏是可选的。
3. **打开 AutoPass，并在提示时允许“辅助功能”。** 没有它，AutoPass 无法看到 Apple 的验证码窗口，也无法输入；在“系统设置”中开启后，它会自动继续。

就这些。启动浏览器，照常浏览即可。

## 安全吗？

只有以下每一项都成立时，AutoPass 才会输入：

- 验证码来自 Apple 自己签名的辅助程序，并且只会输入到 Apple 的 iCloud Passwords 弹出窗口中。
- 该浏览器是你信任的，通过其代码签名识别，并且它是最前面的 App。
- 你已经停止输入。
- （可选）你已用触控 ID 或密码批准。你可以要求在输入前、以及更改设置前进行批准。

从不使用剪贴板，验证码从不被存储或记录，AutoPass 也没有任何联网代码。详情见 [docs/SAFETY.md](../SAFETY.md)（英文）。

## 语言

AutoPass 会跟随你 Mac 的语言，你也可以在 **设置 → 通用 → 语言** 中选择：English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano。本页面也提供上述各语言版本，请使用顶部的链接切换。

## 开发者

从源代码构建、安全模型的详细说明，以及如何添加或修正翻译，请见 [docs/DEVELOPING.md](../DEVELOPING.md) 和 [docs/SAFETY.md](../SAFETY.md)（英文）。

## 许可证

AutoPass 是依据 [GNU Affero 通用公共许可证第 3 版](../../LICENSE)发布的自由软件。源代码：<https://github.com/ZhehanZhang/AutoPass>。作者的更多内容：<https://zhehanz.com>。
