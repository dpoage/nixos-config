# Each palette is `{ pkgs }: { meta, fonts, terminal, colors, upstream, wallpaper? }`.
{
  gruvbox    = import ./gruvbox.nix;
  catppuccin = import ./catppuccin.nix;
}
