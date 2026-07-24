#!/usr/bin/env bash
# update-hashes.sh — refresh pinned fixed-output (FOD) hashes in this flake.
#
# Mechanism: build each target with `nix build --keep-going`; when Nix reports
# a hash mismatch ("specified: sha256-… / got: sha256-…"), locate the stale
# hash in the repo's .nix files, substitute the real one, and rebuild until
# everything is clean. This handles every FOD kind uniformly: fetchurl,
# fetchFromGitHub, vendorHash, goModules.outputHash, nvidia driver hashes.
#
# Typical workflows:
#   tools/update-hashes.sh --update          # nix flake update, then fix fallout
#                                            # (e.g. gastown goModules outputHash)
#   tools/update-hashes.sh --omp-version 17.1.0
#                                            # bump omp: prefetches all 4 platform
#                                            # binaries, rewrites version + hashes
#   tools/update-hashes.sh --gcx-version 0.3.0
#                                            # bump gcx: resets src/vendor hashes to
#                                            # sentinels, build loop fills them in
#   tools/update-hashes.sh --full            # sweep host toplevels (catches pins
#                                            # not covered by the default targets)
#   tools/update-hashes.sh .#nixosConfigurations.tunguska.pkgs.gcx
#                                            # explicit installables only
#
# Bumping a pin by hand (e.g. the tla-nvim rev in common/neovim.nix): change the
# rev, set the hash to the sentinel below, then run this script. Do NOT leave the
# old hash in place — Nix would reuse the cached store path and never refetch.
# If one derivation has several hash fields, give each a DISTINCT sentinel
# (sha256-AAA…, sha256-BBB…) so replacements can't cross-contaminate.

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
OVERLAY="$REPO_ROOT/overlays/default.nix"
MAX_ITER=20

FAKE_A="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
FAKE_B="sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
EMPTY_HASH="sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="

# Default targets: every attr in this repo that carries a pinned FOD hash.
DEFAULT_TARGETS=(
  ".#nixosConfigurations.tunguska.pkgs.gastown"
  ".#nixosConfigurations.tunguska.pkgs.gcx"
  ".#nixosConfigurations.tunguska.pkgs.omp"
  ".#nixosConfigurations.tunguska.config.hardware.nvidia.package"
  ".#nixosConfigurations.tunguska.config.programs.nixvim.build.package"
)
FULL_TARGETS=(
  ".#nixosConfigurations.tunguska.config.system.build.toplevel"
  ".#nixosConfigurations.oerlikon.config.system.build.toplevel"
)

die() { echo "error: $*" >&2; exit 1; }
log() { echo ">> $*"; }

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# --- hash substitution ------------------------------------------------------

# Replace the first repo occurrence of $1 with $2. Refuses hashes it cannot
# find (they belong to a flake input, not this repo).
replace_hash() {
  local spec=$1 got=$2 loc file line count
  [[ "$spec" == "$EMPTY_HASH" ]] && die \
    "a pin uses hash \"\" — replace it with the sentinel $FAKE_A and re-run"
  loc=$(grep -rnoF --include='*.nix' -- "$spec" "$REPO_ROOT" | head -n1) || true
  [[ -n "$loc" ]] || {
    echo "!! stale hash $spec not found in repo .nix files (from a flake input?); skipping" >&2
    return 1
  }
  file=${loc%%:*}
  line=$(echo "$loc" | cut -d: -f2)
  count=$(grep -rcoF --include='*.nix' -- "$spec" "$REPO_ROOT" | awk -F: '{n+=$2} END {print n}')
  [[ "$count" -gt 1 ]] && echo "!! $spec occurs $count times; replacing first (${file#"$REPO_ROOT"/}:$line) only" >&2
  sed -i "${line}s|$spec|$got|" "$file"
  log "fixed ${file#"$REPO_ROOT"/}:$line  $spec -> $got"
}

# --- build loop -------------------------------------------------------------

build_loop() {
  local -a targets=("$@")
  local iter out fixed spec got
  for ((iter = 1; iter <= MAX_ITER; iter++)); do
    log "build pass $iter: ${targets[*]}"
    if out=$(nix build --no-link --keep-going "${targets[@]}" 2>&1); then
      log "all targets build clean"
      return 0
    fi
    fixed=0
    # Pair up "specified:" / "got:" lines from hash-mismatch errors.
    while read -r spec got; do
      [[ "$spec" == "$got" ]] && continue
      replace_hash "$spec" "$got" && fixed=1 || true
    done < <(awk '/specified:/ {s=$NF} /got:/ && s {print s, $NF; s=""}' <<<"$out")
    if [[ "$fixed" -eq 0 ]]; then
      echo "build failed with no fixable hash mismatch; last lines:" >&2
      tail -n 30 <<<"$out" >&2
      return 1
    fi
  done
  die "did not converge after $MAX_ITER passes (conflicting pins? see header notes)"
}

# --- version bumps ----------------------------------------------------------

bump_omp() {
  local ver=$1 ln url hashline newhash
  log "bumping omp to $ver"
  grep -q 'ompVersion = "' "$OVERLAY" || die "ompVersion pin not found in $OVERLAY"
  sed -i "s|ompVersion = \"[^\"]*\"|ompVersion = \"$ver\"|" "$OVERLAY"
  # Prefetch every release binary; the hash line directly follows each url line.
  grep -n 'url = ".*oh-my-pi/releases/download' "$OVERLAY" | cut -d: -f1 |
    while read -r ln; do
      url=$(sed -n "${ln}s|.*url = \"\([^\"]*\)\".*|\1|p" "$OVERLAY")
      url=${url//\$\{ompVersion\}/$ver}
      hashline=$((ln + 1))
      sed -n "${hashline}p" "$OVERLAY" | grep -q 'hash = "sha256-' ||
        die "expected hash on $OVERLAY:$hashline after url line $ln"
      log "prefetching $url"
      newhash=$(nix store prefetch-file --json "$url" | grep -oP '"hash":"\K[^"]+') ||
        die "prefetch failed for $url"
      sed -i "${hashline}s|sha256-[A-Za-z0-9+/=]\{44\}|$newhash|" "$OVERLAY"
      log "fixed overlays/default.nix:$hashline  -> $newhash"
    done
}

bump_gcx() {
  local ver=$1
  log "bumping gcx to $ver (hashes reset; build loop will fill them in)"
  grep -q 'pname = "gcx"' "$OVERLAY" || die "gcx pin not found in $OVERLAY"
  # Distinct sentinels per field so replace_hash can't cross-contaminate.
  sed -i "/pname = \"gcx\"/,/subPackages/ {
    s|version = \"[^\"]*\"|version = \"$ver\"|
    s|hash = \"sha256-[A-Za-z0-9+/=]\{44\}\"|hash = \"$FAKE_A\"|
    s|vendorHash = \"sha256-[A-Za-z0-9+/=]\{44\}\"|vendorHash = \"$FAKE_B\"|
  }" "$OVERLAY"
}

# --- main -------------------------------------------------------------------

declare -a targets=()
do_update=0 full=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --update) do_update=1 ;;
    --full) full=1 ;;
    --omp-version) shift; bump_omp "${1:?--omp-version needs a value}" ;;
    --gcx-version) shift; bump_gcx "${1:?--gcx-version needs a value}" ;;
    -h|--help) usage ;;
    -*) die "unknown flag: $1 (see --help)" ;;
    *) targets+=("$1") ;;
  esac
  shift
done

[[ "$do_update" -eq 1 ]] && { log "nix flake update"; nix flake update --flake "$REPO_ROOT"; }

if [[ ${#targets[@]} -eq 0 ]]; then
  if [[ "$full" -eq 1 ]]; then targets=("${FULL_TARGETS[@]}"); else targets=("${DEFAULT_TARGETS[@]}"); fi
fi

cd "$REPO_ROOT"
build_loop "${targets[@]}"
