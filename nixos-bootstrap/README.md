Ansible playbook to install nixos

# Install on raspberry pi

It is a little tricky to install nixos on raspberry bi. I made some trivial modification to https://github.com/NixOS/nixpkgs/issues/63720#issuecomment-522331183

## Set up live CD system

- Connect to wifi
- Obtain IP Address
- Change password

## Setup some variables

```shell
export nixos_hostname=shl nixos_host_ip=192.168.0.102 zfs_pool_name=rspool zfs_passphrase=zfs_passphrase root_password=root_password user=user user_password=user_password tmp_mount_path=/tmpmount
```

## Make partitions and Install

```shell
echo "[$nixos_hostname]\n${nixos_host_ip} ansible_user=nixos" | tee -a inventory
ssh-copy-id nixos@$nixos_host_ip
ssh nixos@$nixos_host_ip 'nix-env -iA nixos.python3 && sudo ln -sf $(command -v bash) /bin/bash && sudo ln -sf $(command -v python3) /usr/bin/python'
ansible-playbook -i inventory --become-user=root --extra-vars host=myhost --extra-vars nixos_hostname="$nixos_hostname" --extra-vars zfs_pool_name="$zfs_pool_name" --extra-vars '{"zfs_pool_disks": ["/dev/sda"]}' --extra-vars "zfs_passphrase=$zfs_passphrase" --extra-vars "root_password=$root_password" --extra-vars "user=$user" --extra-vars "user_password=$user_password" --extra-vars "tmp_mount_path=$tmp_mount_path" site.yml
```
