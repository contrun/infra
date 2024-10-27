#!/usr/bin/env bash
file=~/.config/cron/crontab
c="$((fcrontab -l; cat "$file") | sort | uniq)"
echo "$c" | "$file"
vi "$file"
cat "$file" | fcrontab -
fcrontab -l
