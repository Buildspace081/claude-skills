#!/usr/bin/env bash
# assemble.sh <MAIN_TEX>
# Aggiorna main.tex (e genera i PDF dei capitoli) con un \input{Chapters/<file>} per ogni capitolo (ordine numerico
# sul prefisso N_) e compila con latexmk.
set -uo pipefail

MAIN="${1:?uso: assemble.sh <Files/main.tex>}"
[ -f "$MAIN" ] || { echo "ERRORE: '$MAIN' non esiste (crea il corso con new_course.sh)" >&2; exit 1; }

MAINDIR=$(dirname "$(realpath "$MAIN")")
CHAPTERS="$MAINDIR/Chapters"
[ -d "$CHAPTERS" ] || { echo "ERRORE: '$CHAPTERS' non trovata" >&2; exit 1; }

# Tutta la logica di aggiornamento in Python (ordinamento numerico, regex robuste)
python3 - "$MAIN" "$CHAPTERS" <<'PY'
import sys, re, os, glob

main_path, chapters = sys.argv[1], sys.argv[2]

def key(path):
    # "10_foo.tex" dopo "2_foo.tex": ordina sul numero iniziale, poi sul nome
    name = os.path.basename(path)
    m = re.match(r'(\d+)', name)
    return (int(m.group(1)) if m else 10**9, name)

files = [f for f in glob.glob(os.path.join(chapters, '*.tex'))
         if os.path.getsize(f) > 0
         and os.path.basename(f) != '00-index.tex'
         and not os.path.basename(f).startswith('tmp-')]
files.sort(key=key)
if not files:
    print("ERRORE: nessun file .tex di contenuto in Chapters/", file=sys.stderr)
    sys.exit(1)

content = open(main_path).read()

# Rimuove gli \input{Chapters/...} esistenti (e il \pagebreak che li segue)
content = re.sub(r'\\input\{Chapters/[^}]*\}[ \t]*\n(\\pagebreak[ \t]*\n)?(\s*\n)*', '', content)

block = ''.join(f"\\input{{Chapters/{os.path.basename(f)}}}\n\\pagebreak\n\n" for f in files)
if r'\end{document}' not in content:
    print("ERRORE: \\end{document} mancante in main.tex", file=sys.stderr)
    sys.exit(1)
content = content.replace(r'\end{document}', block + r'\end{document}')
open(main_path, 'w').write(content)
print(f"  -> main.tex aggiornato ({len(files)} capitoli): "
      + ", ".join(os.path.basename(f) for f in files))
PY
[ $? -eq 0 ] || exit 1

command -v latexmk >/dev/null 2>&1 || {
  echo "latexmk non trovato: compila a mano '$MAIN'."; exit 0; }

echo "Compilo $MAIN ..."
LOGFILE="$MAINDIR/build.log"
if latexmk -pdf -interaction=nonstopmode -halt-on-error \
      -outdir="$MAINDIR" "$MAIN" > "$LOGFILE" 2>&1; then
  PDF="${MAIN%.tex}.pdf"
  echo "OK  ->  $PDF"
  latexmk -c -outdir="$MAINDIR" "$MAIN" >/dev/null 2>&1
  rm -f "$MAINDIR"/main.synctex.gz
  # PDF dei singoli capitoli in Files/PDF/ (un errore qui non blocca il main)
  bash "$(dirname "${BASH_SOURCE[0]}")/build_chapters.sh" "$MAIN" || echo "ATTENZIONE: qualche PDF di capitolo non compilato."
  exit 0
else
  echo "COMPILAZIONE FALLITA. Errori:"
  grep -nE '^(!|l\.[0-9]+|.*Undefined control sequence|.*Missing)' "$LOGFILE" | head -40
  echo "--- log completo: $LOGFILE"
  exit 2
fi
