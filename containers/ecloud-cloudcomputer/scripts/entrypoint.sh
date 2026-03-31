#!/bin/bash
set -e

# ============================================
# Main Container Entrypoint
# Sets up anti-detection and starts supervisor
# ============================================

echo ">>> VDI Container Starting..."

# Create log directory
mkdir -p /var/log/supervisor

# Ensure VNC password file exists
if [ ! -f /config/vnc_password ]; then
    echo "Aa11@@33" > /config/vnc_password
fi

# ============================================
# ANTI-DETECTION: Make it look like real hardware
# ============================================
echo ">>> Applying anti-detection measures..."

# Set real hardware-like environment
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Deepin
export DESKTOP_SESSION=deepin
export XDG_SESSION_DESKTOP=deepin

# Remove any virtualization hints from environment
unset container
unset DOCKER_HOST



# Fake hostname to look real
if [ -w /etc/hostname ]; then
    echo "desktop-$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)" > /etc/hostname 2>/dev/null || true
fi

# Remove Docker specific files
rm -f /.dockerenv
umount /run/.containerenv
rm -f /run/.containerenv

# Masquerade Process Name (PID 1)
# We copy supervisord to a credible system name
if [ -f /usr/bin/supervisord ]; then
    cp /usr/bin/supervisord /usr/sbin/init_system
fi

echo ">>> Starting services via supervisor (Masqueraded)..."
# Executing as 'init_system' to hide 'supervisord' from process list
exec /usr/sbin/init_system -c /etc/supervisor/supervisord.conf
