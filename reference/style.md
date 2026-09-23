# Regole di stile per gli appunti

Vincolanti. Setup LaTeX verificato sul preamble.tex dell'utente (2026-09-23).

---

## Pubblico e obiettivo

Il lettore studia per un **esame magistrale di Data Science**: vuole capire i concetti,
saper rispondere a domande teoriche, e avere un'idea di come i metodi si usano in pratica.
**Non** vuole dimostrazioni complete né derivazioni passo-passo (a meno che la derivazione
*sia* il punto della slide).

Scrivi come se spiegassi a un collega intelligente che non è statistico di formazione:
- Usa analogie concrete ("pensa a X come a Y")
- Dopo ogni formula, spiega **cosa significa** in una riga ("in pratica: più grande è λ,
  più il modello penalizza i coefficienti grandi")
- Evita gergo tecnico non necessario; quando lo usi, definiscilo subito

---

## Lingua

**Tutto in inglese**, inclusi titoli, caption, commenti nel codice.

---

## Struttura del file

Ogni lezione produce **un unico file** `chapters/<slug>.tex`.

```
\section{Nome Lezione}\label{sec:<slug>}

\subsection{Macro-argomento 1}\label{sec:<slug>-macro1}

\subsubsection{Sotto-argomento}\label{sec:<slug>-sub1}
testo...

\subsection{Macro-argomento 2}
...
```

- `\section{}` — una sola per file, è la lezione intera
- `\subsection{}` — uno per macro-argomento (corrisponde ai chunk del piano)
- `\subsubsection{}` — usa liberamente per spezzettare e dare ritmo: meglio troppi
  che troppo pochi; aiuta a studiare per step
- Metti `\label{sec:...}` su `\section` e `\subsection`
- **Mai** preambolo, mai `\begin{document}`

---

## Profondità matematica

Le formule ci sono, ma devono essere **leggibili**, non intimidatorie.

Regola: per ogni formula non banale scrivi:
1. La formula
2. Una riga che spiega **cosa rappresenta** ogni simbolo importante
3. Una riga di intuizione ("more λ → stronger regularisation → simpler model")

```latex
The ridge estimator is
\[
  \hat{\beta}^{\text{ridge}} = \argmin_{\beta}
    \underbrace{\|y - X\beta\|^2}_{\text{fit}} +
    \lambda \underbrace{\|\beta\|^2}_{\text{complexity penalty}}.
\]
Here $\lambda \geq 0$ controls the trade-off: $\lambda = 0$ recovers OLS,
while $\lambda \to \infty$ shrinks all coefficients to zero.
```

**Non fare:** derivazioni complete, prove formali, calcoli di algebra lineare che non
aggiungono intuizione. Se la derivazione è lunga, mostra solo i passaggi chiave.

**Usa `align`** per catene di passaggi, mai dentro `\[...\]`.

Operatori già definiti nel preambolo: `\argmin`, `\argmax` — usali senza ridichiarare.

---

## Definizioni — `defbox`

`defbox` è una tcolorbox con **un argomento titolo obbligatorio**. Non lasciarlo vuoto.

```latex
\begin{defbox}{Markov Property}
A stochastic process has the Markov property if the future depends only on the
present state, not on the history:
\[
  P(s_{t+1} \mid s_t, s_{t-1}, \ldots, s_0) = P(s_{t+1} \mid s_t).
\]
\textit{Think of it as: the current state is a sufficient summary of the past.}
\end{defbox}
```

Usa le corsive per le frasi di intuizione dentro le defbox.

---

## Esempi — `example`

⚠️ `example` è un `\newtheorem` — **nessun argomento tra graffe**.
Usa solo l'opzionale tra parentesi quadre:

```latex
\vs
\begin{example}[Q-learning on a tiny grid]
Consider a $2\times2$ grid...
\end{example}
```

`\vs` va **prima** di `\begin{example}`, non dentro.

Gli esempi devono essere:
- **concreti**: numeri reali, scenari specifici (non "consider some data X")
- **brevi**: 5–10 righe, focalizzati su un solo concetto
- **connessi**: spiegano perché la teoria appena vista serve a qualcosa

### Step dentro gli esempi

```latex
\vs
\begin{example}[Training a Q-table]
\begin{itemize}
  \item \texttt{Step 1:} Initialise $Q(s,a) = 0$ for all $(s,a)$.

  \vs
  \item \texttt{Step 2:} At each step pick $a = \argmax_{a'} Q(s, a')$
        ($\varepsilon$-greedy: with prob.\ $\varepsilon$ pick randomly).

  \vs
  \item \texttt{Step 3:} Observe $r$ and $s'$, then update:
        $Q(s,a) \mathrel{+}= \alpha\bigl(r + \gamma \max_{a'} Q(s',a') - Q(s,a)\bigr)$.
\end{itemize}
\end{example}
```

---

## Codice Python

Includi Python **solo quando**:
- il concetto è intrinsecamente computazionale (algoritmi, aggiornamenti iterativi)
- il codice è ≤ 20 righe, standalone, niente import esotici
- è il tipo di codice che potrebbe servire in un compito o progetto

Usa `lstlisting` (il preambolo ha lo stile VS Code configurato):

```latex
\begin{lstlisting}[language=Python, caption={Q-learning update}]
import numpy as np

Q = np.zeros((n_states, n_actions))

for episode in range(n_episodes):
    s = env.reset()
    done = False
    while not done:
        # epsilon-greedy action selection
        a = np.argmax(Q[s]) if np.random.rand() > eps else env.action_space.sample()
        s_next, r, done, _ = env.step(a)
        Q[s, a] += alpha * (r + gamma * Q[s_next].max() - Q[s, a])
        s = s_next
\end{lstlisting}
```

Non forzare il codice: se la slide è su teoria pura, niente Python.

---

## Note — `noteboxtitle`

Per osservazioni importanti che non sono né definizioni né esempi:

```latex
\begin{noteboxtitle}{Watch out}
In practice, $\varepsilon$ should decay over time: high at the start
(explore) and low at the end (exploit).
\end{noteboxtitle}
```

⚠️ **Il titolo di `noteboxtitle` NON deve contenere virgole.** A differenza di
`defbox` (protetto da `\mbox{}` nel preambolo), il titolo di `noteboxtitle` è
passato "nudo" a `pgfkeys`: una virgola lo spezza in chiavi separate e la
compilazione fallisce con `Package pgfkeys Error: I do not know the key`.
Se il titolo citerebbe naturalmente una frase con virgole, riformulalo senza
virgole o accorcialo (es. `"All models are wrong, but useful"` → `"All Models
Are Wrong"`).

---

## Figure da slide

Le immagini estratte sono in `Images/slide_NNN.png`. Includile **solo** per slide
che sono prevalentemente un diagramma, schema, flowchart o grafico — non per slide
di solo testo o formule (quelle le scrivi in LaTeX).

```latex
\begin{figure}[H]
    \centering
    \includegraphics[width=0.85\textwidth]{slide_014}
    \caption{Agent-environment interaction loop.}
    \captionsetup{font=footnotesize}
\end{figure}
```

Scale: `width=0.85\textwidth` per diagrammi a piena pagina, `width=0.60\textwidth`
per figure più piccole.

---

## Schemi e diagrammi

Se la slide ha uno schema riproducibile in LaTeX (e farlo è più chiaro dell'immagine),
usalo. Altrimenti usa la figura estratta.

- `tikzpicture` per diagrammi/flussi — il preambolo carica `positioning, arrows.meta,
  shapes.geometric, calc`
- `tabular` / `booktabs` per confronti e tassonomie

---

## Cose da non fare

- `\usepackage` — il preambolo esiste già
- `\begin{example}{titolo}` con graffe — è `\newtheorem`, usa `[titolo]`
- `\vspace{0.2cm}` — usa `\vs`
- Derivazioni complete se non aggiungono intuizione
- Frasi di servizio ("In this section we will...")
- `\includegraphics` di file non in `Images/`
- Caratteri non escapati: `_`, `%`, `&`, `#` → `\_`, `\%`, `\&`, `\#`
