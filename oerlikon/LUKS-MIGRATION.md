# oerlikon disk encryption

Status record, not a runbook. The original in-place `cryptsetup reencrypt`
runbook that lived in this file is obsolete: the root disk was instead wiped
and reinstalled as LUKS2 + btrfs (see `hardware-configuration.nix`, commit
63d6cac). This file records what is encrypted, how to capture SOC2 evidence,
and what remains.

## Current state

| Device      | Contents        | Encryption                                    |
| ----------- | --------------- | --------------------------------------------- |
| nvme0n1p1   | /boot (ESP)     | none (bootloader + kernels only, by design)   |
| nvme0n1p3   | root btrfs      | LUKS2, unlocked in stage 1                    |
| nvme0n1p2   | swap            | randomEncryption (fresh key per boot), `luks.nix` |
| nvme1n1p1   | /data ext4      | **none — pending** (see below)                |

Policy on top of the installer layout lives in `luks.nix`: `allowDiscards`
for root, and swap `mkForce`d to by-partuuid with `randomEncryption`
(no hibernation is configured on this host, so resume-from-swap is not
needed).

## One-time swap wipe

Before (or right after) the first boot with the `randomEncryption` swap
config, discard the old plaintext swap contents — pages written while swap
ran unencrypted stay readable on flash until overwritten:

```sh
sudo swapoff /dev/nvme0n1p2
sudo blkdiscard -f /dev/nvme0n1p2
# then reboot into the new generation; the encrypted swap unit re-creates it
```

## Drata evidence capture

Drata's Linux agent cannot read LUKS state, so encryption evidence is a
manual upload (see
<https://help.drata.com/en/articles/5014509-computer-configuration-via-ubuntu-linux>).

1. In one terminal frame, run `date`, `lsblk -f`, and
   `sudo cryptsetup luksDump /dev/nvme0n1p3 | head -n 20` so the date, the
   `crypto_LUKS` line, and the header are visible together.
2. Screenshot that frame.
3. Upload the screenshot in myDrata under the disk-encryption evidence
   request for this device.

## Pending: /data (nvme1n1p1)

Secondary drive is plain ext4. Encrypting it needs an unmount + either
`cryptsetup reencrypt --encrypt --reduce-device-size 32M` in place (backup
first; the fs must be shrunk by at least 32 MiB before reencrypt or the tail
is silently destroyed) or a copy-off/mkfs/copy-back. Note nc-lix: this NVMe
already throws ext4 EIO after D3cold resume — take a full backup before any
in-place rewrite, and consider fixing the resume issue first.
