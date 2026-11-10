{ config, lib, pkgs, ... }:

let
  cfg = config.myPrompt;
  stylix = config.stylix;
  colors = config.lib.stylix.colors;
  ansi = import ../theme/ansi.nix colors;

  # Rounded pill around `body`; the body styles itself and must carry bg:`color`.
  pill = color: body: "[](fg:${color})${body}[](fg:${color}) ";

  badgeText = b: if b.label != "" then "${b.icon} ${b.label}" else b.icon;
  badges = lib.concatMapStringsSep " " badgeText cfg.badges;

  # Identity pill: static badges plus user@host, which starship shows only over
  # SSH or as another user. Without badges the pill exists only when they do.
  gap = "[ ](bg:neutral)";
  identity =
    if cfg.badges != [ ]
    then pill "neutral" "[ ${badges}](bg:neutral fg:neutral_fg)(${gap}$username$hostname)${gap}"
    else "(${pill "neutral" "${gap}$username$hostname${gap}"})";

  # Light palettes: most accents give base00 text under 4.5:1 (catppuccin-latte
  # pastels 2.3-3.0:1), so the segments are the accent mixed toward the text
  # color base05 (see ../theme/mix.nix) and keep base00 text. Dark palettes
  # keep the plain slots.
  light = stylix.polarity == "light";
  mix = import ../theme/mix.nix { inherit lib; };
  # Lowest passing pct per use, measured on gruvbox-light and catppuccin-latte;
  # a new light palette needs re-probing.
  segmentPct = 70; # starship segments 4.5:1 from 61 (latte); kitty url from 19
  hintPct = 70; # autosuggest hint 3:1 from 64 (latte)
  hash = hex: "#${hex}";
  accent = slot: hash (mix.mixHex { from = colors.${slot}; toward = colors.base05; pct = segmentPct; });
  seg = slot: if light then accent slot else colors.withHashtag.${slot};

  # Semantic prompt colors; pills put base00 text on them, other text sits on base00.
  promptColors = {
    neutral = colors.withHashtag.base02;
    neutral_fg = colors.withHashtag.base05;
    pill_text = colors.withHashtag.base00;
    path = seg "base16";
    branch = seg "base0B";
    dirty = seg "base0A";
    toolchain = seg "base15";
    cloud = seg "base17";
    # Dark base08 is 2.7:1 on gruvbox-dark; its bright red clears 4.3:1.
    danger = if light then accent "base08" else colors.withHashtag.base12;
    subtle = hash (mix.mixHex { from = colors.base00; toward = colors.base05; pct = hintPct; });
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
    # modules/personal/theme); colors come from the base24 ANSI list, fonts from stylix.*.
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
        # base06 is rosewater on latte (2.3:1 vs base00); light selections are the
        # inverse chip, and cursor/url follow.
        selection_background = if light then base05 else base06;
        cursor = if light then base05 else base06;
        cursor_text_color = base00;
        url_color = if light then accent "base0D" else base06;
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
      autosuggestion = {
        enable = true;
        # Default hint is ANSI 8 (base04), 1.9:1 on catppuccin-latte; light
        # palettes get a text-color mix that clears 3:1 as a dim hint.
        highlight = lib.mkIf light "fg=${hash (mix.mixHex { from = colors.base00; toward = colors.base05; pct = hintPct; })}";
      };
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

    # Starship prompt. Pills: identity, directory, git; plain text: toolchain
    # and cloud context. Right side: exit status, duration, jobs, time.
    programs.starship = {
      enable = true;
      settings = {
        format = builtins.concatStringsSep "" [
          identity
          "$directory"
          "$git_branch$git_commit$git_state$git_status"
          "$nix_shell$python$rust$golang$nodejs"
          "$docker_context$kubernetes$gcloud$aws"
          "$line_break$character"
        ];
        right_format = "$status$cmd_duration$jobs$time";

        palettes.base16 = promptColors;

        username = {
          style_user = "bg:neutral fg:neutral_fg";
          style_root = "bg:danger fg:pill_text bold";
          format = "[$user]($style)";
        };

        hostname = {
          style = "bg:neutral fg:neutral_fg bold";
          format = "[@$hostname]($style)";
        };

        # Inside a repo: bold repo name, then the path below it.
        directory = let
          tail = "[$path]($style)[$read_only]($read_only_style)[ ]($style)";
        in {
          style = "bg:path fg:pill_text";
          repo_root_style = "bg:path fg:pill_text bold";
          read_only_style = "bg:path fg:pill_text";
          read_only = " 󰌾";
          format = pill "path" "[ ]($style)${tail}";
          repo_root_format = pill "path" "[ $repo_root]($repo_root_style)${tail}";
          truncation_length = 4;
          truncation_symbol = "…/";
        };

        git_branch = {
          only_attached = true;
          format = pill "branch" "[  $branch ](bg:branch fg:pill_text)";
        };

        git_commit.format = pill "branch" "[  $hash$tag ](bg:branch fg:pill_text)";

        git_state.format = pill "danger"
          "[ $state( $progress_current/$progress_total) ](bg:danger fg:pill_text bold)";

        # Shown only when the tree is dirty, stashed, or out of sync with upstream.
        git_status = {
          format = "(${pill "dirty" "[ $all_status$ahead_behind](bg:dirty fg:pill_text)"})";
          conflicted = "✘$count ";
          staged = "+$count ";
          modified = "~$count ";
          renamed = "»$count ";
          deleted = "-$count ";
          typechanged = "";
          untracked = "?$count ";
          stashed = "≡$count ";
          ahead = "⇡$count ";
          behind = "⇣$count ";
          diverged = "⇡$ahead_count⇣$behind_count ";
        };

        nix_shell = {
          symbol = "❄ ";
          style = "fg:toolchain";
          format = "[$symbol$name]($style) ";
        };

        python = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version( \\($virtualenv\\))]($style) ";
        };

        rust = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version]($style) ";
        };

        golang = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version]($style) ";
        };

        nodejs = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version]($style) ";
        };

        docker_context = {
          symbol = " ";
          style = "fg:cloud";
          format = "[$symbol$context]($style) ";
        };

        kubernetes = {
          disabled = !cfg.kubernetes;
          symbol = "☸ ";
          style = "fg:cloud";
          format = "[$symbol$context( \\($namespace\\))]($style) ";
        };

        # Literal symbols: a conditional group hides only when all its variables are empty.
        gcloud = {
          disabled = !cfg.gcloud;
          style = "fg:cloud";
          format = "([☁ $project]($style) )";
        };

        aws = {
          disabled = !cfg.aws;
          style = "fg:cloud";
          format = "([ $profile( \\($region\\))]($style) )";
        };

        status = {
          disabled = false;
          style = "fg:danger bold";
          format = "[✘ $status( $signal_name)]($style) ";
        };

        cmd_duration = {
          min_time = 2000;
          style = "fg:subtle";
          format = "[took $duration]($style) ";
        };

        jobs = {
          symbol = "✦ ";
          number_threshold = 1;
          style = "fg:dirty";
          format = "[$symbol$number]($style) ";
        };

        time = {
          disabled = false;
          time_format = "%R";
          style = "fg:subtle";
          format = "[$time]($style)";
        };

        character = {
          success_symbol = "[❯](bold fg:branch)";
          error_symbol = "[❯](bold fg:danger)";
          vimcmd_symbol = "[❮](bold fg:branch)";
        };
      };
    };
  };
}
