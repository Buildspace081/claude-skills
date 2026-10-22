# Creare un corso nuovo

Guida per gli agenti. Va letta quando l'utente chiede un **nuovo corso / nuovo esame**,
oppure quando la skill `appunti` trova una cartella senza `Files/main.tex`.
Dopo lo scheletro, i PDF delle lezioni si gestiscono con `SKILL.md`.

`SKILL_DIR` = `/Users/gennarobasile/Desktop/buildspace/Venture-studio/claude-skills`
(percorso ufficiale, solo Mac).

---

## Struttura standard (identica per ogni corso)

```
<COURSE>/                       ← cartella del corso, es. generative-AI/
└── Files/
    ├── main.tex                ← titolo, autore, \maketitle, sommario, \input dei capitoli
    ├── preamble.tex            ← copia di SKILL_DIR/reference/preamble.tex
    ├── Chapters/               ← un file per lezione: N_nome_lezione.tex
    │   ├── 1_intro.tex
    │   └── 2_transformers.tex
    ├── PDF/                    ← PDF dei singoli capitoli (generati da assemble.sh)
    └── Images/
        ├── <copertina>.png     ← opzionale
        ├── L1/slide_001.png    ← slide estratte, una sottocartella per lezione
        └── L2/slide_001.png
```

Regole fisse:
- La radice del corso è la cartella del corso; tutto il LaTeX sta in `Files/`.
- `Chapters/` ha la **C maiuscola**, `Images/` la I maiuscola.
- Nome capitolo: `N_nome_lezione.tex` — numero intero **senza zeri iniziali**, underscore,
  titolo in minuscolo con underscore (`1_intro_to_the_course.tex`). `assemble.sh` ordina
  sul numero, quindi `10_` viene dopo `9_`.
- Ogni capitolo inizia con `%!TEX root = ../main.tex`, contiene **una sola** `\section{}`
  e **nessun** preambolo né `\begin{document}`.
- File temporanei durante la scrittura (`tmp-NN.tex`, `00-index.tex`, `plan.json`)
  stanno in `Chapters/` ma vengono ignorati da `assemble.sh`.

## Come è fatto `main.tex`

Generato da `SKILL_DIR/reference/main-template.tex`:

```latex
\documentclass[11pt]{article}
\input{preamble}
\title{\Huge <Titolo corso>}
\author{\Large Gennaro Basile}
\date{\today}
% (opzionale) \titlepic{...} con l'immagine di copertina
\begin{document}
\maketitle
\counterwithin{figure}{subsection}
\captionsetup[figure]{labelfont=bf}
\pagebreak
\tableofcontents
\pagebreak
\input{Chapters/1_xxx.tex}     ← aggiunti da assemble.sh, ognuno seguito da \pagebreak
\end{document}
```

`main.tex` si modifica a mano solo per titolo, autore e copertina. I capitoli li aggiunge
sempre `assemble.sh`; non scrivere `\input` a mano.

---

## Procedura

1. **Raccogli i dati.** Servono solo il **nome del corso** (diventa il titolo) e la
   **cartella** in cui crearlo. Autore di default: Gennaro Basile. La copertina è
   opzionale: chiedila solo se l'utente ne ha già parlato, altrimenti non farlo.
2. **Crea lo scheletro** con un solo comando:
   ```bash
   bash SKILL_DIR/scripts/new_course.sh "<COURSE_DIR>" "<Titolo del corso>"
   # opzioni: --author "Nome Cognome"   --cover /percorso/immagine.png
   ```
   Lo script crea `Files/Chapters/` e `Files/Images/`, copia il preambolo, genera
   `main.tex` e compila a vuoto per verificare che tutto funzioni. Non sovrascrive mai un
   `main.tex` o un `preamble.tex` già esistenti.
3. **Controlla l'esito.** Deve stampare `OK compilazione di prova`. Se fallisce, leggi
   `Files/build.log`; la causa più probabile è un pacchetto TeX mancante.
4. **Fermati qui.** Non creare capitoli vuoti e non fare `\input` di file inesistenti.
   Di' all'utente che il corso è pronto e che può dare i PDF delle lezioni.
5. **Quando arrivano i PDF**, segui `SKILL.md` partendo dalla cartella del corso.

## Da non fare

- Non modificare `preamble.tex` di un corso senza motivo: è il preambolo dell'utente e
  `style.md` si basa sui suoi ambienti (`defbox`, `noteboxtitle`, `example`, `\vs`).
- Non usare `chapters/` minuscolo né `main.tex` fuori da `Files/`.
- Non cancellare o rinominare a mano i capitoli già scritti: se cambi un numero, rilancia
  `assemble.sh`.
- Non committare i file ausiliari di LaTeX (`.aux`, `.log`, `.toc`, `.out`, `.synctex.gz`):
  gli script li eliminano dopo la compilazione.

## Dipendenze

```bash
command -v latexmk pdflatex   # distribuzione TeX (MacTeX)
command -v pdftoppm           # brew install poppler (estrazione slide)
command -v python3
```
