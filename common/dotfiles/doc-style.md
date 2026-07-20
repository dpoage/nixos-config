# Documentation Style: Simplified Technical English

How to write documentation: READMEs, docs/ pages, guides, man pages, module-level
doc comments. Based on ASD-STE100. Goal: text a tired reader parses correctly on
the first pass.

Scope: prose documentation only. GitHub posts follow `github-voice.md` instead.
Inline code comments follow the surrounding codebase's conventions.

## Core

One idea per sentence. Active voice. Present tense. Short sentences: at most 20
words for an instruction, at most 25 for a description. Paragraphs carry one
topic and at most 6 sentences.

## Rules

- Write instructions as commands: "Run the build", not "The build should be run"
  or "You may want to run the build".
- Use the active voice. Name the agent: "The scheduler retries the job", not
  "The job is retried".
- Use the present tense for descriptions. Use the future tense only for real
  future events.
- One word, one meaning. Pick one term per concept and keep it: do not alternate
  "config / configuration / settings" for the same thing.
- Prefer the simple, common verb: "use" not "utilize", "start" not "initiate",
  "show" not "indicate", "do" not "perform", "help" not "facilitate".
- Keep the articles. "Start the server", not "Start server".
- Break noun clusters longer than 3 words: "the timeout for the retry queue",
  not "the retry queue timeout configuration value".
- Make conditions explicit and put them first: "If the check fails, the deploy
  stops", not "The deploy stops in the event of check failure".
- Use a numbered list for a sequence of steps, one action per step. Use dash
  bullets for unordered sets.
- Put warnings and prerequisites before the instruction they protect, not after.
- Spell out what a pronoun refers to when there is any distance or ambiguity:
  repeat the noun instead of writing "it" or "this" across a sentence boundary.
- Define an abbreviation at first use unless it is universal for the audience
  (API, CPU, URL).

## Never

- Nominalizations when a verb works: "compresses", not "performs compression of".
- Hedging filler: "generally", "essentially", "simply", "just", "note that",
  "it should be noted".
- Marketing language: "powerful", "seamless", "blazing fast", "robust".
- Chained modal ambiguity: "may", "might", "should" for behavior the system
  either does or does not have. State what happens.
- Wall-of-text procedures. If a reader must do 3+ things, it is a numbered list.
