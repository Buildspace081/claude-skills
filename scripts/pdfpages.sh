#!/usr/bin/env bash
# Numero di pagine di un PDF, con fallback multipli.
set -uo pipefail
PDF="${1:?uso: pdfpages.sh file.pdf}"
[ -f "$PDF" ] || { echo "ERRORE: '$PDF' non esiste" >&2; exit 1; }

# 1) poppler, se c'e'
if command -v pdfinfo >/dev/null 2>&1; then
  n=$(pdfinfo "$PDF" 2>/dev/null | awk '/^Pages:/{print $2; exit}')
  [ -n "${n:-}" ] && { echo "$n"; exit 0; }
fi

# 2) python: pypdf se installato, altrimenti parser con inflate degli object stream
if command -v python3 >/dev/null 2>&1; then
  n=$(python3 - "$PDF" 2>/dev/null <<'PY'
import re, sys, zlib

path = sys.argv[1]

try:
    from pypdf import PdfReader
    print(len(PdfReader(path).pages)); raise SystemExit
except SystemExit:
    raise
except Exception:
    pass

data = open(path, 'rb').read()

def scan(blob):
    counts = [int(m.group(1)) for m in re.finditer(rb'/Count\s+(\d+)', blob)]
    pages  = len(re.findall(rb'/Type\s*/Page(?![s/A-Za-z])', blob))
    return counts, pages

counts, pages = scan(data)

# I PDF moderni tengono l'albero delle pagine dentro stream compressi (/ObjStm):
# proviamo a decomprimere ogni stream e a cercare li dentro.
if not counts and not pages:
    for m in re.finditer(rb'stream\r?\n', data):
        start = m.end()
        end = data.find(b'endstream', start)
        if end == -1:
            continue
        try:
            blob = zlib.decompress(data[start:end])
        except Exception:
            continue
        c, p = scan(blob)
        counts.extend(c)
        pages += p

n = max(counts) if counts else pages
if not n:
    raise SystemExit(1)
print(n)
PY
  )
  [ -n "${n:-}" ] && { echo "$n"; exit 0; }
fi

# 3) Spotlight (solo file indicizzati)
if command -v mdls >/dev/null 2>&1; then
  n=$(mdls -raw -name kMDItemNumberOfPages "$PDF" 2>/dev/null || true)
  case "${n:-}" in ''|'(null)') ;; *) echo "$n"; exit 0 ;; esac
fi

echo "ERRORE: impossibile contare le pagine di '$PDF'." >&2
echo "Soluzione: brew install poppler   (oppure: pip install pypdf)" >&2
exit 1
