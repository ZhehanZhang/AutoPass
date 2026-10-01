<p align="center">
  <img src="../icon.png" width="128" alt="Icono de AutoPass">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  Se acabó escribir a mano el código de 6 dígitos. Una utilidad segura para automatizar la vinculación de iCloud Passwords con navegadores de terceros en macOS.
</p>

<p align="center">
  <a href="../../README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <b>Español</b> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a> · <a href="README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="La ventana de AutoPass: estado, lista de navegadores con botones de vincular y pausar, y actividad reciente">
</p>

## Qué hace

La extensión iCloud Passwords de Apple para Chrome, Edge, Vivaldi, Brave, Arc y otros navegadores se vincula con tu Mac mostrando un código de 6 dígitos que tienes que volver a escribir. Ocurre tras cada reinicio del navegador y cada pocas horas. AutoPass escribe el código por ti, con comprobaciones que lo hacen casi tan seguro como hacerlo a mano.

- **Empieza solo.** Aproximadamente un segundo después de que empieces a navegar y hagas una pausa, AutoPass abre iCloud Passwords, escribe el código y vuelve a cerrar la ventana emergente.
- **Funciona con varios navegadores a la vez**, cada uno con sus propios botones de vincular y pausar. Añade cualquier navegador que admita el ayudante de Apple.
- **Rápido y discreto.** La ventana del código de Apple está en pantalla solo unos milisegundos, y AutoPass retoma donde lo dejó si escribes o cambias de ventana entretanto.
- **Vive en la barra de menús.** El icono se ve sólido cuando estás vinculado, así que lo notas de un vistazo.
- **En 11 idiomas**, siguiendo a tu Mac o a tu elección.

## Instalación

1. **Descarga** el último `AutoPass-x.y.z.zip` desde [Releases](https://github.com/ZhehanZhang/AutoPass/releases), descomprímelo y mueve AutoPass a Aplicaciones. Está firmado y notarizado por Apple y funciona en macOS 14 o posterior, en Apple silicon e Intel.
2. **Añade iCloud Passwords a tu navegador.** Si no está, AutoPass se ofrece a instalarlo o activarlo por ti. Fijarlo en la barra de herramientas es opcional.
3. **Abre AutoPass y permite Accesibilidad** cuando lo pida. Sin eso, AutoPass no puede ver la ventana del código de Apple ni escribir, y continúa solo en cuanto lo actives en Ajustes del Sistema.

Eso es todo. Abre tu navegador y sigue navegando.

## ¿Es seguro?

AutoPass solo escribe cuando se cumplen todas estas condiciones:

- El código procede del ayudante firmado por Apple y solo se escribe en la ventana emergente de iCloud Passwords de Apple.
- El navegador es uno de tu confianza, reconocido por su firma de código, y es la app en primer plano.
- Has dejado de escribir.
- Opcionalmente, lo aprobaste con Touch ID o tu contraseña. Puedes exigirlo antes de escribir y antes de cambiar ajustes.

Nunca se usa el portapapeles, los códigos nunca se guardan ni se registran, y AutoPass no tiene código de red. Los detalles están en [docs/SAFETY.md](../SAFETY.md) (en inglés).

## Idiomas

AutoPass sigue el idioma de tu Mac, o puedes elegir uno en **Ajustes → General → Idioma**: English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano. Esta página está disponible en todos ellos con los enlaces de arriba.

## Para desarrolladores

La compilación desde el código fuente, el modelo de seguridad en detalle y cómo añadir o corregir una traducción están en [docs/DEVELOPING.md](../DEVELOPING.md) y [docs/SAFETY.md](../SAFETY.md) (en inglés).

## Licencia

AutoPass es software libre bajo la [Licencia Pública General de Affero de GNU 3.0](../../LICENSE). Código fuente: <https://github.com/ZhehanZhang/AutoPass>. Más del autor: <https://zhehanz.com>.
