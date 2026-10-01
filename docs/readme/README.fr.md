<p align="center">
  <img src="../icon.png" width="128" alt="Icône d'AutoPass">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  Fini la saisie manuelle du code à 6 chiffres. Un utilitaire sécurisé pour automatiser l'association d'iCloud Passwords avec les navigateurs tiers sur macOS.
</p>

<p align="center">
  <a href="../../README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.es.md">Español</a> · <b>Français</b> · <a href="README.de.md">Deutsch</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a> · <a href="README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="La fenêtre d'AutoPass : état, liste des navigateurs avec boutons d'association et de pause, et activité récente">
</p>

## Ce qu'il fait

L'extension iCloud Passwords d'Apple pour Chrome, Edge, Vivaldi, Brave, Arc et d'autres navigateurs s'associe à votre Mac en affichant un code à 6 chiffres que vous devez ressaisir. Cela arrive après chaque redémarrage du navigateur et toutes les quelques heures. AutoPass saisit le code à votre place, avec des vérifications qui le rendent presque aussi sûr que de le faire à la main.

- **Démarre tout seul.** Environ une seconde après que vous avez commencé à naviguer et fait une pause, AutoPass ouvre iCloud Passwords, saisit le code et referme la fenêtre contextuelle.
- **Fonctionne avec plusieurs navigateurs à la fois**, chacun avec ses propres boutons d'association et de pause. Ajoutez n'importe quel navigateur pris en charge par l'assistant d'Apple.
- **Rapide et discret.** La fenêtre du code d'Apple n'est à l'écran que quelques millisecondes, et AutoPass reprend là où il s'était arrêté si vous tapez ou changez de fenêtre entre-temps.
- **Vit dans la barre des menus.** L'icône est pleine quand vous êtes associé, pour le voir d'un coup d'œil.
- **En 11 langues**, selon votre Mac ou votre choix.

## Installation

1. **Téléchargez** le dernier `AutoPass-x.y.z.zip` depuis [Releases](https://github.com/ZhehanZhang/AutoPass/releases), décompressez-le et déplacez AutoPass dans Applications. Il est signé et notarisé par Apple, et fonctionne sous macOS 14 ou version ultérieure, sur Apple silicon comme sur Intel.
2. **Ajoutez iCloud Passwords à votre navigateur.** S'il n'y est pas, AutoPass propose de l'installer ou de l'activer pour vous. L'épingler à la barre d'outils est facultatif.
3. **Ouvrez AutoPass et autorisez l'accessibilité** quand il le demande. Sans cela, AutoPass ne peut ni voir la fenêtre du code d'Apple ni saisir, et il reprend tout seul dès que vous l'activez dans Réglages Système.

C'est tout. Lancez votre navigateur et naviguez comme d'habitude.

## Est-ce sûr ?

AutoPass ne saisit le code que si toutes ces conditions sont réunies :

- Le code provient de l'assistant signé d'Apple et n'est saisi que dans la fenêtre contextuelle iCloud Passwords d'Apple.
- Le navigateur est l'un de ceux auxquels vous faites confiance, reconnu par sa signature de code, et c'est l'app au premier plan.
- Vous avez arrêté de taper.
- Facultativement, vous avez approuvé avec Touch ID ou votre mot de passe. Vous pouvez l'exiger avant la saisie et avant de modifier les réglages.

Le presse-papiers n'est jamais utilisé, les codes ne sont jamais stockés ni journalisés, et AutoPass n'a aucun code réseau. Les détails sont dans [docs/SAFETY.md](../SAFETY.md) (en anglais).

## Langues

AutoPass suit la langue de votre Mac, ou vous pouvez en choisir une dans **Réglages → Général → Langue** : English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano. Cette page est disponible dans chacune d'elles grâce aux liens en haut.

## Pour les développeurs

La compilation depuis les sources, le modèle de sécurité en détail et la manière d'ajouter ou de corriger une traduction se trouvent dans [docs/DEVELOPING.md](../DEVELOPING.md) et [docs/SAFETY.md](../SAFETY.md) (en anglais).

## Licence

AutoPass est un logiciel libre sous [licence publique générale Affero GNU 3.0](../../LICENSE). Code source : <https://github.com/ZhehanZhang/AutoPass>. Plus de l'auteur : <https://zhehanz.com>.
