---
name: doc-writer
description: Use when writing or revising prose documentation — READMEs, docs/ pages, guides, tutorials, man pages, changelogs, and module- or package-level doc comments. Load before drafting or editing any of these. Does NOT govern GitHub comments/issues/PRs (use github-voice) or inline code comments (follow the surrounding codebase).
---

# Documentation Writer

Write documentation a tired reader parses correctly on the first pass. Three ideas
govern every choice. When they conflict, clarity wins.

- **Simplified Technical English (STE).** Constrained grammar and vocabulary, from
  ASD-STE100: one idea per sentence, active voice, present tense, one word per meaning,
  the simplest verb that works.
- **Factual knowledge transfer.** A doc exists to move a fact the reader needs into the
  reader's head. Every sentence states what a thing is, what to do, or what happens.
  Cut anything that transfers no fact.
- **Clarity.** The reader parses correctly on the first read, without backtracking.
  Order for the reader: prerequisite before step, condition before consequence, noun
  before pronoun.

## Scope

Prose documentation only. GitHub posts (comments, issues, PRs, reviews) follow the
`github-voice` guidance. Inline code comments follow the surrounding codebase's
conventions.

## Structure before sentences

- Lead with the fact the reader came for. State what the thing is and what it does in
  the first two sentences. Defer history, motivation, and edge cases.
- One topic per paragraph, at most 6 sentences. One action per step.
- A sequence of 3 or more actions is a numbered list, never a wall-of-text paragraph.
  An unordered set is dash bullets.
- Put warnings and prerequisites BEFORE the instruction they protect.
- Show, then explain. A runnable example carries more than a paragraph describing it.

## Sentences (STE)

- One idea per sentence. At most 20 words for an instruction, at most 25 for a
  description.
- Write instructions as commands: "Run the build", not "The build should be run" or
  "You may want to run the build".
- Use the active voice and name the agent: "The scheduler retries the job", not "The
  job is retried".
- Use the present tense for descriptions. Use the future tense only for real future
  events.
- Make conditions explicit and put them first: "If the check fails, the deploy stops",
  not "The deploy stops in the event of check failure".

## Words

- One word, one meaning. Pick one term per concept and keep it. Do not alternate
  "config / configuration / settings" for the same thing.
- Prefer the simple, common verb: "use" not "utilize", "start" not "initiate", "show"
  not "indicate", "do" not "perform", "help" not "facilitate".
- Keep the articles: "Start the server", not "Start server".
- Break noun clusters longer than 3 words: "the timeout for the retry queue", not "the
  retry queue timeout configuration value".
- Spell out what a pronoun refers to across any distance or ambiguity. Repeat the noun
  instead of writing "it" or "this" across a sentence boundary.
- Define an abbreviation at first use unless it is universal for the audience (API,
  CPU, URL).

## Verify the facts

- Run every published command and example verbatim before you ship it. A command that
  does not run destroys trust in the whole page.
- State a default or a value only after you confirm it against the code. Do not
  reproduce a stale one.
- When behavior is uncertain, test it. Do not paper over the gap with a vague modal.

## Never

- Nominalizations when a verb works: "compresses", not "performs compression of".
- Hedging filler: "generally", "essentially", "simply", "just", "note that", "it
  should be noted".
- Marketing language: "powerful", "seamless", "blazing fast", "robust".
- Chained modal ambiguity: "may / might / should" for behavior the system either has or
  does not have. State what happens.
- Wall-of-text procedures. If a reader must do 3 or more things, it is a numbered list.
