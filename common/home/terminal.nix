{ config, lib, pkgs, ... }:

let
  cfg = config.myPrompt;
  stylix = config.stylix;
  colors = config.lib.stylix.colors;
  ansi = import ../theme/ansi.nix colors;

  # --- Badge generation ---
  # Badges appear between the username and directory segments,
  # on a distinctive background.
  badgeTexts = map (b:
    let text = if b.label != "" then "${b.icon} ${b.label}" else b.icon;
    in "[ ${text} ](bg:flamingo fg:crust)"
  ) cfg.badges;

  hasBadges = cfg.badges != [];

  badgeSegment = lib.optionalString hasBadges
    ("[](bg:flamingo fg:mauve)" + builtins.concatStringsSep "" badgeTexts);

  # The powerline arrow between badges (or username) and directory must
  # transition from the correct color.
  afterBadge = if hasBadges
    then "[](fg:flamingo bg:peach)"
    else "[](bg:peach fg:mauve)";

  # Segment names the prompt format already uses, added to Stylix's
  # starship palette (which owns green, blue and purple).
  starshipSegments = with colors.withHashtag; {
    mauve = bright-magenta;
    flamingo = orange;
    peach = bright-yellow;
    teal = bright-cyan;
    crust = base00;
  };

in
{
  options.myPrompt = {
    badges = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          icon = lib.mkOption {
            type = lib.types.str;
            description = "Nerd Font icon for the badge.";
          };
          label = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Optional text label next to the icon.";
          };
        };
      });
      default = [];
      description = ''
        Static badges shown in the prompt between username and directory.
        Set by host profiles to indicate active modules/context.
      '';
    };

    kubernetes = lib.mkEnableOption "the Kubernetes context segment in the prompt";
    gcloud = lib.mkEnableOption "the Google Cloud segment in the prompt";
    aws = lib.mkEnableOption "the AWS segment in the prompt";
  };

  config = {
    # Stylix's kitty target only emits base16 colors and is off (see
    # common/theme); colors come from the base24 ANSI list, fonts from stylix.*.
    programs.kitty = {
      enable = true;
      font = {
        name = stylix.fonts.monospace.name;
        size = stylix.fonts.sizes.terminal;
      };
      settings = with colors.withHashtag; {
        foreground = base05;
        background = base00;
        selection_foreground = base00;
        selection_background = base06;
        cursor = base06;
        cursor_text_color = base00;
        url_color = base06;
      }
      // lib.listToAttrs (lib.imap0 (i: hex: lib.nameValuePair "color${toString i}" "#${hex}") ansi)
      // {
        # Tab bar
        active_tab_foreground = base00;
        active_tab_background = base0E;
        inactive_tab_foreground = base05;
        inactive_tab_background = base01;
        tab_bar_background = base00;

        # Window
        background_opacity = toString stylix.opacity.terminal;
        window_padding_width = "8";
        # kitty >= 0.49 restores the last window state (incl. maximized) on
        # Wayland; under Hyprland that opens every new kitty maximized
        # instead of tiled. The tiler owns geometry, so don't remember it.
        remember_window_size = "no";
        confirm_os_window_close = "0";
        enable_audio_bell = "no";
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";

        # Scrollback
        scrollback_lines = "10000";

        # URLs
        detect_urls = "yes";
        open_url_with = "default";
      };
    };

    # Zsh
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;

      history = {
        size = 50000;
        save = 50000;
        ignoreDups = true;
        ignoreAllDups = true;
        ignoreSpace = true;
        extended = true;
        share = true;
      };

      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "docker"
          "kubectl"
          "sudo"
          "history"
          "extract"
        ];
      };

      shellAliases = {
        ls = "eza --icons";
        ll = "eza -la --icons --git";
        lt = "eza --tree --icons --level=2";
        cat = "bat";
        grep = "rg";
        find = "fd";
        top = "btop";
        ".." = "cd ..";
        # NOTE: `cd` is provided by programs.zoxide (--cmd cd) below, not aliased
        # here. A static `cd = "z"` alias breaks in non-interactive shells (e.g.
        # the Claude Code Bash tool) where zoxide's functions aren't loaded,
        # yielding `__zoxide_z: command not found`.
        "..." = "cd ../..";
        gs = "git status";
        gd = "git diff";
        gl = "git log --oneline --graph";
        gc = "git commit";
        gp = "git push";
      };

      initContent = ''
        # FZF keybindings
        if [ -n "''${commands[fzf-share]}" ]; then
          source "$(fzf-share)/key-bindings.zsh"
          source "$(fzf-share)/completion.zsh"
        fi
      '';
    };

    # Colors come from the Stylix fzf/bat/btop targets.
    programs.fzf = {
      enable = true;
      enableZshIntegration = false;
      defaultOptions = [ "--multi" ];
    };
    programs.bat.enable = true;
    programs.btop.enable = true;

    # LS_COLORS (read by eza and ls) is `vivid generate` of the theme the
    # Stylix vivid target defines; the zsh integration exports it.
    # Directories use base0D: the target's base0F is unreadable on gruvbox-dark.
    programs.vivid = {
      enable = true;
      enableZshIntegration = true;
      themes.${config.programs.vivid.activeTheme}.core.directory.foreground =
        lib.mkForce "base0D";
    };

    # Zoxide (smart cd). Managed via the home-manager module rather than a
    # manual `eval "$(zoxide init zsh)"` so initialization stays in sync with the
    # package and ordering. `--cmd cd` defines a `cd` shell function that handles
    # real paths directly and falls back to zoxide queries — and, crucially, when
    # the integration isn't loaded (non-interactive shells like the Claude Code
    # Bash tool) `cd` is simply the builtin, instead of a dangling `z` alias.
    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    # Yazi (terminal file browser). enableZshIntegration provides the `yy`
    # wrapper function, which cd's the shell to yazi's last directory on
    # quit — the reason to prefer it over invoking `yazi` directly.
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "yy";
      settings = {
        mgr.show_hidden = true;
        preview.wrap = "yes";
      };
    };

    # Tmux
    programs.tmux = {
      enable = true;
      mouse = true;
      terminal = "screen-256color";
      extraConfig = ''
        bind | split-window -h
        bind - split-window -v
        unbind '"'
        unbind %

        # switch panes using Alt-arrow without prefix
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D

        # don't do anything when a 'bell' rings
        set -g visual-activity off
        set -g visual-bell off
        set -g visual-silence off
        setw -g monitor-activity off
        set -g bell-action none

        # Colors: none set here. Styles for the status line, windows, panes,
        # messages, copy mode and clock come from the Stylix tmux target.

        # statusbar
        set -g status-position bottom
        set -g status-justify left

        set -g status-left ""
        set -g status-left-length 10

        set -g status-right '%Y-%m-%d %H:%M '
        set -g status-right-length 50

        setw -g window-status-current-format ' #I #W #F '
        setw -g window-status-format ' #I #W #F '
      '';
    };

    # SSH
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        SetEnv = { TERM = "xterm-256color"; };
      };
      # Alias the fleet flake's platform inputs fetch through
      # (robot-provisioning-fleet flake.nix).
      settings."github-platform" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
        HostKeyAlias = "github.com";
      };
    };

    # Starship prompt, colored from the active palette's semantic names.
    programs.starship = {
      enable = true;
      settings = {
        format = builtins.concatStringsSep "" [
          "[](mauve)"
          "$os"
          "$username"
          badgeSegment
          afterBadge
          "$directory"
          "[](fg:peach bg:green)"
          "$git_branch"
          "$git_status"
          "[](fg:green bg:teal)"
          "$rust"
          "$golang"
          "$python"
          "$nodejs"
          "[](fg:teal bg:blue)"
          "$docker_context"
          "$kubernetes"
          "$gcloud"
          "$aws"
          "[](fg:blue bg:purple)"
          "$time"
          "[ ](fg:purple)"
          "$line_break"
          "$character"
        ];

        palettes.base16 = starshipSegments;

        os = {
          disabled = false;
          style = "bg:mauve fg:crust";
          symbols.NixOS = " ";
        };

        username = {
          show_always = true;
          style_user = "bg:mauve fg:crust";
          style_root = "bg:mauve fg:crust";
          format = "[ $user ]($style)";
        };

        directory = {
          style = "fg:crust bg:peach";
          format = "[ $path ]($style)";
          truncation_length = 3;
          truncation_symbol = ".../";
          substitutions = {
            Documents = " ";
            Downloads = " ";
            Music = " ";
            Pictures = " ";
          };
        };

        git_branch = {
          symbol = "";
          style = "bg:green fg:crust";
          format = "[ $symbol $branch ]($style)";
        };

        git_status = {
          style = "bg:green fg:crust";
          format = "[$all_status$ahead_behind ]($style)";
        };

        rust = {
          symbol = "";
          style = "bg:teal fg:crust";
          format = "[ $symbol ($version) ]($style)";
        };

        golang = {
          symbol = "";
          style = "bg:teal fg:crust";
          format = "[ $symbol ($version) ]($style)";
        };

        python = {
          symbol = "";
          style = "bg:teal fg:crust";
          format = "[ $symbol ($version) ]($style)";
        };

        nodejs = {
          symbol = "";
          style = "bg:teal fg:crust";
          format = "[ $symbol ($version) ]($style)";
        };

        docker_context = {
          symbol = "";
          style = "bg:blue fg:crust";
          format = "[ $symbol $context ]($style)";
        };

        kubernetes = {
          disabled = !cfg.kubernetes;
          symbol = "☸ ";
          style = "bg:blue fg:crust";
          format = "[ $symbol$context( \\($namespace\\)) ]($style)";
        };

        gcloud = {
          disabled = !cfg.gcloud;
          symbol = "☁ ";
          style = "bg:blue fg:crust";
          format = "[ $symbol$project ]($style)";
        };

        aws = {
          disabled = !cfg.aws;
          symbol = " ";
          style = "bg:blue fg:crust";
          format = "[ $symbol$profile(\\($region\\)) ]($style)";
        };

        time = {
          disabled = false;
          time_format = "%R";
          style = "bg:purple fg:crust";
          format = "[ $time ]($style)";
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };

        line_break.disabled = false;
      };
    };
  };
}
