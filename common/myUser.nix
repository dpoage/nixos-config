# Single source of truth for the primary user on each host.
#
# Eliminates the per-host duplication of `users.users.<name>`,
# `home-manager.users.<name>`, and per-tool integrations like
# `pattern.primaryUser` — all of which previously had to be kept
# manually in sync across hosts.
#
# Example (in a host's configuration.nix):
#
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
      default = [ "networkmanager" "wheel" "video" "audio" "input" "docker" "render" ];
      description = ''
        Groups the user belongs to beyond the implicit ones. Profile
        modules may extend this list (e.g. `personal.nix` could add
        "gamemode") via `config.myUser.extraGroups`.
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
      extraGroups = cfg.extraGroups;
      packages = cfg.extraPackages;
      shell = cfg.shell;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = lib.mkDefault "backup";
    home-manager.users.${cfg.name} = cfg.home;
  };
}
