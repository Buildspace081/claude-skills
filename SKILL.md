---
name: appunti
description: Trasforma le slide PDF di una lezione universitaria in appunti completi in LaTeX (in inglese), in un unico file chapters/<slug>.tex con sezioni e sottosezioni, aggiornando main.tex. Usare quando l'utente indica un PDF di slide e chiede appunti, note, riassunto in .tex, oppure invoca /appunti.
---

# Appunti LaTeX da slide universitarie

Pipeline: **indice → immagini → scrittura parallela → merge in file unico → compilazione**.
Non saltare fasi. Non chiedere conferme: l'utente vuole un `.tex` + `.pdf` finiti.

## Input

- `PDF` — percorso delle slide. Se non indicato, cerca PDF nel cwd; se più di uno, chiedi.
- `ESAME` — nome del corso. Se non indicato, deducilo dal nome file e comunicalo.
- `RANGE` opzionale — `--from N --to M` per una parte delle slide.
- `--seq` opzionale — scrittura sequenziale (no subagent, vedi Fase 3).

Deriva:
- `SLUG` = nome PDF senza estensione, senza numero iniziale, minuscolo con trattini
  (es. "01 Prolusion.pdf" → "prolusion").
- `OUTFILE` = `chapters/<SLUG>.tex` — il file finale di questa lezione.
- `MAIN_TEX` = `./main.tex` se esiste, altrimenti `./main-<SLUG>.tex`.

---

## Fase 0 — Setup

```bash
bash ~/.claude/skills/appunti/scripts/pdfpages.sh "<PDF>"
mkdir -p chapters Images
```

**Preambolo** (priorità): `./preamble.tex` → `../preamble.tex` → copia da
`~/.claude/skills/appunti/reference/preamble.tex` (avvisa in una riga).

**Estrazione immagini:**
```bash
bash ~/.claude/skills/appunti/scripts/extract_images.sh "<PDF>" "./Images" <FROM> <TO>
```
Idempotente: salta se le immagini esistono già.

---

## Fase 1 — Indice e piano

Leggi **tutto** il PDF (tool Read, `pages`, max 20 per chiamata) e produci:

**`chapters/00-index.tex`** — panoramica in `\begin{itemize}...\end{itemize}`, **solo per
mostrarla all'utente in chat** (Fase 1). Non finisce mai nel PDF: `\tableofcontents` in
main.tex genera già l'elenco dei capitoli automaticamente, un indice manuale sarebbe
ridondante e andrebbe aggiornato a mano ogni volta che si aggiunge una lezione.
```latex
\begin{itemize}
  \item \textbf{Markov Decision Processes} \textit{(slides 3--14)}
  \begin{itemize}
    \item States, actions, rewards \textit{(slides 3--7)}
    \item Bellman equations \textit{(slides 8--14)}
  \end{itemize}
\end{itemize}
```

**`chapters/plan.json`** — piano dei chunk per i subagent:
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

Leggi `~/.claude/skills/appunti/reference/style.md` prima di scrivere qualsiasi LaTeX.
Punti critici da tenere a mente per ogni subagent:
- Struttura: `\section{}` una sola volta (solo il primo chunk), poi `\subsection{}` e
  `\subsubsection{}` per tutto il resto
- `\begin{example}[titolo]` — parentesi quadre, **mai graffe**
- `\vs` invece di `\vspace{0.2cm}`
- Tono semplice, intuitivo, exam-oriented — non una monografia

---

## Fase 3 — Scrittura parallela in file temporanei

Ogni chunk del piano produce un file temporaneo `chapters/tmp-NN.tex` (NN a due cifre).

**Resume**: salta i chunk il cui `tmp-NN.tex` esiste già ed è non vuoto.

**Modalità parallela (default).** Ondate di max 5 subagent contemporanei.
Prompt per ogni subagent (sostituisci i segnaposto):

---
> Leggi `~/.claude/skills/appunti/reference/style.md` e rispettalo alla lettera.
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
>     \includegraphics[width=0.85\textwidth]{slide_<NNN>}
>     \caption{Descrizione in inglese.}
>     \captionsetup{font=footnotesize}
> \end{figure}
> ```
> `width=0.85\textwidth` per diagrammi a piena pagina, `width=0.60\textwidth` per figure piccole.
>
> Scrivi il risultato con il tool Write in `chapters/tmp-<NN>.tex`.
> Non produrre preambolo, non `\begin{document}`.
> Risposta finale: solo `OK tmp-NN, slides <from>-<to>, <righe> righe, <N_fig> figure`.
---

**Modalità sequenziale (`--seq`)**: stessa logica ma la fai tu, un chunk alla volta.
Più lenta, più coerente nello stile — consigliala se l'utente segnala disomogeneità.

---

## Fase 4 — Merge in file unico

Dopo che tutti i subagent hanno completato:

```bash
python3 - "chapters" "<SLUG>" <<'PY'
import os, glob

chapters = sys.argv[1]  # "chapters"
slug     = sys.argv[2]  # es. "prolusion"

tmp_files = sorted(glob.glob(os.path.join(chapters, 'tmp-*.tex')))
out_path  = os.path.join(chapters, f'{slug}.tex')

with open(out_path, 'w') as out:
    for f in tmp_files:
        with open(f) as inp:
            out.write(inp.read())
            out.write('\n')

# Rimuovi i temporanei
for f in tmp_files:
    os.remove(f)

print(f'OK: {len(tmp_files)} chunk → {out_path}')
PY
```

Poi assembla e compila:
```bash
bash ~/.claude/skills/appunti/scripts/assemble.sh "<MAIN_TEX>" "<ESAME>" "<TITOLO LEZIONE>"
```

`assemble.sh` cerca tutti i `chapters/*.tex` non temporanei (esclude `00-index.tex` e
`tmp-*.tex`) e li inserisce come `\input{}` in main.tex.

Se la compilazione fallisce:
1. Leggi il log
2. Correggi solo il file `chapters/<SLUG>.tex` nella parte colpevole
3. Rilancia lo script — max 3 tentativi

Errori tipici: `\begin{example}{...}` con graffe → usa `[...]`; `_` non escapato nel testo;
virgola nel titolo di `\begin{noteboxtitle}{...}` → `pgfkeys Error` (il titolo non è
protetto nel preambolo, riformula il titolo senza virgole).

---

## Fase 5 — Report

Risposta breve:
- percorso `.tex` e `.pdf`
- slide coperte / totali, quali saltate
- eventuali punti dove hai integrato teoria non presente nelle slide

Poi mostra il PDF con `SendUserFile`.
