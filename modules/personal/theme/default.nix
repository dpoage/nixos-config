{ config, lib, pkgs, ... }:

let
  cfg = config.myTheme;
  graphical = config.services.graphical-desktop.enable;
  colors = config.lib.stylix.colors;

  # base24 schemes carry their own brights (base12-17); base16 ones get `brights`.
  b24 = name: { scheme = "base24/${name}"; };
  b16 = name: { scheme = "base16/${name}"; };
  catppuccinWallpaper = flavour:
    "${pkgs.nixos-artwork.wallpapers."nineish-catppuccin-${flavour}-alt"}/share/backgrounds/nixos/nix-wallpaper-nineish-catppuccin-${flavour}-alt.png";

  # Light palettes mix accents pct% toward `ink`; `red` is the danger slot.
  # Each pct is re-probed per palette: lowest 4.5:1 mix (hint 3:1) within its CIEDE2000 ceiling.
  lightContrastDefaults = {
    ink = "base05";
    red = "base08";
    segment = 70; # starship segments 4.5:1 from 61 (latte); kitty url from 19
    hint = 70; # autosuggest hint 3:1 from 64 (latte)
    label = 70; # waybar labels 4.5:1 from 67 (latte)
    dim = 80; # 4.5:1 from 75 (latte)
    warning = 60; # 4.5:1 from 57 (latte); CIEDE2000 >= 10 vs #disk up to 62 (gruvbox-light)
    critical = 25; # 4.5:1 from 13 (also base00 on the urgent chip), CIEDE2000 >= 15 vs the same module's label up to 37 (gruvbox-light)
    selectionMatch = 60; # fuzzel, on base02: 4.5:1 from 36 (gruvbox-light), CIEDE2000 >= 10 vs ink up to 86 (latte)
    match = 0; # fuzzel, on base00
  };
  light = contrast: { inherit contrast; };

  palettes = {
    gruvbox-dark = b24 "gruvbox-dark";
    gruvbox-light = b24 "gruvbox-light";
    catppuccin-mocha = b24 "catppuccin-mocha" // { wallpaper = catppuccinWallpaper "mocha"; };
    catppuccin-latte = b24 "catppuccin-latte" // { wallpaper = catppuccinWallpaper "latte"; };
    tokyo-night-dark = b24 "tokyo-night-dark";
    tokyo-night-storm = b24 "tokyo-night-storm";
    tokyo-night-moon = b24 "tokyo-night-moon";
    # base08 is the navy variables color here; base12 is the red.
    tokyo-night-light = b24 "tokyo-night-light" // light { red = "base12"; warning = 45; critical = 8; };
    kanagawa = b16 "kanagawa";
    kanagawa-dragon = b24 "kanagawa-dragon";
    rose-pine = b16 "rose-pine";
    rose-pine-moon = b16 "rose-pine-moon";
    # No critical mix reaches CIEDE2000 15 vs pulseaudio's rose; contrast wins.
    rose-pine-dawn = b16 "rose-pine-dawn" // light { warning = 65; critical = 30; match = 30; };
    nord = b16 "nord";
    nord-light = b16 "nord-light" // light { critical = 10; };
    dracula = b24 "dracula";
    # base24/builtin-solarized-* are terminal dumps, not base16 layouts (light
    # body text is 1.9:1; dark base02 equals base00).
    solarized-dark = b16 "solarized-dark";
    # base05 is too weak (4.4:1 on base01) to mix toward.
    solarized-light = b16 "solarized-light" // light { ink = "base07"; selectionMatch = 65; match = 5; };
    everforest-dark-hard = b16 "everforest-dark-hard";
    # base16/everforest-dark-medium shifts the slots (base05 is grey1); this is the same palette.
    everforest-dark-medium = b16 "everforest";
    everforest-dark-soft = b16 "everforest-dark-soft";
    # Mixing toward base05 needs 80-90% (soft: unreachable), so ink is base07.
    everforest-light-hard = b16 "everforest-light-hard" // light { ink = "base07"; critical = 30; match = 25; };
    everforest-light-medium = b16 "everforest-light-medium" // light { ink = "base07"; critical = 35; match = 30; };
    everforest-light-soft = b16 "everforest-light-soft" // light { ink = "base07"; critical = 45; match = 40; };
    gruvbox-material-dark-hard = b16 "gruvbox-material-dark-hard";
    gruvbox-material-dark-medium = b16 "gruvbox-material-dark-medium";
    gruvbox-material-dark-soft = b16 "gruvbox-material-dark-soft";
    # Toward base05, critical/selectionMatch floors exceed their CIEDE2000 ceilings.
    gruvbox-material-light-hard = b16 "gruvbox-material-light-hard" // light { ink = "base07"; match = 5; };
    gruvbox-material-light-medium = b16 "gruvbox-material-light-medium" // light { ink = "base07"; match = 5; };
    gruvbox-material-light-soft = b16 "gruvbox-material-light-soft" // light { ink = "base07"; match = 15; };
  };
  p = palettes.${cfg.palette};
  # Stylix's YAML parser fails on comment-only lines, which some upstream schemes
  # (dracula) have; drop them before handing the scheme over.
  schemeFile = name: builtins.toFile "${name}.yaml" (builtins.unsafeDiscardStringContext
    (lib.concatMapStrings (line: line + "\n")
      (builtins.filter (line: builtins.match " *#.*" line == null)
        (lib.splitString "\n" (builtins.readFile "${config.stylix.inputs.tinted-schemes}/${palettes.${name}.scheme}.yaml")))));

  # Stylix fills a base16 scheme's missing base12-17 with the normal colors, so
  # ANSI 9-14 would equal 1-6. Derive them a quarter of the way toward white
  # (dark schemes) or black (light schemes), as base24 schemes like gruvbox do.
  mix = import ./mix.nix { inherit lib; };
  brights = base:
    lib.mapAttrs
      (_: normal: mix.mixHex {
        from = base.${normal};
        toward = if base.variant == "light" then "000000" else "ffffff";
        pct = 25;
      })
      {
        base12 = "base08";
        base13 = "base0A";
        base14 = "base0B";
        base15 = "base0C";
        base16 = "base0D";
        base17 = "base0E";
      };

  schemeOverride = name:
    lib.optionalAttrs (lib.hasPrefix "base16/" palettes.${name}.scheme) (brights (config.stylix.base16.mkSchemeAttrs (schemeFile name)))
    // lib.optionalAttrs (name == "gruvbox-dark") { base00 = "1d2021"; };

  # What Stylix's lib.stylix.colors would be with each palette active, for the
  # kitty-palette live preview.
  paletteThemes = lib.mapAttrs
    (name: palette: {
      colors = (config.stylix.base16.mkSchemeAttrs (schemeFile name)).override (schemeOverride name);
      lightContrast = lightContrastDefaults // (palette.contrast or { });
    })
    palettes;

  generatedWallpaper = pkgs.runCommand "wallpaper-${cfg.palette}.png"
    { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick -size 3840x2160 'radial-gradient:#${colors.base01}-#${colors.base00}' \
        \( -background none -density 300 \
           ${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg \
           -resize 900x900 -fill '#${colors.base09}' -colorize 100 \) \
        -gravity center -composite $out
    '';

  # Headless hosts run with autoEnable off and only these terminal targets.
  terminalTargets = [ "bat" "btop" "fzf" "starship" "tmux" "yazi" "lazygit" "k9s" "vivid" ];
in
{
  options.myTheme.palette = lib.mkOption {
    type = lib.types.enum (lib.attrNames palettes);
    default = "catppuccin-mocha";
    description = "Palette Stylix themes the host with.";
  };

  config = {
    stylix = {
      enable = true;
      base16Scheme = schemeFile cfg.palette;
      override = schemeOverride cfg.palette;
      polarity = colors.variant;
      image = lib.mkIf graphical (p.wallpaper or generatedWallpaper);

      fonts = {
        monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; };
        sansSerif = { package = pkgs.noto-fonts; name = "Noto Sans"; };
        serif = { package = pkgs.noto-fonts; name = "Noto Serif"; };
        emoji = { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };
        sizes.terminal = 12;
      };
      opacity.terminal = 0.92;

      cursor = lib.mkIf graphical {
        package = pkgs.bibata-cursors;
        name = if config.stylix.polarity == "light" then "Bibata-Modern-Ice" else "Bibata-Modern-Classic";
        size = 24;
      };
      icons = {
        enable = graphical;
        package = pkgs.papirus-icon-theme;
        dark = "Papirus-Dark";
        light = "Papirus-Light";
      };

      autoEnable = graphical;

      targets = {
        # Own the 16 ANSI colors: the target maps bright to normal.
        console.enable = false;
        # Upstream colorscheme plugins are configured in neovim.nix.
        nixvim.enable = false;
        # Enables programs.chromium and writes /etc/{brave,chromium,opt/chrome}
        # policies/managed/extra.json, so browsers show "managed by your organisation".
        chromium.enable = false;
      };
    };

    console.colors = import ./ansi.nix colors;

    home-manager.sharedModules = [
      {
        stylix.targets = {
          # kitty/alacritty colors come from ./ansi.nix; fonts and opacity from stylix.*.
          kitty.enable = false;
          alacritty.enable = false;
          # Installs a GNOME Shell extension; gtk.colorScheme below carries polarity.
          gnome.enable = false;
          # No Plasma here; installs a KDE theme activator (autostart entry and
          # activation script). Qt apps are themed by the qt target.
          kde.enable = false;
        } // lib.genAttrs terminalTargets (_: { enable = true; });

        gtk.colorScheme = lib.mkIf graphical config.stylix.polarity;
      }
      {
        options.myTheme = {
          lightContrast = lib.mkOption {
            type = lib.types.attrs;
            readOnly = true;
            description = "Ink slot, red slot and accent mix percentages for the active palette when it is light.";
          };
          palettes = lib.mkOption {
            type = lib.types.attrsOf lib.types.attrs;
            readOnly = true;
            description = "Every selectable palette's Stylix colors set and lightContrast, keyed by myTheme.palette name.";
          };
        };
        config.myTheme = {
          lightContrast = paletteThemes.${cfg.palette}.lightContrast;
          palettes = paletteThemes;
        };
      }
    ];
  };
}
