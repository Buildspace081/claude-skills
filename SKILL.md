---
name: appunti
description: Trasforma le slide PDF di una lezione universitaria in appunti completi in LaTeX (in inglese), in un unico file Files/Chapters/<N_slug>.tex con sezioni e sottosezioni, aggiornando Files/main.tex. Funziona per qualsiasi corso. Usare quando l'utente indica un PDF di slide e chiede appunti, note, riassunto in .tex, oppure invoca /appunti. Per creare un corso nuovo leggi prima NEW_COURSE.md.
---

# Appunti LaTeX da slide universitarie

Pipeline: **indice → immagini → scrittura parallela → merge in file unico → compilazione**.
Non saltare fasi. Non chiedere conferme: l'utente vuole un `.tex` + `.pdf` finiti.

## Percorsi

`SKILL_DIR` = `/Users/gennarobasile/Desktop/buildspace/Venture-studio/claude-skills`
(percorso ufficiale, solo Mac). Tutti gli script e i file di riferimento stanno lì.

Struttura di ogni corso (la cartella del corso è la cwd, `COURSE`):
```
<COURSE>/
└── Files/
    ├── main.tex
    ├── preamble.tex
    ├── Chapters/      ← un .tex per lezione: N_nome_lezione.tex
    └── Images/        ← slide_NNN.png + eventuale copertina
```
Se `Files/main.tex` non esiste, il corso non è stato creato: **leggi `NEW_COURSE.md`**
ed esegui prima quella procedura, poi torna qui.

## Input

- `PDF` — percorso delle slide. Se non indicato, cerca PDF nel cwd; se più di uno, chiedi.
- `ESAME` — nome del corso. Se non indicato, deducilo dalla cartella del corso e comunicalo.
- `RANGE` opzionale — `--from N --to M` per una parte delle slide.
- `--seq` opzionale — scrittura sequenziale (no subagent, vedi Fase 3).

Deriva:
- `N` = numero della lezione. Preferisci il numero iniziale nel nome del PDF
  ("03 Transformers.pdf" → 3). Se manca, deducilo da `ls Files/Chapters/` (ultimo
  numero + 1) e chiedi all'utente solo se resta ambiguo.
- `SLUG` = `N_nome_lezione`: numero intero **senza zeri iniziali** + underscore +
  titolo in minuscolo con underscore (es. "Intro to the Course" → `1_intro_to_the_course`).
  `assemble.sh` ordina i capitoli sul numero, quindi `10_` viene dopo `9_`.
- `OUTFILE` = `Files/Chapters/<SLUG>.tex` — il file finale di questa lezione.
- `MAIN_TEX` = `Files/main.tex`.

---

## Fase 0 — Setup

```bash
bash SKILL_DIR/scripts/pdfpages.sh "<PDF>"
mkdir -p Files/Chapters Files/Images
```

Il preambolo è `Files/preamble.tex` (creato da `new_course.sh`). Non modificarlo e non
sostituirlo. Se manca, il corso non è stato creato: vedi `NEW_COURSE.md`.

**Estrazione immagini** (richiede `pdftoppm`: `brew install poppler`):
```bash
bash SKILL_DIR/scripts/extract_images.sh "<PDF>" "Files/Images/L<N>" <FROM> <TO>
```
Idempotente: salta se le immagini esistono già. Ogni lezione ha la **sua sottocartella**
`Images/L<N>/` perché i file si chiamano tutti `slide_NNN.png` e altrimenti lezioni
diverse si sovrascriverebbero. Nel LaTeX: `\includegraphics{L<N>/slide_NNN}`
(`\graphicspath{{Images/}}` nel preambolo risolve il resto).

---

## Fase 1 — Indice e piano

Leggi **tutto** il PDF (tool Read, `pages`, max 20 per chiamata) e produci:

**`Files/Chapters/00-index.tex`** — panoramica in `\begin{itemize}...\end{itemize}`, **solo per
mostrarla all'utente in chat**. Non finisce mai nel PDF: `\tableofcontents` in `main.tex`
genera già l'elenco dei capitoli, e `assemble.sh` ignora questo file.
```latex
\begin{itemize}
  \item \textbf{Markov Decision Processes} \textit{(slides 3--14)}
  \begin{itemize}
    \item States, actions, rewards \textit{(slides 3--7)}
    \item Bellman equations \textit{(slides 8--14)}
  \end{itemize}
\end{itemize}
```

**`Files/Chapters/plan.json`** — piano dei chunk per i subagent:
```json
[{"n":1,"title":"Markov Decision Processes","from":3,"to":14},
 {"n":2,"title":"Dynamic Programming","from":15,"to":28}]
```

Regole di chunking:
- 10–15 slide per chunk, mai più di 20
- Confini = confini macro-argomento, mai a metà di un ragionamento
- Macro > 20 slide → "Part 1" / "Part 2"
- Nessun buco nel range (escluse slide di soli titoli/copertine, saltate esplicitamente)

Mostra l'indice e il piano all'utente in forma compatta.

---

## Fase 2 — Stile

Leggi `SKILL_DIR/reference/style.md` prima di scrivere qualsiasi LaTeX.
Punti critici da tenere a mente per ogni subagent:
- Struttura: `\section{}` una sola volta (solo il primo chunk), poi `\subsection{}` e
  `\subsubsection{}` per tutto il resto
- `\begin{example}[titolo]` — parentesi quadre, **mai graffe**
- `\vs` invece di `\vspace{0.2cm}`
- Tono semplice, intuitivo, exam-oriented — non una monografia

---

## Fase 3 — Scrittura parallela in file temporanei

Ogni chunk del piano produce un file temporaneo `Files/Chapters/tmp-NN.tex` (NN a due cifre).

**Resume**: salta i chunk il cui `tmp-NN.tex` esiste già ed è non vuoto.

**Modalità parallela (default).** Ondate di max 5 subagent contemporanei.
Prompt per ogni subagent (sostituisci i segnaposto):

---
> Leggi `SKILL_DIR/reference/style.md` e rispettalo alla lettera.
>
> Leggi il PDF `<PDF>` pagine `<from>`-`<to>` (tool Read, parametro `pages`).
>
> Scrivi appunti in **inglese**, in LaTeX, per il corso **`<ESAME>`** (magistrale Data Science).
> Copri **ogni** slide da `<from>` a `<to>` senza saltarne nessuna.
>
> **Tono**: semplice e accessibile, non super tecnico. Spiega i concetti ad alto livello.
> Per ogni formula: spiega cosa significa ogni simbolo e dai un'intuizione in una riga.
> Aggiungi esempi concreti con numeri reali. Aggiungi codice Python solo se il concetto
> è computazionale e il codice sarebbe utile per un compito/progetto (≤ 20 righe).
>
> **Struttura**:
> - Chunk `<n>` di `<tot>` — contesto: gli altri chunk sono: `<elenco titoli>`.
> - Se questo è il chunk **1**: inizia con `\section{<titolo lezione>}\label{sec:<slug>}`,
>   poi `\subsection{<titolo chunk>}`.
> - Se questo è il chunk **2+**: inizia direttamente con `\subsection{<titolo chunk>}`.
> - Usa `\subsubsection{}` liberamente per spezzettare e dare ritmo.
> - Non ripetere teoria delle altre sezioni: rimandaci con `\ref{}`.
>
> **Figure**: per slide prevalentemente diagramma/schema/flowchart (non testo/formule),
> includi l'immagine estratta:
> ```latex
> \begin{figure}[H]
>     \centering
>     \includegraphics[width=0.85\textwidth]{L<N>/slide_<NNN>}
>     \caption{Descrizione in inglese.}
>     \captionsetup{font=footnotesize}
> \end{figure}
> ```
> `width=0.85\textwidth` per diagrammi a piena pagina, `width=0.60\textwidth` per figure piccole.
>
> Scrivi il risultato con il tool Write in `Files/Chapters/tmp-<NN>.tex`.
> Non produrre preambolo, non `\begin{document}`.
> Risposta finale: solo `OK tmp-NN, slides <from>-<to>, <righe> righe, <N_fig> figure`.
---

**Modalità sequenziale (`--seq`)**: stessa logica ma la fai tu, un chunk alla volta.
Più lenta, più coerente nello stile — consigliala se l'utente segnala disomogeneità.

---

## Fase 4 — Merge in file unico

Dopo che tutti i subagent hanno completato:

```bash
python3 - "Files/Chapters" "<SLUG>" <<'PY'
import os, glob, sys

chapters = sys.argv[1]  # "Files/Chapters"
slug     = sys.argv[2]  # es. "3_transformers"

tmp_files = sorted(glob.glob(os.path.join(chapters, 'tmp-*.tex')))
out_path  = os.path.join(chapters, f'{slug}.tex')

with open(out_path, 'w') as out:
    out.write('%!TEX root = ../main.tex\n\n')
    for f in tmp_files:
        with open(f) as inp:
            out.write(inp.read())
            out.write('\n')

for f in tmp_files:
    os.remove(f)

print(f'OK: {len(tmp_files)} chunk → {out_path}')
PY
```

Poi assembla e compila:
```bash
bash SKILL_DIR/scripts/assemble.sh "Files/main.tex"
```

`assemble.sh` prende tutti i `Files/Chapters/*.tex` di contenuto (esclude `00-index.tex` e
`tmp-*.tex`), li ordina per numero e li inserisce come `\input{Chapters/<file>.tex}` in
`main.tex`. Non tocca titolo, autore, copertina e sommario. Dopo il main genera anche un
PDF per ogni capitolo in `Files/PDF/<N_slug>.pdf` (`build_chapters.sh`, stesso titolo e
copertina, numerazione originale delle sezioni).

Se la compilazione fallisce:
1. Leggi `Files/build.log`
2. Correggi solo il file `Files/Chapters/<SLUG>.tex` nella parte colpevole
3. Rilancia lo script — max 3 tentativi

Errori tipici: `\begin{example}{...}` con graffe → usa `[...]`; `_` non escapato nel testo;
virgola nel titolo di `\begin{noteboxtitle}{...}` → `pgfkeys Error` (il titolo non è
protetto nel preambolo, riformula il titolo senza virgole).

---

## Fase 5 — Report

Risposta breve:
- percorso `.tex` e `.pdf` (`Files/main.pdf` e `Files/PDF/<N_slug>.pdf`)
- slide coperte / totali, quali saltate
- eventuali punti dove hai integrato teoria non presente nelle slide

Poi mostra il PDF con `SendUserFile`.
