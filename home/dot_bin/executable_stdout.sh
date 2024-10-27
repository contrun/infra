#!/bin/zsh
if [[ $(uname) == 'Linux' ]]; then
	:
elif [[ $(uname) == 'Darwin' ]]; then
	capture() {
		sudo dtrace -p "$1" -qn '
			syscall::write*:entry
			/pid == $target && arg0 == 1/ {
				printf("%s", copyinstr(arg1, arg2));
			}
		'
	}
	capture "$1"
else
    :
fi
