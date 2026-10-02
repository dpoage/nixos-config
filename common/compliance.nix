# SOC2 + Cyber Essentials compliance stack (Pattern requirement), gated
# behind myCompliance feature flags so only work hosts carry it — tunguska
# never sees the Drata agent, clamd's ~1.2G resident signature DB, the
# Bitwarden desktop app, or the admin-account split. profiles/work.nix flips
# the master switch; per-component flags exist to turn one piece off without
# losing the rest.
#
# Not gated here: screen lock (compositor-gated in home/lock.nix), the
# firewall/auto-upgrades (baseline for every host in ./default.nix), and
# "no inbound connections" (sshd and tailnet trust exist only in
# profiles/personal.nix).

{ config, lib, pkgs, ... }:

let
  cfg = config.myCompliance;
in
{
  options.myCompliance = {
    enable = lib.mkEnableOption "the compliance stack (Drata agent, ClamAV, Bitwarden, separate admin account)";

    drataAgent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Drata SOC2 evidence agent with graphical-session autostart.";
    };

    antivirus = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "ClamAV daemon, freshclam updates, and a daily scan sweep.";
    };

    passwordManager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Bitwarden desktop app (Pattern's approved password manager).";
    };

    separateAdmin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Cyber Essentials user-access control: the daily user is not an
        administrator; root goes through a separate `<user>-admin` account
        whose password hash is sops-encrypted at secrets/admin-password.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    myUser.extraPackages =
      lib.optional cfg.drataAgent pkgs.drata-agent
      ++ lib.optional cfg.passwordManager pkgs.bitwarden-desktop;

    # Cyber Essentials: admin rights behind a separate account + password.
    # neededForUsers decrypts before user creation, so the admin account
    # never exists without its password. Create/rotate the secret with:
    #   mkpasswd -m yescrypt | sops encrypt --filename-override \
    #     secrets/admin-password --input-type binary --output-type binary \
    #     /dev/stdin > secrets/admin-password
    sops.secrets."admin-password" = lib.mkIf cfg.separateAdmin {
      sopsFile = ../secrets/admin-password;
      format = "binary";
      neededForUsers = true;
    };
    myUser.admin = !cfg.separateAdmin;
    myUser.adminHashedPasswordFile =
      lib.mkIf cfg.separateAdmin config.sops.secrets."admin-password".path;

    # Drata agent autostart: tray app collecting SOC2 evidence; must run for
    # the whole graphical session. hm's hyprland module (systemd.enable
    # defaults true) starts hyprland-session.target, which BindsTo
    # graphical-session.target — so binding there autostarts the agent under
    # Hyprland. Registration note: deep links don't work on unpacked Electron
    # apps, so the first-run magic-link token is pasted into the agent by hand.
    systemd.user.services.drata-agent = lib.mkIf cfg.drataAgent {
      description = "Drata SOC2 compliance agent";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.drata-agent}/bin/drata-agent";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # SOC2 anti-malware control: clamd resident (~1.2G RAM for the signature
    # DB), freshclam timer for definition updates, and a scheduled clamdscan
    # sweep. On-access scanning (clamonacc) deliberately omitted — the control
    # requires AV presence and periodic scans, not real-time interception.
    # NOTE: like the firewall check, Drata's Linux agent may not auto-detect
    # clamd; if the AV field stays empty after a sync, submit manual evidence
    # (`systemctl status clamav-daemon` + `freshclam --version` screenshot).
    services.clamav = lib.mkIf cfg.antivirus {
      daemon.enable = true;
      updater.enable = true;
      scanner = {
        enable = true;
        # No /tmp,/var/tmp: clamdscan.service runs with PrivateTmp=yes, so
        # those paths resolve to its own empty tmpfs — scanning them is a
        # silent no-op. (Daemon-side sandboxing is irrelevant: the unit uses
        # --fdpass, the scanner opens files and hands clamd the fds.)
        scanDirectories = [ "/home" "/etc" "/var/lib" ];
      };
    };
  };
}
