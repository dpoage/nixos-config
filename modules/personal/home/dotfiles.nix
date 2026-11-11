{ config, ... }:

{
  # Claude Code base config
  home.file.".claude/CLAUDE.md".source = ../dotfiles/CLAUDE.md;
  home.file.".claude/github-voice.md".source =
    ../dotfiles/agents/skills/github-voice/SKILL.md;

  # Agent skills (~/.agents/skills)
  home.file.".agents/skills/arbiter-architect/SKILL.md".source =
    ../dotfiles/agents/skills/arbiter-architect/SKILL.md;
  home.file.".agents/skills/oracle-rounds/SKILL.md".source =
    ../dotfiles/agents/skills/oracle-rounds/SKILL.md;
  home.file.".agents/skills/oracle-rounds/procedure.md".source =
    ../dotfiles/agents/skills/oracle-rounds/procedure.md;
  home.file.".agents/skills/oracle-rounds/casebook.md".source =
    ../dotfiles/agents/skills/oracle-rounds/casebook.md;
  home.file.".agents/skills/handoff/SKILL.md".source =
    ../dotfiles/agents/skills/handoff/SKILL.md;
  home.file.".agents/skills/doc-writer/SKILL.md".source =
    ../dotfiles/agents/skills/doc-writer/SKILL.md;
  home.file.".agents/skills/comment-compactor/SKILL.md".source =
    ../dotfiles/agents/skills/comment-compactor/SKILL.md;
  home.file.".agents/skills/module-design/SKILL.md".source =
    ../dotfiles/agents/skills/module-design/SKILL.md;
  home.file.".agents/skills/interface-contract/SKILL.md".source =
    ../dotfiles/agents/skills/interface-contract/SKILL.md;
  home.file.".agents/skills/design-review/SKILL.md".source =
    ../dotfiles/agents/skills/design-review/SKILL.md;
  home.file.".agents/skills/github-voice/SKILL.md".source =
    ../dotfiles/agents/skills/github-voice/SKILL.md;
  home.file.".agents/skills/bug-hunt/SKILL.md".source =
    ../dotfiles/agents/skills/bug-hunt/SKILL.md;
  home.file.".agents/skills/acceptance-replay/SKILL.md".source =
    ../dotfiles/agents/skills/acceptance-replay/SKILL.md;
  home.file.".agents/skills/premortem/SKILL.md".source =
    ../dotfiles/agents/skills/premortem/SKILL.md;
  home.file.".agents/skills/bend/SKILL.md".source =
    ../dotfiles/agents/skills/bend/SKILL.md;
  home.file.".agents/skills/type-driven-design/SKILL.md".source =
    ../dotfiles/agents/skills/type-driven-design/SKILL.md;
  home.file.".agents/skills/type-driven-design/cpp.md".source =
    ../dotfiles/agents/skills/type-driven-design/cpp.md;
  home.file.".agents/skills/type-driven-design/rust.md".source =
    ../dotfiles/agents/skills/type-driven-design/rust.md;
  home.file.".agents/skills/type-driven-design/go.md".source =
    ../dotfiles/agents/skills/type-driven-design/go.md;
  home.file.".agents/skills/type-driven-design/typescript.md".source =
    ../dotfiles/agents/skills/type-driven-design/typescript.md;
  home.file.".agents/skills/type-driven-design/python.md".source =
    ../dotfiles/agents/skills/type-driven-design/python.md;
  home.file.".agents/skills/type-driven-design/elixir.md".source =
    ../dotfiles/agents/skills/type-driven-design/elixir.md;
  home.file.".agents/skills/skill-review/SKILL.md".source =
    ../dotfiles/agents/skills/skill-review/SKILL.md;

  # OMP agent definitions (~/.omp/agent/agents)
  home.file.".omp/agent/agents/oracle.md".source =
    ../dotfiles/omp/agents/oracle.md;
  home.file.".omp/agent/agents/architect.md".source =
    ../dotfiles/omp/agents/architect.md;
  home.file.".omp/agent/agents/implementer.md".source =
    ../dotfiles/omp/agents/implementer.md;
  home.file.".omp/agent/agents/implementer-max.md".source =
    ../dotfiles/omp/agents/implementer-max.md;
  home.file.".omp/agent/agents/sweeper.md".source =
    ../dotfiles/omp/agents/sweeper.md;
  home.file.".omp/agent/agents/skill-reviewer.md".source =
    ../dotfiles/omp/agents/skill-reviewer.md;

  # OMP TTSR rules (~/.omp/agent/rules). Identity comes from programs.git so
  # the work profile's mkDefault override flows through.
  home.file.".omp/agent/rules/git-authorship.md".text =
    builtins.replaceStrings
      [ "@GIT_NAME@" "@GIT_EMAIL@" ]
      [ config.programs.git.settings.user.name config.programs.git.settings.user.email ]
      (builtins.readFile ../dotfiles/omp/rules/git-authorship.md);
  home.file.".omp/agent/rules/terse-comments.md".source =
    ../dotfiles/omp/rules/terse-comments.md;
  home.file.".omp/agent/rules/context-rollover.md".source =
    ../dotfiles/omp/rules/context-rollover.md;
  home.file.".omp/agent/rules/context-rollover-checkpoint.md".source =
    ../dotfiles/omp/rules/context-rollover-checkpoint.md;
  home.file.".omp/agent/rules/punted-work.md".source =
    ../dotfiles/omp/rules/punted-work.md;
  home.file.".omp/agent/rules/deferred-without-bead.md".source =
    ../dotfiles/omp/rules/deferred-without-bead.md;
  home.file.".omp/agent/rules/unverified-done.md".source =
    ../dotfiles/omp/rules/unverified-done.md;
  home.file.".omp/agent/rules/silent-scope-shrink.md".source =
    ../dotfiles/omp/rules/silent-scope-shrink.md;
  home.file.".omp/agent/rules/needless-question.md".source =
    ../dotfiles/omp/rules/needless-question.md;
  home.file.".omp/agent/rules/unpushed-session-end.md".source =
    ../dotfiles/omp/rules/unpushed-session-end.md;
  home.file.".omp/agent/rules/oracle-probe-evidence.md".source =
    ../dotfiles/omp/rules/oracle-probe-evidence.md;
  home.file.".omp/agent/rules/implementer-self-verdict.md".source =
    ../dotfiles/omp/rules/implementer-self-verdict.md;
  home.file.".omp/agent/rules/nix-silenced-error.md".source =
    ../dotfiles/omp/rules/nix-silenced-error.md;
  home.file.".omp/agent/rules/swallowed-error.md".source =
    ../dotfiles/omp/rules/swallowed-error.md;
  home.file.".omp/agent/rules/repinned-test.md".source =
    ../dotfiles/omp/rules/repinned-test.md;
  home.file.".omp/agent/rules/compat-shim.md".source =
    ../dotfiles/omp/rules/compat-shim.md;
  home.file.".omp/agent/rules/narrating-comment.md".source =
    ../dotfiles/omp/rules/narrating-comment.md;
  home.file.".omp/agent/rules/rationalized-shortcut.md".source =
    ../dotfiles/omp/rules/rationalized-shortcut.md;

  # OMP model-role overlay: read-only layer over ~/.omp/agent/config.yml.
  # PI_CONFIG_FILES makes omp load it; per-key override, strict parse.
  home.file.".omp/agent/roles-overlay.yml".source =
    ../dotfiles/omp/roles-overlay.yml;
  home.sessionVariables.PI_CONFIG_FILES = "$HOME/.omp/agent/roles-overlay.yml";

  # OpenCode config
  xdg.configFile = {
    "opencode/opencode.json".source = ../dotfiles/opencode/opencode.json;
    "opencode/AGENTS.md".source = ../dotfiles/opencode/AGENTS.md;
    "opencode/ensemble.json".source = ../dotfiles/opencode/ensemble.json;
    "opencode/github-voice.md".source = ../dotfiles/agents/skills/github-voice/SKILL.md;
    "opencode/doc-style.md".source = ../dotfiles/agents/skills/doc-writer/SKILL.md;

    "opencode/agent/review.md".source = ../dotfiles/opencode/agent/review.md;
    "opencode/agent/explore.md".source = ../dotfiles/opencode/agent/explore.md;
    "opencode/agent/plan.md".source = ../dotfiles/opencode/agent/plan.md;
    "opencode/agent/test.md".source = ../dotfiles/opencode/agent/test.md;

    "opencode/commands/commit.md".source = ../dotfiles/opencode/commands/commit.md;
    "opencode/commands/pr.md".source = ../dotfiles/opencode/commands/pr.md;
    "opencode/commands/bd-ready.md".source = ../dotfiles/opencode/commands/bd-ready.md;
    "opencode/commands/review.md".source = ../dotfiles/opencode/commands/review.md;
    "opencode/commands/handoff.md".source = ../dotfiles/opencode/commands/handoff.md;
    "opencode/commands/test.md".source = ../dotfiles/opencode/commands/test.md;
  };
}
