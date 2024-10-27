# see https://github.com/rupor-github/wsl-ssh-agent#wsl-2-compatibility
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
    npipereplay="$HOME/winhome/Programs/wsl-ssh-agent/npiperelay.exe"
    if [[ -f "$npipereplay" ]]; then
        export SSH_AUTH_SOCK=$HOME/.ssh/agent.sock
        if ! ss -a | grep -q $SSH_AUTH_SOCK; then
            rm -f $SSH_AUTH_SOCK
            setsid socat UNIX-LISTEN:$SSH_AUTH_SOCK,fork EXEC:"$npipereplay -ei -s //./pipe/openssh-ssh-agent",nofork &
        fi
    fi
fi
