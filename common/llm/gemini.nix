# Gemini CLI (Google). Off by default — flip enable on per host when you
# start using it, then drop real config into common/dotfiles/gemini/.
{ config, lib, extraPkgs, ... }:

let
  cfg = config.myLLM.gemini;
in
{
  options.myLLM.gemini.enable = lib.mkEnableOption "Gemini CLI (Google)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ extraPkgs.llmAgents.gemini-cli ];
  };
}
