# Home-manager surfaces with no owning module of their own, themed from
# osConfig.myTheme. Program modules that exist elsewhere theme themselves.
{ osConfig, lib, pkgs, ... }:

let
  t = osConfig.myTheme;
  c = t.colors;
  dark = t.meta.variant == "dark";

  # libadwaita (GTK 4) and adw-gtk3 (GTK 3) both read these named colors.
  gtkCss = ''
    @define-color accent_color #${c.accent};
    @define-color accent_bg_color #${c.accent};
    @define-color accent_fg_color #${c.bg};
    @define-color destructive_color #${c.redBr};
    @define-color destructive_bg_color #${c.red};
    @define-color destructive_fg_color #${c.fg0};
    @define-color success_color #${c.greenBr};
    @define-color success_bg_color #${c.green};
    @define-color success_fg_color #${c.bg};
    @define-color warning_color #${c.yellowBr};
    @define-color warning_bg_color #${c.yellow};
    @define-color warning_fg_color #${c.bg};
    @define-color error_color #${c.redBr};
    @define-color error_bg_color #${c.red};
    @define-color error_fg_color #${c.fg0};
    @define-color window_bg_color #${c.bg};
    @define-color window_fg_color #${c.fg};
    @define-color view_bg_color #${c.bg0};
    @define-color view_fg_color #${c.fg};
    @define-color headerbar_bg_color #${c.bg0};
    @define-color headerbar_fg_color #${c.fg};
    @define-color headerbar_border_color #${c.bg2};
    @define-color headerbar_backdrop_color @window_bg_color;
    @define-color headerbar_shade_color rgba(0, 0, 0, 0.36);
    @define-color sidebar_bg_color #${c.bg0};
    @define-color sidebar_fg_color #${c.fg};
    @define-color sidebar_backdrop_color @window_bg_color;
    @define-color sidebar_shade_color rgba(0, 0, 0, 0.36);
    @define-color card_bg_color #${c.bg1};
    @define-color card_fg_color #${c.fg};
    @define-color card_shade_color rgba(0, 0, 0, 0.36);
    @define-color dialog_bg_color #${c.bg1};
    @define-color dialog_fg_color #${c.fg};
    @define-color popover_bg_color #${c.bg1};
    @define-color popover_fg_color #${c.fg};
    @define-color popover_shade_color rgba(0, 0, 0, 0.36);
    @define-color thumbnail_bg_color #${c.bg1};
    @define-color thumbnail_fg_color #${c.fg};
    @define-color shade_color rgba(0, 0, 0, 0.36);
    @define-color scrollbar_outline_color rgba(0, 0, 0, 0.5);
  '';

  btopTheme = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''theme[${k}]="#${v}"'') {
    main_bg = c.bg; main_fg = c.fg; title = c.fg; hi_fg = c.accent;
    selected_bg = c.bg2; selected_fg = c.accentSecond; inactive_fg = c.bg4;
    graph_text = c.fg2; meter_bg = c.bg2; proc_misc = c.accentTri; div_line = c.bg3;
    cpu_box = c.blueBr; mem_box = c.greenBr; net_box = c.purpleBr; proc_box = c.accent;
    temp_start = c.greenBr; temp_mid = c.yellowBr; temp_end = c.redBr;
    cpu_start = c.aquaBr; cpu_mid = c.blueBr; cpu_end = c.purpleBr;
    free_start = c.aqua; free_mid = c.aquaBr; free_end = c.greenBr;
    cached_start = c.blue; cached_mid = c.blueBr; cached_end = c.aquaBr;
    available_start = c.yellow; available_mid = c.yellowBr; available_end = c.orangeBr;
    used_start = c.orange; used_mid = c.orangeBr; used_end = c.redBr;
    download_start = c.green; download_mid = c.greenBr; download_end = c.aquaBr;
    upload_start = c.purple; upload_mid = c.purpleBr; upload_end = c.redBr;
    process_start = c.greenBr; process_mid = c.yellowBr; process_end = c.redBr;
  });
in
{
  config = lib.mkMerge [
    {
      programs.bat = {
        enable = true;
        config.theme = t.upstream.bat;
      };

      programs.btop = {
        enable = true;
        themes.palette = btopTheme;
        settings = {
          color_theme = "palette";
          theme_background = false;
        };
      };
    }

    (lib.mkIf osConfig.services.graphical-desktop.enable {
      gtk = {
        enable = true;
        colorScheme = t.meta.variant;
        theme = {
          name = if dark then "adw-gtk3-dark" else "adw-gtk3";
          package = pkgs.adw-gtk3;
        };
        iconTheme = {
          name = if dark then "Papirus-Dark" else "Papirus-Light";
          package = pkgs.papirus-icon-theme;
        };
        gtk3.extraCss = gtkCss;
        # libadwaita ignores themes; colors come from gtk.css alone.
        gtk4.theme = null;
        gtk4.extraCss = gtkCss;
      };

      qt = {
        enable = true;
        platformTheme.name = "gtk3";
      };
    })
  ];
}
