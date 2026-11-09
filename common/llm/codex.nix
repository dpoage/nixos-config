# Codex CLI (OpenAI). Off by default — flip enable on per host when you
# start using it, then drop real config into common/dotfiles/codex/.
{ config, lib, extraPkgs, ... }:

let
  cfg = config.myLLM.codex;
in
{
  options.myLLM.codex.enable = lib.mkEnableOption "Codex CLI (OpenAI)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ extraPkgs.llmAgents.codex ];
  };
}
