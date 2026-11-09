# LLM agent harnesses. Each tool gets its own module with an enable flag
# and co-located dotfiles. Packages are sourced from the
# numtide/llm-agents.nix flake (extraPkgs.llmAgents) — a daily-updated
# collection that already packages Claude Code, Pi, Codex, Gemini CLI,
# OpenCode, and friends.
#
# To add a tool: drop a new ./<tool>.nix here and import it below.

{ ... }:

{
  imports = [
    ./claude.nix
    ./pi.nix
    ./codex.nix
    ./gemini.nix
    ./opencode.nix
  ];
}
