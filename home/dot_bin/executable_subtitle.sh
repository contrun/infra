#!/bin/sh
export PATH=/usr/local/git/bin:/usr/local/bin:$PATH

parallel --will-cite pc.sh -q subliminal download -l {} ::: deu eng fra zho ::: "$@"
