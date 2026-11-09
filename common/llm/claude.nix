{ config, lib, extraPkgs, ... }:

let
  cfg = config.myLLM.claude;
  hasUser = config.myUser.name != "";
in
{
  options.myLLM.claude.enable = lib.mkEnableOption "Claude Code CLI and dotfiles" // {
    default = true;
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ extraPkgs.llmAgents.claude-code ];
    }
    (lib.mkIf hasUser {
      home-manager.users.${config.myUser.name}.home.file.".claude/CLAUDE.md".source =
        ../dotfiles/claude/CLAUDE.md;
    })
  ]);
}
