# Single source of truth for the primary user on each host. Drives
# users.users.<name>, home-manager.users.<name>, and pattern.primaryUser.
#
# Example:
#   myUser = {
#     name = "dustin";
#     fullName = "Dustin Poage";
#     extraPackages = with pkgs; [ firefox slack ];
#     home = { ... }: { imports = [ ../common/home ]; myRice.enable = true; };
#   };

{ config, lib, pkgs, ... }:

let
  cfg = config.myUser;
in
{
  options.myUser = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "Login name of the primary user.";
      example = "dustin";
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      default = cfg.name;
      description = "GECOS description for the user account.";
    };

    shell = lib.mkOption {
      type = lib.types.package;
      default = pkgs.zsh;
      description = "Login shell. Defaults to zsh.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional groups beyond the baseline (networkmanager, wheel,
        video, audio, input, docker, render). Profiles can append here:
        Nix merges list options across modules.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Per-user packages installed into the user's profile (not
        system-wide). Profiles like `personal.nix` and `work.nix`
        contribute their own lists here.
      '';
    };

    home = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = ''
        Home-manager module evaluated for this user. Typically:
          imports = [ ../common/home ]; myRice.enable = true;
      '';
    };
  };

  config = lib.mkIf (cfg.name != "") {
    users.users.${cfg.name} = {
      isNormalUser = true;
      description = cfg.fullName;
      extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" "docker" "render" ] ++ cfg.extraGroups;
      packages = cfg.extraPackages;
      shell = cfg.shell;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = lib.mkDefault "backup";
    home-manager.users.${cfg.name} = cfg.home;
  };
}
