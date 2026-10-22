# Skill "appunti" — note di sviluppo e troubleshooting

Percorso ufficiale della skill (solo Mac):
`/Users/gennarobasile/Desktop/buildspace/Venture-studio/claude-skills`

Questo file porta il contesto della skill. Se qualcosa non funziona, leggi prima qui.

## Cosa fa questa skill

Trasforma le slide PDF di una lezione universitaria (magistrale Data Science)
in appunti LaTeX studiabili: spiega ogni concetto in inglese, in tono semplice
e orientato all'esame (non una monografia tecnica), con definizioni in box,
esempi pratici, codice Python quando serve davvero, e le figure delle slide
più importanti incluse automaticamente. Vale per **qualsiasi corso**: ogni corso ha
la stessa struttura di cartelle (vedi sotto), creata da `scripts/new_course.sh`.

Sostituisce un processo manuale in due prompt che l'utente (Gennaro) faceva
prima a mano su Claude Chat: 1) chiedere l'indice dei macro-argomenti con i
numeri di slide, 2) chiedere la spiegazione di un gruppo di slide alla volta.
Ora è tutto automatico e parallelo.

## Struttura di un corso

```
<corso>/
└── Files/
    ├── main.tex
    ├── preamble.tex
    ├── Chapters/       ← N_nome_lezione.tex (numero senza zeri iniziali)
    └── Images/         ← L<N>/slide_NNN.png, più eventuale copertina
```

Dettagli e procedura di creazione: **`NEW_COURSE.md`**.

## Pipeline (vedi SKILL.md per il dettaglio completo)

0. **Corso nuovo?** `NEW_COURSE.md` → `scripts/new_course.sh` crea lo scheletro.
1. **Setup**: conta le pagine del PDF, estrae ogni slide come PNG in
   `Files/Images/L<N>/slide_NNN.png` (`extract_images.sh`).
2. **Indice**: legge tutto il PDF, produce `Files/Chapters/00-index.tex` (mostrato
   solo in chat, non finisce nel PDF) e `Files/Chapters/plan.json` con i chunk
   (10-15 slide ciascuno, tagliati sui confini dei macro-argomenti).
3. **Scrittura parallela**: un subagent per chunk (max 5 alla volta), ognuno
   scrive `Files/Chapters/tmp-NN.tex` leggendo solo le sue slide. Ogni subagent
   risponde con una sola riga di conferma, così il contesto della sessione
   principale resta piccolo — è per questo che la pipeline regge lezioni da
   100+ slide senza calare di qualità verso la fine.
4. **Merge**: tutti i `tmp-NN.tex` vengono concatenati in un unico file
   `Files/Chapters/<N_slug>.tex` (una `\section` + `\subsection`/`\subsubsection`
   per macro-argomento), i temporanei vengono cancellati.
5. **Assemblaggio e compilazione**: `assemble.sh` aggiorna `main.tex` con
   `\input{Chapters/<N_slug>.tex}` e compila con `latexmk -pdf`.

## Struttura dei file della skill

```
claude-skills/
├── SKILL.md                    — istruzioni della pipeline (letto da Claude Code)
├── NEW_COURSE.md               — come creare un corso nuovo e come sono strutturati i file
├── README.md                   — questo file
├── reference/
│   ├── style.md                — regole di stile LaTeX, VINCOLANTI, lette da ogni subagent
│   ├── preamble.tex            — preambolo dell'utente, copiato in ogni corso nuovo
│   └── main-template.tex       — template di main.tex ({{TITLE}}, {{AUTHOR}}, {{COVER}})
└── scripts/
    ├── new_course.sh           — crea lo scheletro di un corso e compila a vuoto
    ├── pdfpages.sh             — conta le pagine di un PDF (con fallback multipli)
    ├── extract_images.sh       — estrae le slide come PNG via pdftoppm
    └── assemble.sh             — aggiorna main.tex (ordine numerico) e compila con latexmk
```

## Il preambolo dell'utente

`reference/preamble.tex` è il preambolo di `text_mining`, copiato in ogni corso.
Punti critici che hanno causato bug (già corretti nello style.md):

- **`example`** è un `\newtheorem{example}{Example}[section]`, NON una
  tcolorbox. Quindi `\begin{example}{titolo}` con le GRAFFE non compila.
  Va `\begin{example}[titolo]` con le QUADRE (sintassi opzionale dei theorem).
- **`defbox`** è una tcolorbox con titolo protetto da `\mbox{#1}` — quindi
  virgole nel titolo sono ok.
- **`noteboxtitle`** è una tcolorbox con `title=#1` **NON protetto**. Una
  virgola nel titolo rompe `pgfkeys` con errore tipo
  `Package pgfkeys Error: I do not know the key '/tcb/...'`. Mai virgole nei
  titoli di `noteboxtitle`.
- **`\vs`** è una macro definita nel preambolo = `\vspace{0.2\baselineskip}`.
  Usarla al posto di `\vspace{0.2cm}` scritto a mano.
- `\graphicspath{{Images/}}` è già nel preambolo, quindi
  `\includegraphics{L3/slide_014}` funziona senza specificare il path.
- Il preambolo **non** contiene `\documentclass`: sta in `main.tex`.

## Bug già risolti (non ripeterli)

1. **Path con spazi** rompeva `extract_images.sh` quando usava `for f in $(ls ...)`.
   Risolto riscrivendo il rename via Python invece che bash puro.
2. **`assemble.sh` cercava ancora `sec-*.tex`** dopo che la pipeline è passata
   al file unico mergiato. Risolto: prende tutti i `.tex` in `Chapters/` tranne
   `00-index.tex` e `tmp-*.tex`.
3. **Indice manuale ridondante nel PDF**: resta solo `\tableofcontents`.
   `00-index.tex` serve solo per mostrare il piano in chat.
4. **Virgola in `noteboxtitle`** — vedi sopra.
5. **Ordine dei capitoli sbagliato**: l'ordine alfabetico dei nomi file non coincide
   con quello cronologico (e `10_` verrebbe prima di `2_`). Risolto: i capitoli si
   chiamano `N_nome.tex` e `assemble.sh` li ordina **numericamente** sul prefisso.
6. **Slide di lezioni diverse che si sovrascrivevano** (`slide_001.png` per ogni
   lezione). Risolto: una sottocartella `Images/L<N>/` per lezione.
7. **`assemble.sh` riscriveva titolo e sommario** di `main.tex`. Ora tocca solo gli
   `\input{Chapters/...}`; titolo, autore e copertina li decide `new_course.sh`.

## Dipendenze

```bash
command -v pdflatex   # LaTeX (MacTeX)
command -v latexmk    # compilazione automatica
command -v pdftoppm   # estrazione immagini: brew install poppler
command -v python3    # usato da tutti gli script
```

## Come si usa

1. Corso nuovo: in chat "crea il corso X in <cartella>" → l'agente legge `NEW_COURSE.md`
   e lancia `new_course.sh`.
2. `cd` nella cartella del corso.
3. In chat: `/appunti fammi gli appunti di "NOME_SLIDE.pdf" per NOME_CORSO`
4. Opzioni: `--from N --to M` per un range di slide, `--seq` per scrittura
   sequenziale invece che parallela (più lenta ma più coerente di stile —
   usarla se emerge disomogeneità tra sezioni scritte da subagent diversi).

## Se qualcosa non compila

1. Leggi `Files/build.log` (`assemble.sh` lo stampa già filtrato, ma il file completo è lì).
2. Errori tipici e fix:
   - `\begin{example}{...}` con graffe → cambia in `[...]`
   - `pgfkeys Error` su `noteboxtitle` → il titolo ha una virgola, riformulalo
   - `_` `%` `&` `#` non escapati nel testo normale → `\_` `\%` `\&` `\#`
   - `Undefined control sequence` su un comando che sembra esistere → verifica
     che sia davvero nel `Files/preamble.tex` di QUESTO corso
3. Correggi solo il file `Files/Chapters/<slug>.tex` (o la sezione responsabile),
   MAI `main.tex` a mano per i capitoli — gli `\input` li rigenera `assemble.sh`.
4. Rilancia `assemble.sh`. Se fallisce 3 volte, fermati e chiedi all'utente.

## Preferenze di stile dell'utente (riassunto — dettagli in reference/style.md)

- Tutto in **inglese**.
- Pubblico: magistrale Data Science, ma **non super tecnico** — capire i
  concetti e le formule ad alto livello, non fare l'esperto di statistica.
  Niente derivazioni complete se non aggiungono intuizione.
- Ogni formula: cosa rappresenta ogni simbolo + una riga di intuizione pratica.
- Esempi concreti con numeri reali, brevi, uno per concetto.
- Codice Python **solo** se il concetto è computazionale e il codice
  servirebbe davvero per un compito/progetto — mai forzato.
- Struttura: un file per lezione, `\section` (uno solo) → `\subsection` per
  macro-argomento → `\subsubsection` liberamente per dare ritmo.
- Figure dalle slide incluse automaticamente solo per diagrammi/schemi
  essenziali, non per slide di solo testo.
