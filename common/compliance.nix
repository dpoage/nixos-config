# SOC2 compliance stack (Pattern requirement), gated behind myCompliance
# feature flags so only work hosts carry it — tunguska never sees the Drata
# agent, clamd's ~1.2G resident signature DB, or the Bitwarden desktop app.
# profiles/work.nix flips the master switch; per-component flags exist to
# turn one piece off without losing the rest.
#
# Not gated here: screen lock (compositor-gated in home/lock.nix) and the
# firewall/auto-upgrades (baseline for every host in ./default.nix).

{ config, lib, pkgs, ... }:

let
  cfg = config.myCompliance;
in
{
  options.myCompliance = {
    enable = lib.mkEnableOption "the SOC2 compliance stack (Drata agent, ClamAV, Bitwarden)";

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
  };

  config = lib.mkIf cfg.enable {
    myUser.extraPackages =
      lib.optional cfg.drataAgent pkgs.drata-agent
      ++ lib.optional cfg.passwordManager pkgs.bitwarden-desktop;

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
