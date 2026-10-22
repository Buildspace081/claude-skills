#!/usr/bin/env bash
# new_course.sh <COURSE_DIR> "<TITOLO>" [--author "Nome"] [--cover <immagine>]
# Crea lo scheletro LaTeX di un nuovo corso:
#   <COURSE_DIR>/Files/{main.tex, preamble.tex, Chapters/, Images/}
# Non crea capitoli. Compila a vuoto per verificare che lo scheletro funzioni.
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

COURSE="${1:?uso: new_course.sh <course_dir> \"<titolo>\" [--author X] [--cover img]}"
TITLE="${2:?manca il titolo del corso}"
shift 2

AUTHOR="Gennaro Basile"
COVER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --author) AUTHOR="${2:?manca il valore di --author}"; shift 2 ;;
    --cover)  COVER="${2:?manca il valore di --cover}"; shift 2 ;;
    *) echo "ERRORE: opzione sconosciuta '$1'" >&2; exit 1 ;;
  esac
done

FILES="$COURSE/Files"
if [ -e "$FILES/main.tex" ]; then
  echo "ERRORE: '$FILES/main.tex' esiste già, non sovrascrivo." >&2; exit 1
fi
[ -z "$COVER" ] || [ -f "$COVER" ] || { echo "ERRORE: cover '$COVER' non trovata" >&2; exit 1; }

mkdir -p "$FILES/Chapters" "$FILES/Images"

# Il preambolo esistente (se c'è) non va toccato
if [ -e "$FILES/preamble.tex" ]; then
  echo "preamble.tex già presente — lo lascio com'è."
else
  cp "$SKILL_DIR/reference/preamble.tex" "$FILES/preamble.tex"
fi

COVER_NAME=""
if [ -n "$COVER" ]; then
  COVER_NAME="$(basename "$COVER")"
  cp "$COVER" "$FILES/Images/$COVER_NAME"
fi

python3 - "$SKILL_DIR/reference/main-template.tex" "$FILES/main.tex" "$TITLE" "$AUTHOR" "$COVER_NAME" <<'PY'
import sys
tpl, out, title, author, cover = sys.argv[1:6]
s = open(tpl).read()
if cover:
    cover_block = ("\\titlepic{\n    \\begin{center}\n"
                   f"        \\includegraphics[scale=0.5]{{{cover}}}\n"
                   "    \\end{center}}\n")
else:
    cover_block = ""
s = s.replace("{{COVER}}\n", cover_block)
s = s.replace("{{TITLE}}", title).replace("{{AUTHOR}}", author)
open(out, "w").write(s)
PY

echo "Scheletro creato in: $FILES"

command -v latexmk >/dev/null 2>&1 || { echo "latexmk non trovato: compila a mano."; exit 0; }
if latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir="$FILES" "$FILES/main.tex" \
     > "$FILES/build.log" 2>&1; then
  echo "OK compilazione di prova -> $FILES/main.pdf"
  latexmk -c -outdir="$FILES" "$FILES/main.tex" >/dev/null 2>&1
  rm -f "$FILES/build.log" "$FILES"/main.synctex.gz
else
  echo "COMPILAZIONE DI PROVA FALLITA — vedi $FILES/build.log" >&2
  exit 2
fi
