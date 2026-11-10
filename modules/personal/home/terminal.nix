{ config, lib, pkgs, ... }:

let
  cfg = config.myPrompt;
  stylix = config.stylix;
  colors = config.lib.stylix.colors;

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
  # pastels 2.3-3.0:1), so segments mix toward the palette's ink and keep base00 text.
  light = stylix.polarity == "light";
  lc = config.myTheme.lightContrast;
  mix = import ../theme/mix.nix { inherit lib; };
  hash = hex: "#${hex}";
  accent = slot: hash (mix.mixHex { from = colors.${slot}; toward = colors.${lc.ink}; pct = lc.segment; });
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
    danger = if light then accent lc.red else colors.withHashtag.base12;
    subtle = hash (mix.mixHex { from = colors.base00; toward = colors.${lc.ink}; pct = lc.hint; });
  };

  kittyColors = import ../theme/kitty-colors.nix { inherit lib; };

  # One kitty color file per palette; kitty-palette pushes them over kitty's socket.
  paletteConfs = pkgs.linkFarm "kitty-palettes" (lib.mapAttrsToList
    (name: theme: {
      name = "${name}.conf";
      path = pkgs.writeText "kitty-${name}.conf"
        (lib.concatStrings (lib.mapAttrsToList (k: v: "${k} ${v}\n") (kittyColors theme)));
    })
    config.myTheme.palettes);

  # Recolors every running kitty window; nothing persists past a kitty restart.
  kittyPalette = pkgs.writeShellApplication {
    name = "kitty-palette";
    runtimeInputs = [ config.programs.kitty.package pkgs.fzf pkgs.coreutils ];
    text = ''
      confs=${paletteConfs}

      usage() {
        cat <<EOF
      Usage: kitty-palette [PALETTE | --list | --reset]

      Live-preview myTheme palettes in every running kitty window.
        (none)    pick with fzf; moving the cursor recolors, Enter keeps, Esc resets
        PALETTE   apply PALETTE
        --list    list palettes
        --reset   restore the colors kitty started with
      Colors last until kitty restarts; set myTheme.palette to keep one.
      EOF
      }

      # $1: color file, or empty to reset. Stale sockets from dead kittys fail quietly.
      apply() {
        local sock ok=0
        shopt -s nullglob
        for sock in "''${XDG_RUNTIME_DIR:?}"/kitty-*; do
          [ -S "$sock" ] || continue
          if [ -n "$1" ]; then
            kitten @ --to "unix:$sock" set-colors --all --configured "$1" 2>/dev/null && ok=1
          else
            kitten @ --to "unix:$sock" set-colors --reset 2>/dev/null && ok=1
          fi
        done
        if [ "$ok" = 0 ]; then
          echo "kitty-palette: no kitty listening in $XDG_RUNTIME_DIR (kittys started before the switch need a restart)" >&2
          return 1
        fi
      }

      list() {
        for f in "$confs"/*.conf; do basename "$f" .conf; done
      }

      # fzf preview: ANSI 0-15 and sample text, drawn in the live colors.
      swatch() {
        local i
        printf '%s\n\n' "$1"
        for i in 0 1 2 3 4 5 6 7; do printf '\e[48;5;%sm    ' "$i"; done
        printf '\e[0m\n'
        for i in 8 9 10 11 12 13 14 15; do printf '\e[48;5;%sm    ' "$i"; done
        printf '\e[0m\n\n'
        printf 'plain text \e[2mdim text\e[0m \e[90mcomment\e[0m\n'
        printf '\e[31merror\e[0m \e[33mwarning\e[0m \e[32mok\e[0m \e[34minfo\e[0m \e[35mkeyword\e[0m \e[36mstring\e[0m\n'
        printf '\e[91merror\e[0m \e[93mwarning\e[0m \e[92mok\e[0m \e[94minfo\e[0m \e[95mkeyword\e[0m \e[96mstring\e[0m\n'
        printf '\e[1;37mbold white\e[0m \e[1;97mbold bright white\e[0m\n'
      }

      pick() {
        local choice
        # The Stylix fzf colors are the active palette's hex; ANSI colors follow the preview.
        if choice=$(list | FZF_DEFAULT_OPTS="" fzf --color=16 --prompt 'palette> ' \
          --bind "focus:execute-silent($0 {})" \
          --preview "$0 --swatch {}" --preview-window right,60%); then
          echo "kitty-palette: $choice applies until kitty restarts; to keep it, set myTheme.palette = \"$choice\";"
        else
          apply ""
        fi
      }

      case "''${1:-}" in
        "") pick ;;
        -h | --help) usage ;;
        --list) list ;;
        --reset) apply "" ;;
        --swatch) swatch "$2" ;;
        -*) usage >&2; exit 2 ;;
        *)
          if [ ! -f "$confs/$1.conf" ]; then
            echo "kitty-palette: unknown palette '$1' (see --list)" >&2
            exit 2
          fi
          apply "$confs/$1.conf"
          ;;
      esac
    '';
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
    # modules/personal/theme); colors come from ../theme/kitty-colors.nix, fonts from stylix.*.
    programs.kitty = {
      enable = true;
      font = {
        name = stylix.fonts.monospace.name;
        size = stylix.fonts.sizes.terminal;
      };
      settings = kittyColors { inherit colors; lightContrast = lc; }
      // {
        # kitty-palette recolors over this socket (kitty appends -<pid>);
        # $XDG_RUNTIME_DIR is 0700, and socket-only refuses escape-code requests.
        allow_remote_control = "socket-only";
        listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty";

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
    home.packages = [ kittyPalette ];

    # Zsh
    programs.zsh = {
      enable = true;
      autosuggestion = {
        enable = true;
        # Default hint is ANSI 8 (base04), 1.9:1 on catppuccin-latte; light
        # palettes get an ink mix that clears 3:1 as a dim hint.
        highlight = lib.mkIf light "fg=${promptColors.subtle}";
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
