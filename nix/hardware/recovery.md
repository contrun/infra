# Reovering from a broken NixOS system

## Don't panic

## Download the NixOS ISO image

## Boot from the ISO image

- Burn the ISO image to a USB stick
- Copy the ISO image to a USB stick prepared by [ventoy/Ventoy: A new bootable USB solution.](https://github.com/ventoy/Ventoy)

## Reboot to the USB stick

## Mount the partitions

### Take a look at the partitions

Run the following command and take a look at the `fileSystems` configurations.
```sh
less nix/hardware/hardware-configuration.aol.nix
```
where `aol` is the hostname of the machine.

### Import and unlock zfs pool

```sh
zpool import -l -R /rpool rpool
```
where `rpool` is the name of the zfs pool. We may also need `-f` flag to forcefully import the pool.

### Mount tthe partitions

```sh
mkdir -p /rpool
mount.zfs rpool/ROOT/nixos /rpool
mount.zfs rpool/HOME/home /rpool/home
mount.zfs rpool/NIX/nix /rpool/nix
mount.zfs rpool/TMP/tmp /rpool/tmp
mount.zfs rpool/VAR/var /rpool/var
mount -t vfat /dev/disk/by-label/EFI /rpool/boot
```
where `rpool/ROOT/nixos` is the root partition of the NixOS system. Other datasets are respectively the home, nix store, tmp, and var partitions. And the `EFI` partition is mounted to `/boot`. Different machines may have different datasets. Note that we need to mount the root directory (here `/rpool`) first.
Different machines may have Different datasets. Note that we need to mount the root directory first.

## Change root to the mounted system

```sh
nixos-enter --root /rpool
```

## Install the system

```sh
nixos-rebuild switch --flake ".#aol" --show-trace --keep-going
```

An addtional command may be necessary if we encounter an error like `error: System has not been booted with systemd as init system (PID 1). Can't operate.`. See [Change root - NixOS Wiki](https://nixos.wiki/wiki/Change_root).
```sh
NIXOS_SWITCH_USE_DIRTY_ENV=1 nixos-rebuild boot --flake ".#aol" --show-trace --keep-going
```

## Reboot
