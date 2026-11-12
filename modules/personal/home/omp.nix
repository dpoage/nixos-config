# omp follows the palette through a custom theme it watches and reloads itself.
{ config, lib, pkgs, ... }:

let
  ompTheme = import ../theme/omp-theme.nix { inherit lib; };
  name = "stylix";
  ompConfig = "${config.home.homeDirectory}/.omp/agent/config.yml";
in
{
  myTheme.apps.omp = {
    render = theme: builtins.toJSON (ompTheme theme);
    path = "${config.home.homeDirectory}/.omp/agent/themes/${name}.json";
  };

  # omp owns config.yml and rewrites it from its settings UI, so it stays a
  # regular file; point both appearance slots at the theme in place.
  home.activation.ompTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$(dirname ${ompConfig})"
    [ -e ${ompConfig} ] || run touch ${ompConfig}
    run ${lib.getExe pkgs.yq-go} -i \
      '.theme.dark = "${name}" | .theme.light = "${name}"' ${ompConfig}
  '';
}
