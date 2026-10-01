<p align="center">
  <img src="../icon.png" width="128" alt="AutoPass-Symbol">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  Schluss mit dem manuellen Eintippen des 6-stelligen Codes. Ein sicheres Hilfsprogramm, das die Kopplung von iCloud Passwords mit Drittanbieter-Browsern unter macOS automatisiert.
</p>

<p align="center">
  <a href="../../README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <b>Deutsch</b> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a> · <a href="README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="Das AutoPass-Fenster: Status, Browser-Liste mit Koppeln- und Pause-Tasten und letzte Aktivität">
</p>

## Was es macht

Die iCloud-Passwords-Erweiterung von Apple für Chrome, Edge, Vivaldi, Brave, Arc und andere Browser koppelt sich mit deinem Mac, indem sie einen 6-stelligen Code anzeigt, den du erneut eintippen musst. Das passiert nach jedem Neustart des Browsers und alle paar Stunden. AutoPass tippt den Code für dich ein – mit Prüfungen, die es nahezu so sicher machen wie die Eingabe von Hand.

- **Startet von selbst.** Etwa eine Sekunde, nachdem du angefangen hast zu surfen und pausierst, öffnet AutoPass iCloud Passwords, tippt den Code ein und schließt das Popup wieder.
- **Funktioniert mit mehreren Browsern gleichzeitig**, jeder mit eigenen Koppeln- und Pause-Tasten. Füge jeden Browser hinzu, den Apples Hilfsprogramm unterstützt.
- **Schnell und unauffällig.** Apples Code-Fenster ist nur wenige Millisekunden zu sehen, und AutoPass macht dort weiter, wo es aufgehört hat, falls du in der Zwischenzeit tippst oder das Fenster wechselst.
- **Lebt in der Menüleiste.** Das Symbol ist durchgehend gefüllt, wenn du gekoppelt bist – so siehst du es auf einen Blick.
- **In 11 Sprachen**, passend zu deinem Mac oder nach deiner Wahl.

## Installation

1. **Lade** die neueste `AutoPass-x.y.z.zip` von [Releases](https://github.com/ZhehanZhang/AutoPass/releases) **herunter**, entpacke sie und verschiebe AutoPass in „Programme“. Die App ist von Apple signiert und notarisiert und läuft ab macOS 14, auf Apple Silicon und Intel.
2. **Füge iCloud Passwords deinem Browser hinzu.** Ist es nicht vorhanden, bietet AutoPass an, es für dich zu installieren oder zu aktivieren. Es an die Symbolleiste anzuheften ist optional.
3. **Öffne AutoPass und erlaube die Bedienungshilfen**, wenn es danach fragt. Ohne sie kann AutoPass weder Apples Code-Fenster sehen noch tippen, und es macht von selbst weiter, sobald du es in den Systemeinstellungen einschaltest.

Das war's. Starte deinen Browser und surfe einfach weiter.

## Ist das sicher?

AutoPass tippt nur, wenn alle diese Punkte erfüllt sind:

- Der Code stammt vom signierten Hilfsprogramm von Apple und wird nur in das iCloud-Passwords-Popup von Apple eingetippt.
- Der Browser gehört zu denen, denen du vertraust, wird an seiner Code-Signatur erkannt und ist die App im Vordergrund.
- Du tippst nicht mehr.
- Optional hast du mit Touch ID oder deinem Passwort bestätigt. Das lässt sich vor dem Eintippen und vor dem Ändern von Einstellungen verlangen.

Die Zwischenablage wird nie benutzt, Codes werden nie gespeichert oder protokolliert, und AutoPass enthält keinen Netzwerkcode. Details stehen in [docs/SAFETY.md](../SAFETY.md) (auf Englisch).

## Sprachen

AutoPass folgt der Sprache deines Macs, oder du wählst unter **Einstellungen → Allgemein → Sprache** eine aus: English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano. Diese Seite gibt es in jeder davon über die Links oben.

## Für Entwickler

Das Bauen aus dem Quellcode, das Sicherheitsmodell im Detail und wie man eine Übersetzung hinzufügt oder korrigiert, steht in [docs/DEVELOPING.md](../DEVELOPING.md) und [docs/SAFETY.md](../SAFETY.md) (auf Englisch).

## Lizenz

AutoPass ist freie Software unter der [GNU Affero General Public License 3.0](../../LICENSE). Quellcode: <https://github.com/ZhehanZhang/AutoPass>. Mehr vom Autor: <https://zhehanz.com>.
