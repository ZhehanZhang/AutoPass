<p align="center">
  <img src="../icon.png" width="128" alt="Ícone do AutoPass">
</p>

<h1 align="center">AutoPass</h1>

<p align="center">
  Chega de digitar o código de 6 dígitos manualmente. Um utilitário seguro para automatizar o pareamento do iCloud Passwords com navegadores de terceiros no macOS.
</p>

<p align="center">
  <a href="../../README.md">English</a> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <b>Português (Brasil)</b> · <a href="README.ru.md">Русский</a> · <a href="README.it.md">Italiano</a>
</p>

<p align="center">
  <img src="../screenshot.png" width="820" alt="A janela do AutoPass: status, lista de navegadores com botões de parear e pausar e atividade recente">
</p>

## O que ele faz

A extensão iCloud Passwords da Apple para Chrome, Edge, Vivaldi, Brave, Arc e outros navegadores é pareada com o seu Mac mostrando um código de 6 dígitos que você precisa digitar de novo. Isso acontece a cada reinício do navegador e a cada poucas horas. O AutoPass digita o código por você, com verificações que o tornam quase tão seguro quanto fazer isso à mão.

- **Começa sozinho.** Cerca de um segundo depois que você começa a navegar e faz uma pausa, o AutoPass abre o iCloud Passwords, digita o código e fecha o pop-up de novo.
- **Funciona com vários navegadores ao mesmo tempo**, cada um com seus próprios botões de parear e pausar. Adicione qualquer navegador compatível com o assistente da Apple.
- **Rápido e discreto.** A janela do código da Apple fica na tela por apenas alguns milissegundos, e o AutoPass retoma de onde parou se você digitar ou trocar de janela nesse meio-tempo.
- **Fica na barra de menus.** O ícone fica sólido quando você está pareado, então dá para saber num relance.
- **Em 11 idiomas**, seguindo o seu Mac ou a sua escolha.

## Instalação

1. **Baixe** o `AutoPass-x.y.z.zip` mais recente em [Releases](https://github.com/ZhehanZhang/AutoPass/releases), descompacte e mova o AutoPass para Aplicativos. Ele é assinado e notarizado pela Apple e roda no macOS 14 ou posterior, em Apple silicon e Intel.
2. **Adicione o iCloud Passwords ao seu navegador.** Se ele não estiver lá, o AutoPass oferece instalá-lo ou ativá-lo para você. Fixá-lo na barra de ferramentas é opcional.
3. **Abra o AutoPass e permita a Acessibilidade** quando ele pedir. Sem ela, o AutoPass não consegue ver a janela do código da Apple nem digitar, e ele continua sozinho assim que você a ativar em Ajustes do Sistema.

Só isso. Abra o navegador e continue navegando normalmente.

## É seguro?

O AutoPass só digita quando todas estas condições são verdadeiras:

- O código vem do assistente assinado pela própria Apple e vai apenas para o pop-up do iCloud Passwords da Apple.
- O navegador é um em que você confia, reconhecido pela assinatura de código, e é o app em primeiro plano.
- Você parou de digitar.
- Opcionalmente, você aprovou com Touch ID ou sua senha. Dá para exigir isso antes de digitar e antes de alterar ajustes.

A área de transferência nunca é usada, os códigos nunca são armazenados nem registrados, e o AutoPass não tem código de rede. Os detalhes estão em [docs/SAFETY.md](../SAFETY.md) (em inglês).

## Idiomas

O AutoPass segue o idioma do seu Mac, ou você pode escolher um em **Ajustes → Geral → Idioma**: English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, Português (Brasil), Русский, Italiano. Esta página está disponível em cada um deles pelos links no topo.

## Para desenvolvedores

Compilar a partir do código-fonte, o modelo de segurança em detalhes e como adicionar ou corrigir uma tradução estão em [docs/DEVELOPING.md](../DEVELOPING.md) e [docs/SAFETY.md](../SAFETY.md) (em inglês).

## Licença

O AutoPass é software livre sob a [Licença Pública Geral Affero GNU 3.0](../../LICENSE). Código-fonte: <https://github.com/ZhehanZhang/AutoPass>. Mais do autor: <https://zhehanz.com>.
