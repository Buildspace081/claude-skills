#!/usr/bin/env bash
# assemble.sh <MAIN_TEX> <ESAME> <TITOLO_LEZIONE>
# Aggiorna main.tex con \input{chapters/sec-NN} e compila con latexmk.
set -uo pipefail

MAIN="${1:?uso: assemble.sh <main.tex> <esame> <titolo>}"
ESAME="${2:-Course}"
TITOLO="${3:-Lecture notes}"

MAINDIR=$(dirname "$(realpath "$MAIN")")
CHAPTERS="$MAINDIR/chapters"

[ -d "$CHAPTERS" ] || { echo "ERRORE: '$CHAPTERS' non trovata" >&2; exit 1; }

# Prende tutti i .tex non speciali: esclude 00-index.tex e tmp-*.tex
SECS=$(find "$CHAPTERS" -maxdepth 1 -name '*.tex' -size +0 \
  ! -name '00-index.tex' ! -name 'tmp-*.tex' | sort)
[ -n "$SECS" ] || { echo "ERRORE: nessun file .tex di contenuto in chapters/" >&2; exit 1; }
N_SECS=$(echo "$SECS" | wc -l | tr -d ' ')

# Tutta la logica di update/creazione in Python (evita problemi con \n shell)
python3 - "$MAIN" "$MAINDIR" "$TITOLO" <<'PY'
import sys, re, os, glob

main_path   = sys.argv[1]
maindir     = sys.argv[2]
titolo      = sys.argv[3]
chapters    = os.path.join(maindir, "chapters")

# Raccoglie i file di contenuto: tutti i .tex tranne 00-index.tex e tmp-*.tex
all_tex = sorted(glob.glob(os.path.join(chapters, "*.tex")))
sec_files = [f for f in all_tex
             if os.path.basename(f) != "00-index.tex"
             and not os.path.basename(f).startswith("tmp-")]
sec_names = [os.path.splitext(os.path.basename(f))[0] for f in sec_files]

# Costruisce il blocco da inserire (tutto qui, niente variabili shell con \n)
# Niente indice manuale: il \tableofcontents genera già l'elenco dei capitoli.
lines = []
lines.append(r"\tableofcontents")
lines.append(r"\newpage")
lines.append("")
for name in sec_names:
    lines.append(f"\\input{{chapters/{name}}}")
    lines.append(r"\pagebreak")
lines.append("")
block = "\n".join(lines) + "\n"

if os.path.exists(main_path):
    with open(main_path, 'r') as f:
        content = f.read()

    # Aggiorna titolo se ancora placeholder
    if r'\Huge Text Mining' in content:
        content = content.replace(r'\Huge Text Mining', f'\\Huge {titolo}')
        print(f"  -> Titolo aggiornato: '{titolo}'")

    # Rimuovi blocchi inseriti da run precedenti
    content = re.sub(r'\\section\*\{Overview\}.*?\\newpage\s*\n', '', content, flags=re.DOTALL)
    content = re.sub(r'\\tableofcontents.*?\\newpage\s*\n', '', content, flags=re.DOTALL)
    content = re.sub(r'\\input\{chapters/[^}]+\}\s*\n', '', content)
    content = re.sub(r'\\input\{\}\s*\n', '', content)
    # Rimuovi il TOC standalone del template originale PRIMA di togliere i \pagebreak isolati
    content = re.sub(r'(%% -- Sommario\s*\n)?\\tableofcontents\s*\n(\\pagebreak|\\newpage)?\s*\n', '\n', content)
    content = re.sub(r'^\\pagebreak\s*\n', '', content, flags=re.MULTILINE)

    # Inserisce il blocco prima di \end{document}
    if r'\end{document}' in content:
        content = content.replace(r'\end{document}', block + r'\end{document}')
    else:
        content += "\n" + block + "\n\\end{document}\n"

    with open(main_path, 'w') as f:
        f.write(content)
    print(f"  -> main.tex aggiornato ({len(sec_names)} sezioni)")

else:
    # Crea un main.tex minimale
    new_content  = "\\documentclass[11pt]{article}\n"
    new_content += "\\input{preamble}\n\n"
    new_content += f"\\title{{\\Huge {titolo}}}\n"
    new_content += "\\author{\\Large Gennaro Basile}\n"
    new_content += "\\date{\\today}\n\n"
    new_content += "\\begin{document}\n"
    new_content += "\\maketitle\n"
    new_content += "\\pagebreak\n\n"
    new_content += block
    new_content += "\\end{document}\n"
    with open(main_path, 'w') as f:
        f.write(new_content)
    print(f"  -> main.tex creato ({len(sec_names)} sezioni)")
PY

echo "main.tex ha $(wc -l < "$MAIN" | tr -d ' ') righe, ${N_SECS} sezioni."

command -v latexmk >/dev/null 2>&1 || {
  echo "latexmk non trovato: compila a mano '$MAIN'."; exit 0; }

echo "Compilo $MAIN ..."
LOGFILE="$MAINDIR/build.log"
if latexmk -pdf -interaction=nonstopmode -halt-on-error \
      -outdir="$MAINDIR" "$MAIN" > "$LOGFILE" 2>&1; then
  PDF="${MAIN%.tex}.pdf"
  echo "OK  ->  $PDF"
  latexmk -c -outdir="$MAINDIR" "$MAIN" >/dev/null 2>&1
  exit 0
else
  echo "COMPILAZIONE FALLITA. Errori:"
  grep -nE '^(!|l\.[0-9]+|.*Undefined control sequence|.*Missing)' "$LOGFILE" | head -40
  echo "--- log completo: $LOGFILE"
  exit 2
fi
