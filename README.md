# nixos tasks

## nixos switch to new configuration

```
make nixos-switch
```

# ansible tasks

## Install ansible dependencies

```
make ansible-requirements
```

## Change hosts configuration

```
make ansible-inventory-hosts
```

## Run deployment tasks

```
make SERVICES=tailscale ansible-deploy
```

# fly tasks

```
make SERVICE=tailscale flyctl-deploy
```
