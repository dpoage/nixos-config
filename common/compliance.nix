# SOC2 + Cyber Essentials compliance stack (Pattern requirement), gated
# behind myCompliance feature flags so only work hosts carry it — tunguska
# never sees the Drata agent, clamd's ~1.2G resident signature DB, the
# Bitwarden desktop app, or root-only administration. profiles/work.nix
# flips the master switch; per-component flags exist to turn one piece off
# without losing the rest.
#
# Not gated here: screen lock (compositor-gated in home/lock.nix), the
# firewall/auto-upgrades (baseline for every host in ./default.nix),
# "no inbound connections" (sshd and tailnet trust exist only in
# profiles/personal.nix).

{ config, lib, pkgs, ... }:

let
  cfg = config.myCompliance;
in
{
  options.myCompliance = {
    enable = lib.mkEnableOption "the compliance stack (Drata agent, ClamAV, Bitwarden, root-only administration)";

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

    rootAdmin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Cyber Essentials user-access control: the daily user is not in
        wheel; administration elevates straight to root (run0, su, polkit
        prompts) with root's own password, sops-encrypted at
        secrets/root-password.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    myUser.extraPackages =
      lib.optional cfg.drataAgent pkgs.drata-agent
      ++ lib.optional cfg.passwordManager pkgs.bitwarden-desktop;

    # Cyber Essentials: root is the separate admin account, behind a password
    # distinct from the daily user's. neededForUsers decrypts before user
    # setup, so root's password is never left unset. Create/rotate with:
    #   mkpasswd -m yescrypt | sops encrypt --filename-override \
    #     secrets/root-password --input-type binary --output-type binary \
    #     /dev/stdin > secrets/root-password
    sops.secrets."root-password" = lib.mkIf cfg.rootAdmin {
      sopsFile = ../secrets/root-password;
      format = "binary";
      neededForUsers = true;
    };
    users.users.root.hashedPasswordFile =
      lib.mkIf cfg.rootAdmin config.sops.secrets."root-password".path;
    myUser.admin = !cfg.rootAdmin;
    # wheel is empty, so polkit's default admin identity (unix-group:wheel)
    # would leave run0 and graphical prompts with nobody to authenticate as.
    security.polkit.adminIdentities = lib.mkIf cfg.rootAdmin [ "unix-user:root" ];

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
