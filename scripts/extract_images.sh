#!/usr/bin/env bash
# extract_images.sh <PDF> <IMAGES_DIR> [from] [to]
# Renderizza le pagine del PDF come PNG in IMAGES_DIR.
# Nomi output: slide_001.png, slide_002.png, ...
# Salta se le immagini esistono già (resume).
set -uo pipefail

PDF="${1:?uso: extract_images.sh <file.pdf> <images_dir> [from] [to]}"
IMGDIR="${2:?manca images_dir}"
FROM="${3:-1}"
TO="${4:-9999}"

[ -f "$PDF" ] || { echo "ERRORE: '$PDF' non esiste" >&2; exit 1; }
mkdir -p "$IMGDIR"

command -v pdftoppm >/dev/null 2>&1 || {
  echo "ERRORE: pdftoppm non trovato. Installa con: brew install poppler" >&2; exit 1; }

# Conta quante immagini slide già presenti
EXISTING=$(find "$IMGDIR" -maxdepth 1 -name 'slide_*.png' | wc -l | tr -d ' ')
EXPECTED=$(( TO - FROM + 1 ))
if [ "$EXISTING" -ge "$EXPECTED" ] 2>/dev/null; then
  echo "Immagini già presenti ($EXISTING file) — skip estrazione."
  exit 0
fi

echo "Estraggo slide ${FROM}-${TO} da \"$(basename "$PDF")\" → $IMGDIR ..."

# pdftoppm scrive: <prefix>-NNN.png
# Usiamo prefisso temporaneo, poi rinominiamo via Python (gestisce path con spazi)
TMPPREFIX="${IMGDIR}/_tmp_slide"

pdftoppm \
  -f "$FROM" \
  -l "$TO" \
  -r 150 \
  -png \
  "$PDF" "$TMPPREFIX"

python3 - "$IMGDIR" <<'PY'
import os, re, sys

imgdir = sys.argv[1]
count = 0
for fname in sorted(os.listdir(imgdir)):
    if not fname.startswith('_tmp_slide-') or not fname.endswith('.png'):
        continue
    m = re.search(r'-(\d+)\.png$', fname)
    if not m:
        continue
    pagenum = m.group(1).zfill(3)
    src = os.path.join(imgdir, fname)
    dst = os.path.join(imgdir, f'slide_{pagenum}.png')
    os.rename(src, dst)
    count += 1

if count == 0:
    print("ERRORE: nessuna immagine estratta.", file=sys.stderr)
    sys.exit(1)
print(f"OK: estratte {count} immagini")
PY
