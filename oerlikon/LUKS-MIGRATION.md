# oerlikon LUKS migration

This runbook converts oerlikon's plain ext4 root to LUKS2 in place with
`cryptsetup reencrypt`. No reinstall; the filesystem and its UUID survive.
Swap moves to per-boot random-key encryption via `./luks.nix`.

Device facts (from `oerlikon/hardware-configuration.nix`):

| Role  | Filesystem | UUID |
| ----- | ---------- | ---- |
| root  | ext4       | `1b18e291-a3f4-4664-bb25-98c327ab0dd3` |
| /boot | vfat (ESP) | `C368-29C8` — stays unencrypted |
| swap  | swap       | `b70b0ab7-2e29-4420-bb29-16068ed1a790` |

Run every command as root. The migration changes device identities, so each
section derives its own `$ROOT` and `$SWAP` variables. Do not reuse a
variable across a reboot or a new shell; re-run the identification step of
the current section instead.

WARNING: after section 3 starts, never derive `$ROOT` from the ext4 UUID
`1b18e291-…`. During the migration that symlink disappears, and once the
LUKS mapping is open the symlink points at `/dev/mapper/cryptroot` — a
device on which `cryptsetup` header commands fail.

## 1. Preconditions

WARNING: `cryptsetup reencrypt --encrypt` rewrites every sector. There is no
undo. The backup below is the only full rollback path (see section 7).

- A full backup of oerlikon exists, and a test restore of sample files
  succeeded.
- A NixOS live USB (25.05 or newer) is available. The live ISO ships
  cryptsetup 2.x and e2fsprogs.
- A second USB drive (or a reachable remote machine) is available for the
  LUKS header backup in section 3.
- oerlikon is connected to AC power. Reencryption of a ~1 TB disk runs for
  hours.
- The root filesystem is unmounted. Boot the live USB and stay in the live
  environment; do not mount the root partition before section 4.

## 2. Shrink the root filesystem

The encryption needs the last 32 MiB of the partition to be free of
filesystem data: `--reduce-device-size 32M` (twice the header size, the
documented recommended minimum, cryptsetup-reencrypt(8)) places a 16 MiB
LUKS2 header at the front and shifts the data backwards by 16 MiB, staging
segments through the 32 MiB tail. The filesystem must first release those
32 MiB.

WARNING: a power or system crash during `resize2fs` can corrupt the
filesystem, and the resize2fs undo file cannot survive a crash
(resize2fs(8)). The section 1 backup is the mitigation.

1. Resolve the root partition device. This derivation works only now, while
   the partition still carries a plain ext4 signature:

   ```console
   # ROOT=$(readlink -f /dev/disk/by-uuid/1b18e291-a3f4-4664-bb25-98c327ab0dd3)
   # echo "$ROOT"
   ```

2. Check the filesystem. `resize2fs` refuses to shrink a filesystem that was
   not checked immediately before:

   ```console
   # e2fsck -f "$ROOT"
   ```

3. Compute the new size: current block count minus 32 MiB worth of blocks.
   Confirm the block size first; ext4 defaults to 4096 bytes, and
   32 MiB / 4096 = 8192 blocks. If the block size differs, divide 33554432 by
   the block size instead.

   ```console
   # tune2fs -l "$ROOT" | grep -E '^Block (count|size):'
   # BLOCKS=$(tune2fs -l "$ROOT" | awk '/^Block count:/ {print $3}')
   ```

4. Shrink. A bare number passed to `resize2fs` is in filesystem-blocksize
   units (resize2fs(8)):

   ```console
   # resize2fs "$ROOT" $((BLOCKS - 8192))
   ```

## 3. Encrypt in place

WARNING: `cryptsetup reencrypt` does not check for filesystem data in the
partition tail. On an unshrunk filesystem the command exits 0 and silently
destroys the last 32 MiB. Do not run step 2 before step 1 prints `SHRUNK-OK`.

1. Assert the shrink. The check compares the real partition size against the
   filesystem size and does not depend on variables from section 2. If this
   is a fresh shell, derive `$ROOT` with section 2 step 1 first — the
   partition carries the ext4 signature until step 2 below runs:

   ```console
   # BS=$(tune2fs -l "$ROOT" | awk '/^Block size:/ {print $3}')
   # FSBLOCKS=$(tune2fs -l "$ROOT" | awk '/^Block count:/ {print $3}')
   # test $(( $(blockdev --getsize64 "$ROOT") - FSBLOCKS * BS )) -ge 33554432 && echo SHRUNK-OK
   ```

   If the command does not print `SHRUNK-OK`, stop. The tail still holds
   filesystem data. Return to section 2. The check assumes `$ROOT` is the
   ext4 device from section 2: on a non-ext4 device `tune2fs` fails, the
   arithmetic degenerates, and `SHRUNK-OK` prints spuriously — cryptsetup's
   refusal to `--encrypt` an already-LUKS device is the only backstop.

2. Encrypt. `cryptsetup reencrypt --encrypt` initializes in-place
   encryption; LUKS2 is the default format in cryptsetup 2.x. The command
   asks for the new passphrase:

   ```console
   # cryptsetup reencrypt --encrypt --reduce-device-size 32M "$ROOT"
   ```

   Interruption safety (cryptsetup-reencrypt(8)):

   - Ctrl+C or SIGTERM interrupts the operation safely.
   - To resume, run the same command again with the same options.
     `--reduce-device-size` selects the datashift resilience mode, so the
     resume must not change resilience options.
   - If the machine crashes or loses power mid-operation, recovery runs
     automatically on the next `cryptsetup open`, or explicitly via
     `cryptsetup repair "$ROOT"`.

   Resume from a fresh shell: the ext4 by-uuid symlink is gone once the
   operation starts, so re-derive the device from its LUKS signature and
   cross-check the size before you resume:

   ```console
   # ROOT=$(blkid -t TYPE=crypto_LUKS -o device)
   # lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS "$ROOT"
   ```

   Expect exactly one device: the large (~950 GiB) root partition on the
   internal NVMe, `FSTYPE` `crypto_LUKS`, no mountpoint. If `blkid` prints
   more than one line (another encrypted disk is attached), pick the
   internal NVMe root partition explicitly.

3. Back up the LUKS header as soon as the reencryption completes:

   ```console
   # cryptsetup luksHeaderBackup "$ROOT" --header-backup-file /root/oerlikon-luks-header.img
   ```

   Copy the file to the second USB drive or `scp` it to another machine.
   Do not leave the only copy on oerlikon's own disk. Treat the file like a
   credential: together with the passphrase it unlocks the disk. The backup
   restores the header if a later step (for example a mistyped `wipefs`)
   destroys it: `cryptsetup luksHeaderRestore "$ROOT" --header-backup-file <file>`.

## 4. Fill in the config and rebuild

1. Identify the devices (safe mid-migration derivations):

   ```console
   # ROOT=$(blkid -t TYPE=crypto_LUKS -o device)
   # SWAP=$(readlink -f /dev/disk/by-uuid/b70b0ab7-2e29-4420-bb29-16068ed1a790)
   # lsblk -o NAME,SIZE,FSTYPE "$ROOT" "$SWAP"
   ```

   Expect: `$ROOT` is the large `crypto_LUKS` partition, `$SWAP` the small
   `swap` partition. The swap by-uuid symlink stays valid until step 5 wipes
   the signature.

2. Unlock and mount the encrypted root plus the ESP:

   ```console
   # cryptsetup open "$ROOT" cryptroot
   # mount /dev/mapper/cryptroot /mnt
   # mount /dev/disk/by-uuid/C368-29C8 /mnt/boot
   ```

3. Collect the two identifiers:

   ```console
   # cryptsetup luksUUID "$ROOT"
   # lsblk -no PARTUUID "$SWAP"
   ```

4. Edit `/mnt/home/dpoage/code/nixos-config`:
   - In `oerlikon/luks.nix`, replace `@LUKS_UUID@` with the `luksUUID` output
     and `@SWAP_PARTUUID@` with the `PARTUUID` output.
   - In `oerlikon/default.nix`, add `./luks.nix` to `imports`.

   `hardware-configuration.nix` stays untouched: `nixos-generate-config`
   regenerates that file, so `luks.nix` overrides its `swapDevices` with
   `lib.mkForce` instead. Its `fileSystems."/"` entry also stays correct —
   the ext4 UUID survived the reencrypt, and after unlock the by-uuid symlink
   points at `/dev/mapper/cryptroot`.

5. Retire the old plaintext swap. Two separate problems: the old `swap`
   signature (plus its `b70b0ab7-…` UUID) must go because the new config
   references the partition by PARTUUID, and the old swap *contents* must go
   because up to ~8.8 GiB of historical plaintext pages remain readable
   data-at-rest — `randomEncryption` encrypts future writes and never
   overwrites old sectors.

   WARNING: `wipefs --all` against the wrong variable destroys the LUKS
   header on `$ROOT`. Gate on the signature check below; the section 3
   header backup is the recovery if the gate is skipped and the header dies.

   ```console
   # blkid "$SWAP"
   ```

   The output must show `TYPE="swap"`. If it shows `crypto_LUKS` or anything
   else, `$SWAP` points at the wrong device — stop and redo step 1. If you
   re-enter this step after a partial wipe, the swap by-uuid derivation in
   step 1 no longer resolves; find the partition with
   `lsblk -o NAME,SIZE,FSTYPE,PARTUUID` instead (the small partition next to
   the `crypto_LUKS` root).

   ```console
   # wipefs --all "$SWAP"
   # blkdiscard "$SWAP"
   ```

   `blkdiscard` discards every sector of the NVMe partition, dropping the
   old plaintext pages. If `blkdiscard` fails (`BLKDISCARD ioctl failed`),
   overwrite instead:

   ```console
   # dd if=/dev/urandom of="$SWAP" bs=1M status=progress
   ```

   `dd` ends with `No space left on device` when the partition is full.
   That error is the success condition here.

6. Build the new boot generation from inside the mounted system:

   ```console
   # nixos-enter --root /mnt -c 'nixos-rebuild boot --flake /home/dpoage/code/nixos-config#oerlikon'
   ```

   If nix reports a git "dubious ownership" error, run
   `git config --global --add safe.directory /home/dpoage/code/nixos-config`
   inside the chroot and retry.

7. Exit, unmount, and reboot:

   ```console
   # umount -R /mnt
   # cryptsetup close cryptroot
   # reboot
   ```

## 5. Verify

1. On the first boot, stage 1 prints the scripted-initrd prompt
   (`boot.initrd.systemd.enable` is off in this config):

   ```text
   Passphrase for /dev/disk/by-uuid/<the LUKS UUID from section 4>:
   ```

   The passphrase unlocks the disk and boot continues to the greeter.

2. After login, re-derive the root partition — this is a fresh shell, and
   the pre-boot derivations are stale:

   ```console
   # ROOT=/dev/$(lsblk -no PKNAME /dev/mapper/cryptroot)
   # echo "$ROOT"
   ```

3. Confirm the block layout:

   ```console
   # lsblk -f
   ```

   Expected: the root partition shows `crypto_LUKS` with an ext4 `cryptroot`
   mapper child mounted at `/`; the swap partition shows a dm-crypt child.

4. Confirm swap runs on the mapper device, not the raw partition:

   ```console
   # swapon --show
   ```

5. Confirm the LUKS2 header, and confirm the reencryption is complete:

   ```console
   # cryptsetup luksDump "$ROOT" | head -n 20
   ```

   The `Version` field must show `2`. The header section must NOT contain
   `Requirements: online-reencrypt-v2` — that flag means the device is only
   partially encrypted. If the flag is present, resume section 3 step 2 and
   verify again.

## 6. Drata evidence capture

Drata's Linux agent cannot read LUKS state, so encryption evidence is a
manual upload (see
<https://help.drata.com/en/articles/5014509-computer-configuration-via-ubuntu-linux>).

Capture the evidence in the same booted shell as section 5, with `$ROOT`
from section 5 step 2. Do not capture evidence while
`Requirements: online-reencrypt-v2` shows in `luksDump` — a partially
encrypted disk is not a passing control.

1. In one terminal frame, run `date`, `lsblk -f`, and
   `cryptsetup luksDump "$ROOT" | head -n 20` so the date, the
   `crypto_LUKS` line, and the requirement-free header are visible together.
2. Screenshot that frame.
3. Upload the screenshot in myDrata under the disk-encryption evidence
   request for this device.

## 7. Rollback

`cryptsetup reencrypt --encrypt` has no clean undo. Do not attempt
`--decrypt` as a rollback; treat the operation as one-way.

WARNING: after section 3, every pre-migration generation in the systemd-boot
menu is dead. Their initrds contain no cryptsetup, wait ~20 s in stage 1 for
the ext4 by-uuid device that no longer appears, then drop to the stage-1
error menu. The generation menu is NOT a rollback path. (A generation that
does unlock the root but still references the old swap by-uuid also stalls
~90 s on the dead swap device unit before boot continues.)

- Reencryption interrupted (Ctrl+C, crash, power loss): not a failure.
  Resume as described in section 3 step 2, including the fresh-shell
  re-derivation.
- First boot fails or hangs in stage 1 (typo in `luks.nix`, wrong UUID):
  the data is intact. Boot the live USB, re-derive
  `ROOT=$(blkid -t TYPE=crypto_LUKS -o device)`, then prove the data:

  ```console
  # cryptsetup open "$ROOT" cryptroot
  # mount /dev/mapper/cryptroot /mnt
  # ls /mnt/home
  ```

  Then redo section 4 from step 2 (fix the config, rebuild, reboot). The
  swap by-uuid symlink is gone at this point; if the swap PARTUUID needs a
  re-check, read it from `lsblk -o NAME,FSTYPE,PARTUUID`.
- Machine boots and the LUKS prompt works, but the config is wrong: fix the
  config on the running system, or from the live USB via section 4.
- LUKS header destroyed (for example `wipefs` against the wrong device):
  restore it from the section 3 backup with
  `cryptsetup luksHeaderRestore "$ROOT" --header-backup-file <file>`.
- Disk unbootable and unrecoverable: reformat and restore from the verified
  backup taken in section 1. That backup is the rollback.
