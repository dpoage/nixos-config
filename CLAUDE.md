# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:5c2c0639 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

```bash
ci/check.sh    # evaluate every host and checks.patternlabs-example (stubbed pattern-cli)
```

## Architecture Overview

Layers, each a `nixosModules` export that brings its overlay and imports what it
builds on:

- `modules/core/` (`nixosModules.core`): baseline OS, `myUser`, `myNvidia`,
  `myScreenLock` (home-manager). Role modules: `core-desktop`, `core-laptop`,
  `core-workstation`, `core-hyprland`.
- `modules/dev/` (`dev`, needs core): language toolchains, bazel; `dev-cuda` per NVIDIA host.
- `modules/dev-cloud/` (`dev-cloud`, needs core): AWS/GCP CLIs, Kubernetes, HashiCorp.
- `modules/pattern/` (`patternlabs`, imports core + dev + dev-cloud): Pattern CLI,
  compliance (`patternlabs.*`); `patternlabs-work` adds the work apps and enables compliance.
- `modules/personal/`: dpoage's layer: theme, nixvim, agent tooling, home-manager
  config (`home/`), dotfiles, timezone.
- `overlays/<layer>/`: matching package overlays; `overlays/core` provides `pkgs.unstable`.
- `<host>/`: hardware and per-host choices. `flake.nix` `mkHost` composes chosen
  layers + core + personal + host; only oerlikon takes `patternlabs`.

## Conventions & Patterns

- A layer may reference only the layers it imports; none may reference the personal
  layer, a person, or a repo-local path. Personal hosts (tunguska, bofors) build
  without `patternlabs`; `checks.patternlabs-example` (a non-dpoage work laptop)
  builds without the personal layer.
- Compliance controls are assertions in `modules/pattern/compliance.nix`; satisfy
  them instead of overriding them.
