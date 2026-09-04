{ ... }:

{
  # Claude Code base config
  home.file.".claude/CLAUDE.md".source = ../dotfiles/CLAUDE.md;
  home.file.".claude/github-voice.md".source = ../dotfiles/github-voice.md;

  # Agent skills (~/.agents/skills)
  home.file.".agents/skills/arbiter-architect/SKILL.md".source =
    ../dotfiles/agents/skills/arbiter-architect/SKILL.md;
  home.file.".agents/skills/oracle-rounds/SKILL.md".source =
    ../dotfiles/agents/skills/oracle-rounds/SKILL.md;
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

  # OMP agent definitions (~/.omp/agent/agents)
  home.file.".omp/agent/agents/oracle.md".source =
    ../dotfiles/omp/agents/oracle.md;
  home.file.".omp/agent/agents/architect.md".source =
    ../dotfiles/omp/agents/architect.md;
  home.file.".omp/agent/agents/implementer.md".source =
    ../dotfiles/omp/agents/implementer.md;
  home.file.".omp/agent/agents/implementer-max.md".source =
    ../dotfiles/omp/agents/implementer-max.md;

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
    "opencode/github-voice.md".source = ../dotfiles/github-voice.md;
    "opencode/doc-style.md".source = ../dotfiles/doc-style.md;

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
