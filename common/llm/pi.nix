{ config, lib, extraPkgs, ... }:

let
  cfg = config.myLLM.pi;
  hasUser = config.myUser.name != "";
in
{
  options.myLLM.pi.enable = lib.mkEnableOption "Pi coding agent (pi.dev) and dotfiles" // {
    default = true;
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ extraPkgs.llmAgents.pi ];
    }
    (lib.mkIf hasUser {
      home-manager.users.${config.myUser.name}.home.file.".pi/agent/settings.json".source =
        ../dotfiles/pi/settings.json;
    })
  ]);
}
