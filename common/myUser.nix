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
        Additional groups beyond the baseline (networkmanager, video, audio,
        render; plus wheel and input when `admin` is true). Profiles can
        append here: Nix merges list options across modules.
      '';
    };

    admin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the primary user administers the machine (wheel). When false,
        administration moves to a separate `<name>-admin` account with its own
        password, and the primary user also loses `input` (raw /dev/input
        access would let it log the admin password as it is typed).
      '';
    };

    adminHashedPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        File holding the `mkpasswd` hash for the `<name>-admin` account.
        Required when `admin` is false: it is the only wheel account, so
        creating it without a password would lock the machine.
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
    assertions = [
      {
        assertion = cfg.admin || cfg.adminHashedPasswordFile != null;
        message = "myUser.admin = false requires myUser.adminHashedPasswordFile (the admin account is the only wheel member).";
      }
    ];

    users.users.${cfg.name} = {
      isNormalUser = true;
      description = cfg.fullName;
      extraGroups =
        [ "networkmanager" "video" "audio" "render" ]
        ++ lib.optionals cfg.admin [ "wheel" "input" ]
        ++ cfg.extraGroups;
      packages = cfg.extraPackages;
      shell = cfg.shell;
    };

    users.users."${cfg.name}-admin" = lib.mkIf (!cfg.admin) {
      isNormalUser = true;
      description = "${cfg.fullName} (admin)";
      extraGroups = [ "wheel" ];
      hashedPasswordFile = cfg.adminHashedPasswordFile;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = lib.mkDefault "backup";
    home-manager.users.${cfg.name} = cfg.home;
  };
}
