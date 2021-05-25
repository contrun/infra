Ansible playbook to install nixos

# Install on raspberry pi

It is a little tricky to install nixos on raspberry bi. I made some trivial modification to https://github.com/NixOS/nixpkgs/issues/63720#issuecomment-522331183

## Setup some variables
```shell
nixos_hostname=shl
zfs_pool_name=rspool
zfs_passphrase=zfs_passphrase
root_password=root_password
user_password=user_password
tmp_mount_path=/tmpmount
```

## Make partitions and Install
```shell
ansible-playbook -i inventory --become --become-user=root --extra-vars host=localhost --extra-vars nixos_hostname="$nixos_hostname" --extra-vars zfs_pool_name="$zfs_pool_name" --extra-vars '{"zfs_pool_disks": ["/dev/sda"]}' --extra-vars "zfs_passphrase=$zfs_passphrase" --extra-vars "root_password=$root_password" --extra-vars "user_password=$user_password" --extra-vars "tmp_mount_path=$tmp_mount_path" site.yml
```
