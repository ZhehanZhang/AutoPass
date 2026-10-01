<p align="center">
  <img src="../icon.png" width="128" alt="AutoPass 앱 아이콘">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  6자리 코드를 더 이상 직접 입력하지 마세요. macOS에서 서드파티 브라우저의 iCloud Passwords 페어링을 자동화하는 안전한 유틸리티입니다.
</p>

<p align="center">
  <a href="../../README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ja.md">日本語</a> · <b>한국어</b> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a> · <a href="README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="AutoPass 창: 상태, 페어링 및 일시 정지 버튼이 있는 브라우저 목록, 최근 활동">
</p>

## 기능

Chrome, Edge, Vivaldi, Brave, Arc 등의 브라우저용 Apple iCloud Passwords 확장 프로그램은 6자리 코드를 표시하고 이를 다시 입력해야 Mac과 페어링됩니다. 브라우저를 다시 시작할 때마다, 그리고 몇 시간마다 이런 일이 생깁니다. AutoPass는 직접 입력하는 것과 거의 같은 수준의 안전을 지키는 확인 절차를 거쳐 코드를 대신 입력합니다.

- **저절로 시작됩니다.** 탐색을 시작하고 잠시 멈춘 지 1초쯤 뒤에 AutoPass가 iCloud Passwords를 열고, 코드를 입력한 다음 팝업을 다시 닫습니다.
- **여러 브라우저를 동시에 지원합니다.** 브라우저마다 페어링 및 일시 정지 버튼이 따로 있습니다. Apple 도우미가 지원하는 브라우저라면 무엇이든 추가할 수 있습니다.
- **빠르고 조용합니다.** Apple의 코드 창은 화면에 몇 밀리초만 나타나며, 그동안 입력하거나 창을 전환해도 AutoPass가 나중에 이어서 처리합니다.
- **메뉴 막대에 상주합니다.** 페어링되면 아이콘이 선명해져서 한눈에 알 수 있습니다.
- **11개 언어를 지원하며**, Mac의 언어를 따르거나 직접 선택할 수 있습니다.

## 설치

1. [Releases](https://github.com/ZhehanZhang/AutoPass/releases)에서 최신 `AutoPass-x.y.z.zip`을 **다운로드**하고 압축을 푼 다음 AutoPass를 응용 프로그램 폴더로 옮기세요. Apple의 서명 및 공증을 받았으며 macOS 14 이상의 Apple 실리콘과 Intel에서 실행됩니다.
2. **브라우저에 iCloud Passwords를 추가하세요.** 없으면 AutoPass가 설치하거나 켜도록 안내합니다. 도구 막대에 고정하는 것은 선택 사항입니다.
3. **AutoPass를 열고 요청이 나오면 손쉬운 사용을 허용하세요.** 이 권한이 없으면 AutoPass는 Apple의 코드 창을 보거나 입력할 수 없으며, 시스템 설정에서 켜면 자동으로 이어서 진행합니다.

이게 전부입니다. 브라우저를 열고 평소처럼 탐색하세요.

## 안전한가요?

AutoPass는 다음이 모두 충족될 때만 입력합니다.

- 코드가 Apple의 서명된 도우미에서 온 것이고, 입력되는 곳도 Apple의 iCloud Passwords 팝업뿐입니다.
- 브라우저가 신뢰한 것이며 코드 서명으로 확인되고 맨 앞에 있는 앱입니다.
- 입력을 멈춘 상태입니다.
- 선택 사항으로, Touch ID 또는 암호로 승인했을 것. 입력 전과 설정을 바꾸기 전에 이를 요구하도록 설정할 수 있습니다.

클립보드는 전혀 사용하지 않고, 코드는 저장하거나 기록하지 않으며, AutoPass에는 네트워크 코드가 없습니다. 자세한 내용은 [docs/SAFETY.md](../SAFETY.md)(영어)를 참고하세요.

## 언어

AutoPass는 Mac의 언어를 따르며, **설정 → 일반 → 언어**에서 직접 고를 수도 있습니다: English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano. 이 페이지도 위의 링크로 각 언어로 볼 수 있습니다.

## 개발자용

소스에서 빌드하는 방법, 안전 모델의 자세한 내용, 번역을 추가하거나 고치는 방법은 [docs/DEVELOPING.md](../DEVELOPING.md)와 [docs/SAFETY.md](../SAFETY.md)(영어)에 있습니다.

## 라이선스

AutoPass는 [GNU Affero 일반 공중 사용 허가서 3.0](../../LICENSE)에 따른 자유 소프트웨어입니다. 소스 코드: <https://github.com/ZhehanZhang/AutoPass>. 개발자의 다른 소식: <https://zhehanz.com>.
