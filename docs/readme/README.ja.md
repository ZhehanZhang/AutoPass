<p align="center">
  <img src="../icon.png" width="128" alt="AutoPassのアイコン">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  6桁のコードを手入力する手間はもう不要。macOSのサードパーティ製ブラウザでiCloud Passwordsのペアリングを自動化する、安全なユーティリティです。
</p>

<p align="center">
  <a href="../../README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <b>日本語</b> · <a href="README.ko.md">한국어</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a> · <a href="README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="AutoPassのウインドウ: 状態、ペアリングと一時停止のボタンが付いたブラウザ一覧、最近のアクティビティ">
</p>

## できること

Chrome、Edge、Vivaldi、Brave、Arcなどのブラウザ向けのAppleのiCloud Passwords拡張機能は、6桁のコードを表示し、それを手入力することでMacとペアリングします。これはブラウザを再起動するたびと、数時間ごとに発生します。AutoPassは、手入力とほぼ同じ安全性を保つチェックを行いながら、そのコードを代わりに入力します。

- **自動で始まります。** ブラウジングを始めて少し手を止めてから約1秒後に、AutoPassがiCloud Passwordsを開き、コードを入力して、ポップアップを閉じます。
- **複数のブラウザに同時に対応。** ブラウザごとにペアリングと一時停止のボタンがあります。Appleのヘルパーが対応している任意のブラウザを追加できます。
- **速くて静か。** Appleのコードウインドウが画面に出ているのはほんの数ミリ秒です。その間に入力したりウインドウを切り替えたりしても、AutoPassは後から続きを行います。
- **メニューバーに常駐。** ペアリングが済むとアイコンがはっきり表示されるので、ひと目で分かります。
- **11言語に対応。** Macの言語に合わせることも、自分で選ぶこともできます。

## インストール

1. [Releases](https://github.com/ZhehanZhang/AutoPass/releases) から最新の `AutoPass-x.y.z.zip` を**ダウンロード**し、展開してAutoPassをアプリケーションフォルダに移動します。Appleによる署名と公証済みで、macOS 14以降のApple siliconとIntelで動作します。
2. **ブラウザにiCloud Passwordsを追加します。** 入っていない場合は、AutoPassがインストールやオン操作を案内します。ツールバーへのピン留めは任意です。
3. **AutoPassを開き、求められたらアクセシビリティを許可します。** これがないとAutoPassはAppleのコードウインドウを見ることも入力することもできません。システム設定でオンにすると、自動的に続行します。

これで完了です。ブラウザを起動して、いつもどおりブラウジングしてください。

## 安全性

AutoPassは、次のすべてが満たされたときだけ入力します。

- コードはAppleの署名済みヘルパーから来たもので、入力先はAppleのiCloud Passwordsのポップアップだけです。
- ブラウザは信頼済みのもので、コード署名で確認され、最前面のAppです。
- 入力の手が止まっている。
- 任意で、Touch IDまたはパスワードで承認していること。入力前と設定変更前に、これを必須にできます。

クリップボードは一切使わず、コードは保存も記録もされず、AutoPassにはネットワーク通信のコードがありません。詳しくは [docs/SAFETY.md](../SAFETY.md)（英語）をご覧ください。

## 言語

AutoPassはMacの言語に従います。**設定 → 一般 → 言語** で選ぶこともできます: English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano。このページも、上のリンクからそれぞれの言語で読めます。

## 開発者向け

ソースからのビルド、安全性の仕組みの詳細、翻訳の追加や修正の方法は、[docs/DEVELOPING.md](../DEVELOPING.md) と [docs/SAFETY.md](../SAFETY.md)（英語）にあります。

## ライセンス

AutoPassは[GNU Affero General Public License 3.0](../../LICENSE)に基づくフリーソフトウェアです。ソースコード: <https://github.com/ZhehanZhang/AutoPass>。作者のサイト: <https://zhehanz.com>。
