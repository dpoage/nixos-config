#!/usr/bin/env bash
# Evaluate every host plus the Pattern-layer example, and build the flake-input
# packages cache.nixos.org lacks. pattern-cli is a private git+ssh input; an
# empty stub stands in so this runs without credentials. Evaluation warnings
# are echoed as GitHub annotations rather than failing the check.
set -euo pipefail
cd "$(dirname "$0")/.."

stub=(--override-input pattern-cli path:./ci/pattern-cli-stub)
log=$(mktemp)
trap 'rm -f "$log"' EXIT

eval_drv() {
  local name=$1 attr=$2 status=0
  echo ">> evaluating $name"
  nix eval --raw --option allow-import-from-derivation false "${stub[@]}" \
    ".#$attr.drvPath" 2>"$log" || status=$?
  cat "$log" >&2
  grep -h 'evaluation warning:' "$log" | sed "s/^/::warning title=$name::/" || true
  [ "$status" -eq 0 ] || exit "$status"
  echo
}

hosts=$(nix eval --raw "${stub[@]}" .#nixosConfigurations \
  --apply 'cs: builtins.concatStringsSep " " (builtins.attrNames cs)')
for host in $hosts; do
  eval_drv "$host" "nixosConfigurations.$host.config.system.build.toplevel"
done

# Fails if modules/pattern depends on the personal layer or on dpoage.
eval_drv patternlabs-example checks.x86_64-linux.patternlabs-example

echo ">> building beads and omp"
nix build --no-link --print-build-logs "${stub[@]}" \
  .#nixosConfigurations.tunguska.pkgs.beads \
  .#nixosConfigurations.tunguska.pkgs.omp
