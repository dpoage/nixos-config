# Live palette switching: each myTheme.apps entry is rendered per palette; the app
# reads it through a slot symlink that `theme` re-points by rename, then reloads.
{ config, lib, pkgs, ... }:

let
  cfg = config.myTheme;
  stateDir = "${config.xdg.stateHome}/myTheme";

  appType = lib.types.submodule ({ name, ... }: {
    options = {
      render = lib.mkOption {
        type = lib.types.functionTo (lib.types.either lib.types.str lib.types.package);
        description = ''
          Palette (a myTheme.palettes entry plus `name`) to the slot's content: a
          store path (derivation or string naming one) is linked, other strings are written.
        '';
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "${stateDir}/${name}";
        description = ''
          Absolute path of the slot, the symlink the app reads. Apps that watch
          their file put the slot where they watch; the rest include the default.
        '';
      };
      reload = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Shell run after the slot moves, with $THEME_FILE set to the slot. It
          must succeed when the app is not running; failures are reported.
        '';
      };
    };
  });

  esc = builtins.fromJSON ''"\u001b"'';
  rgb = h: lib.concatMapStringsSep ";" (i: toString (lib.fromHexString (builtins.substring i 2 h))) [ 0 2 4 ];
  reset = "${esc}[0m";
  swatch = name: theme:
    let
      c = theme.colors;
      r = theme.roles;
      row = slots: lib.concatMapStrings (s: "${esc}[48;2;${rgb c.${s}}m    ") slots + reset;
      chip = back: text: "${esc}[48;2;${rgb back};38;2;${rgb c.base00}m ${text} ${reset}";
      on = color: text: "${esc}[48;2;${rgb c.base00};38;2;${rgb color}m ${text} ${reset}";
    in
    ''
      ${name} (${c.variant})

      ${row [ "base00" "base01" "base02" "base03" "base04" "base05" "base06" "base07" ]}
      ${row [ "base08" "base09" "base0A" "base0B" "base0C" "base0D" "base0E" "base0F" ]}
      ${row [ "base12" "base13" "base14" "base15" "base16" "base17" ]}

      ${on c.base05 "body text"}${on r.muted "muted"}${on r.dim "dim"}${on r.hint "hint"}
      ${on r.danger "error"}${on r.warning "warning"}${on (r.fg "base0B") "ok"}${on (r.fg "base0D") "info"}${on (r.fg "base0E") "accent"}
      ${chip (r.fill "base16") "~/code"} ${chip (r.fill "base0B") "main"} ${chip (r.fill "base0A") "~2"} ${chip r.dangerFill "✘ 1"}
    '';

  isLink = v: lib.isDerivation v
    || (builtins.hasContext v && lib.hasPrefix "${builtins.storeDir}/" v && builtins.match "[^\n ]*" v != null);

  # One derivation per palette; a store path per app file would mean hundreds.
  paletteDir = name: theme:
    let
      out = lib.mapAttrs (_: app: app.render (theme // { inherit name; })) cfg.apps;
      texts = lib.filterAttrs (_: v: !isLink v) out // { ".swatch" = swatch name theme; };
      links = lib.filterAttrs (_: isLink) out;
      envName = app: "text_" + builtins.hashString "md5" app;
    in
    pkgs.runCommandLocal "my-theme-${name}"
      (lib.mapAttrs' (app: lib.nameValuePair (envName app)) texts // {
        passAsFile = map envName (lib.attrNames texts);
      })
      ''
        mkdir $out
        ${lib.concatStrings (lib.mapAttrsToList (app: _: ''
          cp "''$${envName app}Path" $out/${lib.escapeShellArg app}
        '') texts)}
        ${lib.concatStrings (lib.mapAttrsToList (app: v: ''
          ln -s ${v} $out/${lib.escapeShellArg app}
        '') links)}
      '';

  tree = pkgs.linkFarm "my-theme" (lib.mapAttrsToList
    (name: theme: { inherit name; path = paletteDir name theme; })
    cfg.palettes);

  apps = lib.attrNames cfg.apps;
  array = xs: "(${lib.escapeShellArgs xs})";

  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = with pkgs; [ coreutils util-linux fzf ];
    text = ''
      tree=${tree}
      state=${lib.escapeShellArg stateDir}
      declared=${lib.escapeShellArg cfg.palette}
      apps=${array apps}
      paths=${array (map (a: cfg.apps.${a}.path) apps)}
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

      reload() {
        case "$1" in
      ${lib.concatMapStrings (a: ''
        ${lib.escapeShellArg a})
      ${if cfg.apps.${a}.reload == "" then ":" else cfg.apps.${a}.reload}
          ;;
      '') apps}
        esac
      }

      usage() {
        cat <<EOF
      Usage: theme [PALETTE | --list | --reset | --status]

      Switch the palette of every running themed app.
        (none)    pick with fzf; moving the cursor previews, Enter keeps, Esc restores
        PALETTE   switch to PALETTE and keep it
        --list    list palettes
        --reset   go back to the declared palette ($declared)
        --status  show the kept and declared palettes
      The kept palette survives restarts and rebuilds until myTheme.palette changes.
      Stylix-themed apps (GTK, Qt, bat, btop, ...) follow myTheme.palette only.
      EOF
      }

      kept() {
        local p
        p=$(cat "$state/palette" 2>/dev/null || true)
        if [ -n "$p" ] && [ -d "$tree/$p" ]; then echo "$p"; else echo "$declared"; fi
      }

      # Re-point every slot at the palette; reload the apps whose slot moved.
      point() {
        local i target
        for i in "''${!apps[@]}"; do
          target="$tree/$1/''${apps[i]}"
          [ "$(readlink "''${paths[i]}" 2>/dev/null || true)" = "$target" ] && continue
          mkdir -p "$(dirname "''${paths[i]}")"
          ln -sfn "$target" "''${paths[i]}.theme-new"
          mv -Tf "''${paths[i]}.theme-new" "''${paths[i]}"
          (
            if ! out=$(THEME_FILE=''${paths[i]} reload "''${apps[i]}" 2>&1); then
              echo "theme: reloading ''${apps[i]} failed: $out" >&2
            fi
          ) &
        done
        wait
      }

      # Rapid previews coalesce: the lock holder applies the latest wanted palette.
      apply() {
        mkdir -p "$state"
        echo "$1" > "$state/want"
        exec 9>"$state/lock"
        flock 9
        point "$(cat "$state/want")"
      }

      keep() {
        apply "$1"
        echo "$1" > "$state/palette"
      }

      check() {
        if [ ! -d "$tree/$1" ]; then
          echo "theme: unknown palette '$1' (see --list)" >&2
          exit 2
        fi
      }

      list() {
        local p
        for p in "$tree"/*; do basename "$p"; done
      }

      status() {
        local k
        k=$(kept)
        echo "kept:     $k"
        echo "declared: $declared"
        if [ "$k" != "$declared" ]; then
          echo "Stylix-themed apps (GTK, Qt, bat, btop, ...) stay on $declared until myTheme.palette = \"$k\";"
        fi
      }

      pick() {
        local k pos choice
        k=$(kept)
        pos=$(list | grep -nxF "$k" | cut -d: -f1)
        # Preview errors go to a log; on the terminal they would tear the picker.
        if choice=$(list | FZF_DEFAULT_OPTS="" fzf --ansi --layout=reverse --prompt 'palette> ' \
          --header "kept: $k · Enter keeps · Esc restores" \
          --bind "load:pos($pos)" \
          --bind "focus:execute-silent($0 --preview {} 2>>$state/preview.log &)" \
          --preview "cat $tree/{}/.swatch" --preview-window right,60%); then
          keep "$choice"
          status
        else
          apply "$k"
        fi
      }

      # Activation: a changed myTheme.palette replaces the kept one; slots of
      # removed apps go.
      activate() {
        local old
        local -A live=()
        mkdir -p "$state"
        if [ "$(cat "$state/declared" 2>/dev/null || true)" != "$declared" ]; then
          echo "$declared" > "$state/declared"
          echo "$declared" > "$state/palette"
        fi
        for old in "''${paths[@]}"; do live[$old]=1; done
        if [ -f "$state/slots" ]; then
          while read -r old; do
            if [ -z "''${live[$old]:-}" ] && [ -L "$old" ]; then rm -f "$old"; fi
          done < "$state/slots"
        fi
        printf '%s\n' "''${paths[@]}" > "$state/slots"
        apply "$(kept)"
      }

      case "''${1:-}" in
        "") pick ;;
        -h | --help) usage ;;
        --list) list ;;
        --status) status ;;
        --reset) keep "$declared"; status ;;
        --preview) check "$2"; apply "$2" ;;
        --activate) activate ;;
        -*) usage >&2; exit 2 ;;
        *) check "$1"; keep "$1"; status ;;
      esac
    '';
  };
in
{
  options.myTheme.apps = lib.mkOption {
    type = lib.types.attrsOf appType;
    default = { };
    description = "Apps whose colors switch live with `theme`, keyed by slot file name.";
  };

  config = lib.mkIf (cfg.apps != { }) {
    home.packages = [ theme ];
    home.activation.myTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe theme} --activate
    '';
  };
}
