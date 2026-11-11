---
description: Fix the cause of a Nix evaluation or build error instead of overriding it away
scope: "tool:edit(*.nix), tool:write(*.nix)"
condition:
  - 'mkForce|mkOverride|allowBroken|permittedInsecurePackages|allowUnfree|allowInsecure|doCheck\s*=\s*false|doInstallCheck\s*=\s*false|dontCheck|meta\.broken|mkIf\s+false|checkPhase\s*=\s*"'
question: "The content is an edit to a Nix file. Answer yes if the edit adds an override or escape hatch (mkForce, mkOverride, allowBroken, permittedInsecurePackages, allowUnfree, disabled checks, dontCheck, an emptied checkPhase, mkIf false) whose evident purpose is to make an evaluation error, option conflict, build failure, or test failure go away rather than to set an intended value. Answer no if the override reads as a deliberate setting with a stated or evident reason, such as replacing a module default with a chosen value."
---
Your Nix edit overrides something in a way that looks like it silences an error. Find the cause first: for an option conflict, find the other definition (`nix eval` with `--show-trace`, `nixos-option`); for a build or test failure, read the log and fix it, pin a working version, or patch the package.

If the override is the right fix, keep it with a one-line comment that states why.
