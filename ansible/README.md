# Install ansible dependencies

`make ansible-install-requirements`

# Change hosts configuration

`make ansible-edit-inventory`

# Run deployment tasks

`make SERVICES=tailscale ansible-deploy-services`

# Enroll new host

`make HOSTS=newhost ansible-enroll-hosts`
