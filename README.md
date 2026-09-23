# Skill "appunti" — note di sviluppo e troubleshooting

Questo file esiste per portare il contesto della skill da una macchina all'altra
(Mac ↔ portatile Windows/WSL). Se stai leggendo questo su una macchina nuova e
qualcosa non funziona, leggi prima qui.

## Cosa fa questa skill

Trasforma le slide PDF di una lezione universitaria (magistrale Data Science)
in appunti LaTeX studiabili: spiega ogni concetto in inglese, in tono semplice
e orientato all'esame (non una monografia tecnica), con definizioni in box,
esempi pratici, codice Python quando serve davvero, e le figure delle slide
più importanti incluse automaticamente.

Sostituisce un processo manuale in due prompt che l'utente (Gennaro) faceva
prima a mano su Claude Chat: 1) chiedere l'indice dei macro-argomenti con i
numeri di slide, 2) chiedere la spiegazione di un gruppo di slide alla volta.
Ora è tutto automatico e parallelo.

## Pipeline (vedi SKILL.md per il dettaglio completo)

1. **Setup**: conta le pagine del PDF, rileva/copia il `preamble.tex`, estrae
   ogni slide come PNG in `Images/slide_NNN.png` (`extract_images.sh`).
2. **Indice**: legge tutto il PDF, produce `chapters/00-index.tex` (mostrato
   solo in chat, non finisce nel PDF) e `chapters/plan.json` con i chunk
   (10-15 slide ciascuno, tagliati sui confini dei macro-argomenti).
3. **Scrittura parallela**: un subagent per chunk (max 5 alla volta), ognuno
   scrive `chapters/tmp-NN.tex` leggendo solo le sue slide. Ogni subagent
   risponde con una sola riga di conferma, così il contesto della sessione
   principale resta piccolo — è per questo che la pipeline regge lezioni da
   100+ slide senza calare di qualità verso la fine.
4. **Merge**: tutti i `tmp-NN.tex` vengono concatenati in un unico file
   `chapters/<slug>.tex` (una `\section` + `\subsection`/`\subsubsection`
   per macro-argomento), i temporanei vengono cancellati.
5. **Assemblaggio e compilazione**: `assemble.sh` aggiorna `main.tex` con
   `\input{chapters/<slug>}` e compila con `latexmk -pdf`.

## Struttura dei file della skill

```
~/.claude/skills/appunti/
├── SKILL.md                    — istruzioni della pipeline (letto da Claude Code)
├── README.md                   — questo file
├── reference/
│   ├── style.md                — regole di stile LaTeX, VINCOLANTI, lette da ogni subagent
│   └── preamble.tex             — preambolo di default (usato SOLO se il progetto non ha già il suo)
└── scripts/
    ├── pdfpages.sh              — conta le pagine di un PDF (con fallback multipli)
    ├── extract_images.sh        — estrae le slide come PNG via pdftoppm
    └── assemble.sh               — aggiorna main.tex e compila con latexmk
```

## Il preambolo reale dell'utente

L'utente ha un `preamble.tex` **suo**, dentro ogni cartella di corso (es.
`Renforcment Learning/files/preamble.tex`), diverso da quello di default della
skill. Punti critici del suo preambolo che hanno causato bug (già corretti
nello style.md, ma tienili a mente se ne aggiunge di nuovi):

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
- `\graphicspath{{Images/}}` è già nel preambolo, quindi `\includegraphics{slide_014}`
  funziona senza specificare il path.

## Bug già risolti (non ripeterli)

1. **Path con spazi** (`"Renforcment Learning"` ha uno spazio) rompeva
   `extract_images.sh` quando usava `for f in $(ls ...)`. Risolto riscrivendo
   il rename via Python invece che bash puro.
2. **`assemble.sh` cercava ancora `sec-*.tex`** dopo che la pipeline è passata
   al file unico mergiato (`<slug>.tex`). Risolto: ora prende tutti i `.tex`
   in `chapters/` tranne `00-index.tex` e `tmp-*.tex`.
3. **Indice manuale ridondante nel PDF**: all'inizio la skill inseriva sia un
   indice scritto a mano (da `00-index.tex`) sia `\tableofcontents` — doppio
   e il primo andava aggiornato a mano. Rimosso l'inserimento dell'indice
   manuale nel PDF: resta solo `\tableofcontents` (cresce da solo aggiungendo
   lezioni). `00-index.tex` continua a essere generato ma solo per mostrare
   il piano in chat prima di lanciare i subagent.
4. **Virgola in `noteboxtitle`** — vedi sopra.
5. **Ordine dei capitoli sbagliato con più lezioni nello stesso `main.tex`**:
   `assemble.sh` ordina i file `chapters/*.tex` alfabeticamente. Se lo SLUG non ha un
   prefisso numerico, l'ordine alfabetico può non coincidere con l'ordine cronologico
   (es. "probability-and-inference" < "prolusion" alfabeticamente, ma Prolusion è la
   lezione 1 e Probability and Inference la lezione 2). Fix: lo SLUG ora mantiene
   SEMPRE il numero iniziale del file PDF originale (`01-prolusion.tex`,
   `02-probability-and-inference.tex`, ...), così l'ordine alfabetico = ordine
   cronologico. Se rinomini a mano un file in `chapters/`, mantieni il prefisso a due
   cifre.

## Setup multi-macchina (Mac ↔ Windows/WSL)

La skill vive in un repo git privato: `Buildspace081/claude-skills`
(dentro c'è solo la cartella `appunti/`, che va clonata/copiata dentro
`~/.claude/skills/appunti/`).

**IMPORTANTE su Windows**: Claude Code lì gira dentro **WSL** (Ubuntu). Tutto
deve stare nel filesystem Linux di WSL (`/home/tuonome/...`), MAI in quello
di Windows (`C:\Users\...`) — sono due filesystem separati e Claude Code
dentro WSL non vede comodamente `C:\Users\...` (serve passare per `/mnt/c/...`,
lento e da evitare). Se qualcuno apre PowerShell per errore e clona lì, il
clone "funziona" ma finisce nel posto sbagliato — va rifatto da un terminale
Ubuntu/WSL vero.

Sync tra le due macchine:
```bash
# lato che ha modificato SKILL.md o style.md:
cd ~/.claude/skills/appunti
git add . && git commit -m "..." && git push

# lato che deve aggiornare:
cd ~/.claude/skills/appunti
git pull
```

### Dipendenze richieste (entrambe le macchine)

```bash
command -v pdflatex   # LaTeX
command -v latexmk    # compilazione automatica
command -v pdftoppm   # estrazione immagini (pacchetto poppler / poppler-utils)
command -v python3    # usato da tutti gli script per parsing/merge robusto
```

Su Windows/WSL (Ubuntu):
```bash
sudo apt update
sudo apt install -y poppler-utils python3 texlive-full
```

Su Mac: di solito già presenti se si ha una distribuzione TeX (MacTeX) e
`brew install poppler`.

## Come si usa (identico su entrambe le macchine)

1. `cd` nella cartella del corso (deve avere `preamble.tex` e idealmente
   `main.tex` con un `\input{}` vuoto, e `chapters/` — se mancano la skill li
   crea/gestisce da sola).
2. In chat: `/appunti fammi gli appunti di "NOME_SLIDE.pdf" per NOME_CORSO`
3. Opzioni: `--from N --to M` per un range di slide, `--seq` per scrittura
   sequenziale invece che parallela (più lenta ma più coerente di stile —
   usarla se emerge disomogeneità tra sezioni scritte da subagent diversi).

## Se qualcosa non compila

1. Leggi `build.log` nella cartella del corso (`assemble.sh` lo stampa già
   filtrato, ma il file completo è lì).
2. Errori tipici e fix:
   - `\begin{example}{...}` con graffe → cambia in `[...]`
   - `pgfkeys Error` su `noteboxtitle` → il titolo ha una virgola, riformulalo
   - `_` `%` `&` `#` non escapati nel testo normale → `\_` `\%` `\&` `\#`
   - `Undefined control sequence` su un comando che sembra esistere → verifica
     che sia davvero nel `preamble.tex` di QUESTO corso (ogni corso potrebbe
     avere preamboli leggermente diversi)
3. Correggi solo il file `chapters/<slug>.tex` (o la sezione responsabile),
   MAI `main.tex` a mano per il contenuto — viene rigenerato da `assemble.sh`
   ogni volta.
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
