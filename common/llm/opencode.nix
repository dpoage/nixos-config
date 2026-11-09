{ config, lib, extraPkgs, ... }:

let
  cfg = config.myLLM.opencode;
  hasUser = config.myUser.name != "";
in
{
  options.myLLM.opencode.enable = lib.mkEnableOption "OpenCode CLI and dotfiles" // {
    default = true;
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ extraPkgs.llmAgents.opencode ];
    }
    (lib.mkIf hasUser {
      home-manager.users.${config.myUser.name}.xdg.configFile = {
        "opencode/opencode.json".source = ../dotfiles/opencode/opencode.json;
        "opencode/AGENTS.md".source = ../dotfiles/opencode/AGENTS.md;
        "opencode/agent/review.md".source = ../dotfiles/opencode/agent/review.md;
      };
    })
  ]);
}
