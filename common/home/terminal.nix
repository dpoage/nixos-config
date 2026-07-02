{ config, lib, pkgs, ... }:

let
  cfg = config.myPrompt;
  rice = config.myRice;
  c = rice.colors; # resolved palette; always defined (default catppuccin)
  named = import ./rice/named.nix c; # shared semantic color names

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

  # Starship named colors, derived once from the active palette via the shared
  # semantic map. The format string references these names (mauve, peach, ...).
  starshipPalette = lib.mapAttrs (_: v: "#${v}") named;

  # --- FZF colors (derived from the active palette) ---
  fzfColorOpts = builtins.concatStringsSep " " [
    "--color=bg+:#${c.bg1},bg:#${c.bg},spinner:#${c.fg2},hl:#${c.redBr}"
    "--color=fg:#${c.fg},header:#${c.redBr},info:#${c.accent},pointer:#${c.fg2}"
    "--color=marker:#${c.promptMuted},fg+:#${c.fg},prompt:#${c.accent},hl+:#${c.redBr}"
    "--color=selected-bg:#${c.bg2}"
  ];

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
    # Kitty terminal, themed from the active palette (myRice.colors).
    programs.kitty = {
      enable = true;
      font = {
        name = rice.fonts.mono;
        size = rice.fonts.monoSize;
      };
      settings = {
        foreground = "#${c.fg}";
        background = "#${c.bg}";
        selection_foreground = "#${c.bg}";
        selection_background = "#${c.fg2}";
        cursor = "#${c.fg2}";
        cursor_text_color = "#${c.bg}";
        url_color = "#${c.fg2}";

        # Normal (0-7) / bright (8-15) ANSI, matching alacritty's mapping.
        color0 = "#${c.bg0}";
        color8 = "#${c.gray}";
        color1 = "#${c.red}";
        color9 = "#${c.redBr}";
        color2 = "#${c.green}";
        color10 = "#${c.greenBr}";
        color3 = "#${c.yellow}";
        color11 = "#${c.yellowBr}";
        color4 = "#${c.blue}";
        color12 = "#${c.blueBr}";
        color5 = "#${c.purple}";
        color13 = "#${c.purpleBr}";
        color6 = "#${c.aqua}";
        color14 = "#${c.aquaBr}";
        color7 = "#${c.fg4}";
        color15 = "#${c.fg}";

        # Tab bar
        active_tab_foreground = "#${c.promptFg}";
        active_tab_background = "#${c.purple}";
        inactive_tab_foreground = "#${c.fg}";
        inactive_tab_background = "#${c.bg0}";
        tab_bar_background = "#${c.promptFg}";

        # Window
        background_opacity = toString rice.terminal.opacity;
        window_padding_width = "8";
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

        # FZF theme (generated from palette when myRice is enabled)
        export FZF_DEFAULT_OPTS="${fzfColorOpts} --multi"
      '';
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

        # clock mode
        setw -g clock-mode-colour yellow

        # copy mode
        setw -g mode-style 'fg=black bg=red bold'

        # panes
        set -g pane-border-style 'fg=red'
        set -g pane-active-border-style 'fg=yellow'

        # statusbar
        set -g status-position bottom
        set -g status-justify left
        set -g status-style 'fg=red'

        set -g status-left ""
        set -g status-left-length 10

        set -g status-right-style 'fg=black bg=yellow'
        set -g status-right '%Y-%m-%d %H:%M '
        set -g status-right-length 50

        setw -g window-status-current-style 'fg=black bg=red'
        setw -g window-status-current-format ' #I #W #F '

        setw -g window-status-style 'fg=red bg=black'
        setw -g window-status-format ' #I #[fg=white]#W #[fg=yellow]#F '

        setw -g window-status-bell-style 'fg=yellow bg=red bold'

        # messages
        set -g message-style 'fg=yellow bg=red bold'
      '';
    };

    # SSH
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        setEnv = { TERM = "xterm-256color"; };
      };
    };

    # Starship prompt — palette is generated from myRice.colors when rice is
    # enabled, otherwise falls back to hardcoded Catppuccin Mocha.
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

        palette = "prompt";
        palettes.prompt = starshipPalette;

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
