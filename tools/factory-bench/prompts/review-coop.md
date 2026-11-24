You are a benchmark driver, not an engineer. Do exactly three things.

1. Call the `task` tool once, with three tasks in its `tasks` list, each for
   `agent: "{AGENT}"`, with `name` set to `Ada`, `Bo` and `Cy`. Each task text is
   everything below the line, verbatim and complete, with one first line added:
   `You are Ada.`, `You are Bo.` or `You are Cy.`
2. The call returns at once. Call the `wait` tool, again each time it returns with an
   agent still running, until all three results have arrived.
3. Reply with the single word DONE.

Call `task` exactly once in the whole run: a second call starts more agents and voids
the benchmark. Never edit files, review the work, or add to the brief. If an agent asks
you a question, answer only: "Proceed on the brief as written."

---

## Team

Three reviewers, Ada, Bo and Cy, review the slice below together and deliver one
verdict. Nobody leads and nobody competes.

Talk to a teammate by writing a message to `agent://Ada`, `agent://Bo` or `agent://Cy`
with the `write` tool. Messages from teammates arrive in your session on their own.

1. Plan first. Read the brief and the slice, then send both teammates the properties
   of the brief and the parts of the code you propose to probe. Read their messages
   before you probe. Where two proposals overlap, the name earlier in the alphabet
   keeps the part and the other picks a part nobody took. Every property of the brief
   is somebody's.
2. Probe your part. Keep your work under `{SCRATCH}/<your name>/`, and write each
   candidate finding's probe there in the form the seat brief gives.
3. Check each other. Send each candidate finding to one teammate: the claim and the
   probe's path. The checker re-runs the probe on a fresh copy of the tree and reads
   the claim against the brief, and answers "holds" or the reason it does not. A
   finding that its checker cannot reproduce, or that no sentence of the brief
   supports, is dropped unless its owner answers the reason.
4. Ada alone writes `{SCRATCH}/verdict.json` and `{SCRATCH}/findings/`. Bo and Cy send
   Ada their checked findings and tell her when they have no more. Ada copies each
   checked finding's directory to `{SCRATCH}/findings/<id>/`, writes the verdict, and
   tells Bo and Cy that it exists.
5. Reply only after Ada has written the verdict. Bo and Cy wait for her message.

{BRIEF}
