{ config, lib, pkgs, ... }:

let
  cfg = config.myTheme;
  graphical = config.services.graphical-desktop.enable;
  colors = config.lib.stylix.colors;

  palettes = {
    gruvbox-dark = { scheme = "gruvbox-dark"; };
    catppuccin-mocha = {
      scheme = "catppuccin-mocha";
      wallpaper = "${pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha-alt}/share/backgrounds/nixos/nix-wallpaper-nineish-catppuccin-mocha-alt.png";
    };
  };
  p = palettes.${cfg.palette};

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
      base16Scheme = "${config.stylix.inputs.tinted-schemes}/base24/${p.scheme}.yaml";
      override = lib.mkIf (cfg.palette == "gruvbox-dark") { base00 = "1d2021"; };
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
        name = "Bibata-Modern-Classic";
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
        # Upstream gruvbox/catppuccin plugins are configured in neovim.nix.
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
    ];
  };
}
