{ ... }:

{
  # Claude Code base config
  home.file.".claude/CLAUDE.md".source = ../dotfiles/CLAUDE.md;

  # OpenCode config
  xdg.configFile = {
    "opencode/opencode.json".source = ../dotfiles/opencode/opencode.json;
    "opencode/AGENTS.md".source = ../dotfiles/opencode/AGENTS.md;
    "opencode/ensemble.json".source = ../dotfiles/opencode/ensemble.json;

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
