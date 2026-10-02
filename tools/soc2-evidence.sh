#!/usr/bin/env bash
# Prints SOC2 / Cyber Essentials manual-evidence state in one screenshot-able
# frame: disk encryption, anti-malware, automatic updates, admin accounts,
# password manager, and firewall. Drata's Linux agent cannot auto-detect these
# on NixOS (see overlays/drata-agent.nix header), so evidence is a terminal
# screenshot uploaded in myDrata. Needs root (luksDump + iptables); the daily
# user is not in wheel, so run0 prompts for root's own password:
#
#   run0 tools/soc2-evidence.sh
#
# Then screenshot the frame and upload it under each evidence request.
set -euo pipefail

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

printf '\033[1mSOC2 evidence — %s — %s\033[0m\n' "$(hostname)" "$(date -R)"

section "Disk encryption (LUKS2 root, random-key swap)"
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT /dev/nvme0n1
cryptsetup luksDump /dev/nvme0n1p3 | sed -n '1,6p'

section "Anti-malware (ClamAV)"
systemctl is-active clamav-daemon.service | xargs echo "clamav-daemon:"
freshclam --version
systemctl list-timers clamav-freshclam.timer clamdscan.timer --no-pager | sed -n '1,3p'

section "Automatic updates (nixos-upgrade, daily)"
nixos-version
systemctl list-timers nixos-upgrade.timer --no-pager | sed -n '1,2p'
systemctl show nixos-upgrade.service -p Result -p ExecMainExitTimestamp

section "Administrator accounts (wheel empty; polkit admin is root)"
getent group wheel
grep -h addAdminRule -A2 /etc/polkit-1/rules.d/*.rules

section "Password manager (Bitwarden)"
# Store path embeds the package version: …-bitwarden-desktop-<ver>/bin/bitwarden
basename "$(dirname "$(dirname "$(readlink -f "$(which bitwarden)")")")" \
  | sed 's/^[a-z0-9]\{32\}-//'

section "Firewall (default-deny inbound, no allowed ports; iptables backend)"
iptables -S INPUT | sed -n '1,2p'
iptables -S nixos-fw

printf '\n\033[1m— captured %s on %s —\033[0m\n' "$(date -R)" "$(hostname)"
