---
description: Every oracle finding rests on a probe the oracle ran, not on reading or reasoning
agents: [oracle]
scope: "text, tool:yield"
condition:
  - 'BLOCKING|VERDICT'
question: "The content is a report from an adversarial verification agent (an oracle) that reviews code. Answer yes if any BLOCKING finding is stated without a command or probe the agent ran and the output it observed, for example a finding that rests only on reading code, on reasoning, or on words like likely, could, or may. Answer no if every BLOCKING finding cites an executed probe and its output, or if the report has no BLOCKING findings."
---
Your report holds a BLOCKING finding with no executed probe behind it. For each such finding, run a probe that shows the wrong behavior and cite its command and output, or move the finding to nits or `SCOPE:`. Then re-issue the report; the verdict follows from the probes.
