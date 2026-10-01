<p align="center">
  <img src="../icon.png" width="128" alt="Icona di AutoPass">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  Basta digitare a mano il codice a 6 cifre. Un'utility sicura per automatizzare l'abbinamento di iCloud Passwords con i browser di terze parti su macOS.
</p>

<p align="center">
  <a href="../../README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a> · <b>Italiano</b>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="La finestra di AutoPass: stato, elenco dei browser con pulsanti per abbinare e mettere in pausa, attività recente">
</p>

## Cosa fa

L'estensione iCloud Passwords di Apple per Chrome, Edge, Vivaldi, Brave, Arc e altri browser si abbina al tuo Mac mostrando un codice a 6 cifre che devi ridigitare. Succede a ogni riavvio del browser e ogni poche ore. AutoPass digita il codice per te, con controlli che lo rendono sicuro quasi quanto farlo a mano.

- **Parte da solo.** Circa un secondo dopo che hai iniziato a navigare e fatto una pausa, AutoPass apre iCloud Passwords, digita il codice e richiude il popup.
- **Funziona con più browser insieme**, ciascuno con i propri pulsanti per abbinare e mettere in pausa. Aggiungi qualsiasi browser supportato dall'assistente di Apple.
- **Veloce e discreto.** La finestra del codice di Apple resta sullo schermo solo per pochi millisecondi, e AutoPass riprende da dove si era fermato se nel frattempo digiti o cambi finestra.
- **Vive nella barra dei menu.** L'icona è piena quando sei abbinato, così lo capisci a colpo d'occhio.
- **In 11 lingue**, seguendo il tuo Mac o la tua scelta.

## Installazione

1. **Scarica** l'ultimo `AutoPass-x.y.z.zip` da [Releases](https://github.com/ZhehanZhang/AutoPass/releases), decomprimilo e sposta AutoPass in Applicazioni. È firmato e notarizzato da Apple e funziona con macOS 14 o successivo, su Apple silicon e Intel.
2. **Aggiungi iCloud Passwords al tuo browser.** Se non c'è, AutoPass si offre di installarlo o attivarlo per te. Fissarlo alla barra degli strumenti è facoltativo.
3. **Apri AutoPass e consenti Accessibilità** quando te lo chiede. Senza, AutoPass non può vedere la finestra del codice di Apple né digitare, e prosegue da solo appena la attivi in Impostazioni di Sistema.

Ecco fatto. Avvia il browser e continua a navigare.

## È sicuro?

AutoPass digita solo quando sono vere tutte queste condizioni:

- Il codice proviene dall'assistente firmato da Apple e viene digitato solo nel popup di iCloud Passwords di Apple.
- Il browser è uno di cui ti fidi, riconosciuto dalla firma del codice, ed è l'app in primo piano.
- Hai smesso di digitare.
- Facoltativamente, hai approvato con Touch ID o con la password. Puoi richiederlo prima di digitare e prima di modificare le impostazioni.

Gli appunti non vengono mai usati, i codici non vengono mai salvati né registrati, e AutoPass non ha codice di rete. I dettagli sono in [docs/SAFETY.md](../SAFETY.md) (in inglese).

## Lingue

AutoPass segue la lingua del tuo Mac, oppure puoi sceglierne una in **Impostazioni → Generali → Lingua**: English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano. Questa pagina è disponibile in ognuna di esse con i link in alto.

## Per sviluppatori

La compilazione dai sorgenti, il modello di sicurezza nel dettaglio e come aggiungere o correggere una traduzione sono in [docs/DEVELOPING.md](../DEVELOPING.md) e [docs/SAFETY.md](../SAFETY.md) (in inglese).

## Licenza

AutoPass è software libero con licenza [GNU Affero General Public License 3.0](../../LICENSE). Codice sorgente: <https://github.com/ZhehanZhang/AutoPass>. Altro dall'autore: <https://zhehanz.com>.
