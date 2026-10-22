#!/usr/bin/env bash
# build_chapters.sh <MAIN_TEX>
# Compila un PDF per ogni capitolo: Files/PDF/<N_slug>.pdf
# Ogni PDF usa titolo, autore e copertina di main.tex e mantiene la numerazione
# originale delle sezioni (il capitolo 3 resta "3", non diventa "1").
set -uo pipefail

MAIN="${1:?uso: build_chapters.sh <Files/main.tex>}"
[ -f "$MAIN" ] || { echo "ERRORE: '$MAIN' non esiste" >&2; exit 1; }
command -v latexmk >/dev/null 2>&1 || { echo "latexmk non trovato: salto i PDF dei capitoli."; exit 0; }

MAINDIR=$(dirname "$(realpath "$MAIN")")
OUT="$MAINDIR/PDF"
mkdir -p "$OUT"

# Genera un wrapper _single_<slug>.tex per ogni capitolo e stampa "<slug>" per riga
SLUGS=$(python3 - "$MAIN" "$MAINDIR" <<'PY'
import sys, re, os, glob
main_path, maindir = sys.argv[1], sys.argv[2]
chapters = os.path.join(maindir, "Chapters")
src = open(main_path).read()

# main.tex senza i \input dei capitoli, senza \tableofcontents e relativi \pagebreak
base = re.sub(r'\\input\{Chapters/[^}]*\}[ \t]*\n(\\pagebreak[ \t]*\n)?', '', src)
base = re.sub(r'\\tableofcontents[ \t]*\n(\\pagebreak[ \t]*\n)?', '', base)

def key(p):
    n = os.path.basename(p)
    m = re.match(r'(\d+)', n)
    return (int(m.group(1)) if m else 10**9, n)

for f in sorted(glob.glob(os.path.join(chapters, '*.tex')), key=key):
    name = os.path.basename(f)
    if name == '00-index.tex' or name.startswith('tmp-') or os.path.getsize(f) == 0:
        continue
    slug = os.path.splitext(name)[0]
    m = re.match(r'(\d+)', name)
    start = int(m.group(1)) - 1 if m else 0
    block = f"\\setcounter{{section}}{{{start}}}\n\\input{{Chapters/{name}}}\n"
    out = base.replace(r'\end{document}', block + r'\end{document}')
    open(os.path.join(maindir, f"_single_{slug}.tex"), 'w').write(out)
    print(slug)
PY
)
[ -n "$SLUGS" ] || { echo "Nessun capitolo da compilare."; exit 0; }

cd "$MAINDIR" || exit 1
FAIL=0
for slug in $SLUGS; do
  W="_single_${slug}.tex"
  if latexmk -pdf -interaction=nonstopmode -halt-on-error \
        -jobname="$slug" -outdir="$OUT" "$W" > "$OUT/$slug.log" 2>&1; then
    latexmk -c -jobname="$slug" -outdir="$OUT" "$W" >/dev/null 2>&1
    rm -f "$OUT/$slug.log" "$OUT/$slug.synctex.gz"
    echo "OK  ->  PDF/$slug.pdf"
  else
    echo "FALLITO: $slug (log: PDF/$slug.log)"
    FAIL=1
  fi
  rm -f "$W"
done
exit $FAIL
