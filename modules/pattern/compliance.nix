# SOC2 + Cyber Essentials controls for work hosts; profiles/work.nix enables it.
# Assertions fail the build if another module weakens a control.

{ config, lib, pkgs, ... }:

let
  cfg = config.patternlabs.compliance;
in
{
  options.patternlabs.compliance = {
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
        prompts) with root's own password from `rootPasswordFile`.
      '';
    };

    rootPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "sops-encrypted (binary) yescrypt hash for root.";
    };
  };

  config = lib.mkIf cfg.enable {
    myUser.extraPackages =
      lib.optional cfg.drataAgent pkgs.drata-agent
      ++ lib.optional cfg.passwordManager pkgs.bitwarden-desktop;

    myUser.home.patternlabs.screenLock.enable = true;

    assertions =
      let
        hm = config.home-manager.users.${config.myUser.name};
      in
      [
        {
          assertion = config.networking.firewall.enable;
          message = "patternlabs.compliance: networking.firewall must stay enabled.";
        }
        {
          assertion = !config.services.openssh.enable;
          message = "patternlabs.compliance: work hosts accept no inbound connections; disable services.openssh.";
        }
        {
          assertion = lib.subtractLists [ "lo" ] config.networking.firewall.trustedInterfaces == [ ];
          message = "patternlabs.compliance: networking.firewall.trustedInterfaces must hold only lo.";
        }
        {
          assertion = config.programs.hyprlock.enable && hm.services.hypridle.enable;
          message = "patternlabs.compliance: screen lock needs programs.hyprlock.enable (profiles/hyprland-stack.nix) and the user's hypridle.";
        }
      ];

    # Rotate: mkpasswd -m yescrypt | sops encrypt --filename-override F \
    #   --input-type binary --output-type binary /dev/stdin > F
    sops.secrets."root-password" = lib.mkIf cfg.rootAdmin {
      sopsFile = cfg.rootPasswordFile;
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
