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

Run every command below as root, in one shell session, so the `$ROOT` and
`$SWAP` variables persist.

## 1. Preconditions

WARNING: `cryptsetup reencrypt --encrypt` rewrites every sector. There is no
undo. The backup below is the only rollback path (see section 6).

- A full backup of oerlikon exists, and a test restore of sample files
  succeeded.
- A NixOS live USB (25.05 or newer) is available. The live ISO ships
  cryptsetup 2.x and e2fsprogs.
- oerlikon is connected to AC power. Reencryption of a ~1 TB disk runs for
  hours.
- The root filesystem is unmounted. Boot the live USB and stay in the live
  environment; do not mount the root partition before section 4.

## 2. Shrink the root filesystem

The encryption step reclaims the last 32 MiB of the partition: the LUKS2
header needs 16 MiB at the front, and `--reduce-device-size 32M` (twice the
header size, the documented recommended minimum) shifts the data back through
a 32 MiB scratch area at the tail. The filesystem must first release those
32 MiB.

1. Resolve the root partition device:

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

`cryptsetup reencrypt --encrypt` initializes in-place encryption.
LUKS2 is the default format in cryptsetup 2.x. The command asks for the new
passphrase.

```console
# cryptsetup reencrypt --encrypt --reduce-device-size 32M "$ROOT"
```

Interruption safety (cryptsetup-reencrypt(8)):

- Ctrl+C or SIGTERM interrupts the operation safely.
- To resume, run the same command again with the same options.
  `--reduce-device-size` selects the datashift resilience mode, so the resume
  must not change resilience options.
- If the machine crashes or loses power mid-operation, recovery runs
  automatically on the next `cryptsetup open`, or explicitly via
  `cryptsetup repair "$ROOT"`.

## 4. Fill in the config and rebuild

1. Unlock and mount the encrypted root plus the ESP:

   ```console
   # cryptsetup open "$ROOT" cryptroot
   # mount /dev/mapper/cryptroot /mnt
   # mount /dev/disk/by-uuid/C368-29C8 /mnt/boot
   ```

2. Collect the two identifiers:

   ```console
   # cryptsetup luksUUID "$ROOT"
   # SWAP=$(readlink -f /dev/disk/by-uuid/b70b0ab7-2e29-4420-bb29-16068ed1a790)
   # lsblk -no PARTUUID "$SWAP"
   ```

3. Edit `/mnt/home/dpoage/code/nixos-config`:
   - In `oerlikon/luks.nix`, replace `@LUKS_UUID@` with the `luksUUID` output
     and `@SWAP_PARTUUID@` with the `PARTUUID` output.
   - In `oerlikon/default.nix`, add `./luks.nix` to `imports`.

   `hardware-configuration.nix` stays untouched: `nixos-generate-config`
   regenerates that file, so `luks.nix` overrides its `swapDevices` with
   `lib.mkForce` instead. Its `fileSystems."/"` entry also stays correct —
   the ext4 UUID survived the reencrypt, and after unlock the by-uuid symlink
   points at `/dev/mapper/cryptroot`.

4. Wipe the old swap signature. `randomEncryption` formats swap with a fresh
   key on every boot, so the old signature and its `b70b0ab7-…` UUID are dead
   weight; the new config references the partition by PARTUUID, which
   survives:

   ```console
   # wipefs --all "$SWAP"
   ```

5. Build the new boot generation from inside the mounted system:

   ```console
   # nixos-enter --root /mnt -c 'nixos-rebuild boot --flake /home/dpoage/code/nixos-config#oerlikon'
   ```

   If nix reports a git "dubious ownership" error, run
   `git config --global --add safe.directory /home/dpoage/code/nixos-config`
   inside the chroot and retry.

6. Exit, unmount, and reboot:

   ```console
   # umount -R /mnt
   # cryptsetup close cryptroot
   # reboot
   ```

## 5. Verify

1. On the first boot, stage 1 asks: `Enter passphrase for cryptroot`. The
   passphrase unlocks the disk and boot continues to the greeter.
2. After login, confirm the block layout:

   ```console
   # lsblk -f
   ```

   Expected: the root partition shows `crypto_LUKS` with an ext4 `cryptroot`
   mapper child mounted at `/`; the swap partition shows a dm-crypt child.
3. Confirm swap runs on the mapper device, not the raw partition:

   ```console
   # swapon --show
   ```

4. Confirm the LUKS2 header:

   ```console
   # cryptsetup luksDump "$ROOT" | head -n 20
   ```

## 6. Drata evidence capture

Drata's Linux agent cannot read LUKS state, so encryption evidence is a
manual upload (see
<https://help.drata.com/en/articles/5014509-computer-configuration-via-ubuntu-linux>).

1. In one terminal frame, run `date`, `lsblk -f`, and
   `cryptsetup luksDump "$ROOT" | head -n 20` so the date and the
   `crypto_LUKS` output are visible together.
2. Screenshot that frame.
3. Upload the screenshot in myDrata under the disk-encryption evidence
   request for this device.

## 7. Rollback

`cryptsetup reencrypt --encrypt` has no clean undo. Do not attempt
`--decrypt` as a rollback; treat the operation as one-way.

- If the reencryption was interrupted: this is not a failure. Resume as
  described in section 3.
- If the disk is unbootable or corrupt: reformat and restore from the
  verified backup taken in section 1. That backup is the rollback.
- If only the NixOS config is wrong (machine boots, LUKS prompt works):
  fix the config from the live USB via section 4, step 5.
