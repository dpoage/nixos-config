{ ... }:

{
  # Claude Code base config
  home.file.".claude/CLAUDE.md".source = ../dotfiles/CLAUDE.md;

  # OpenCode config
  xdg.configFile = {
    "opencode/opencode.json".source = ../dotfiles/opencode/opencode.json;
    "opencode/AGENTS.md".source = ../dotfiles/opencode/AGENTS.md;
    "opencode/agent/review.md".source = ../dotfiles/opencode/agent/review.md;
  };
}
