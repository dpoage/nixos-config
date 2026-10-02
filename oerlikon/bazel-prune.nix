# Hourly cap on Bazel disk usage. Nothing in Bazel bounds output bases (one
# per workspace path, so one per agent-slice worktree, ~5-8G each) or
# --disk_cache dirs (100G in four days of agent rounds), and the apollo dev
# containers set their own --output_user_root/--disk_cache under the mounted
# worktree, so a bazelrc flag on the host cannot reach them. This prunes
# from outside, which works no matter how a container was started.
#
#   - output bases: removed when command.log is untouched for staleDays
#     (Bazel's server exits after 3h idle by default, so nothing is live)
#   - disk caches: once a cache is over capGiB, the oldest-mtime blobs are
#     deleted until it is at 80% of the cap (Bazel touches mtime on cache
#     hits, so this is LRU). A missing blob is just a cache miss.
{ pkgs, ... }:

let
  staleDays = 3;
  capGiB = 100;

  # Globs, expanded by the script. Output-base roots contain <md5>/ dirs.
  outputRoots = [
    "/data/cache/bazel"
    "/data/ApolloCache/bazel"
    "/data/ApolloCache/bazel-review-b"
    "/data/code/apollo/.cache/bazel"
    "/data/code/apollo-wt/*/.cache/bazel"
  ];
  diskCaches = [
    "/data/cache/build"
    "/data/cache/bazel-disk-*"
    "/data/ApolloCache/build"
    "/data/code/apollo/.cache/build"
    "/data/code/apollo-wt/*/.cache/build"
  ];

  prune = pkgs.writeShellApplication {
    name = "bazel-cache-prune";
    runtimeInputs = with pkgs; [ coreutils findutils gawk ];
    text = ''
      shopt -s nullglob
      dry=''${DRY_RUN:-0}
      cap=$(( ${toString capGiB} * 1024 * 1024 * 1024 ))
      target=$(( cap * 8 / 10 ))

      for root in ${toString outputRoots}; do
        [ -d "$root" ] || continue
        for ob in "$root"/*/; do
          ob=''${ob%/}
          [[ $(basename "$ob") =~ ^[0-9a-f]{32}$ ]] || continue
          stamp="$ob/command.log"
          [ -e "$stamp" ] || stamp="$ob"
          if [ -z "$(find "$stamp" -maxdepth 0 -mtime -${toString staleDays})" ]; then
            echo "expunge $ob ($(du -sh "$ob" | cut -f1))"
            if [ "$dry" = 0 ]; then
              chmod -R u+w "$ob"
              rm -rf "$ob"
            fi
          fi
        done
      done

      for dc in ${toString diskCaches}; do
        [ -d "$dc" ] || continue
        used=$(du -sb "$dc" | cut -f1)
        [ "$used" -gt "$cap" ] || continue
        echo "trim $dc: $(( used >> 30 ))G > ${toString capGiB}G"
        find "$dc" -type f -printf '%T@ %s %p\n' | sort -n |
          awk -v excess=$(( used - target )) '{ if (freed >= excess) exit; freed += $2; sub(/^[^ ]+ [^ ]+ /, ""); print }' |
          if [ "$dry" = 0 ]; then xargs -r -d '\n' rm -f; else wc -l | sed 's/$/ files would be removed/'; fi
      done
    '';
  };
in
{
  home.packages = [ prune ];

  systemd.user.services.bazel-cache-prune = {
    Unit.Description = "Cap Bazel output bases and disk caches";
    Service = {
      Type = "oneshot";
      ExecStart = "${prune}/bin/bazel-cache-prune";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.bazel-cache-prune = {
    Unit.Description = "Hourly Bazel cache cap";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
