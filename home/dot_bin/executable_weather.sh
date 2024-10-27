#!/usr/bin/env bash
# http://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BRed='\033[1;31m'         # Red

# get weather info
CITY=$(cat ~/.customized/ignore/city)
curl -m 5 -ss "wttr.in/$CITY?mM1nQ" | grep -Ev 'igor_chubin|New\sfeature'

# get aqi info
FILE=/tmp/weatherRawInfo
curl -m 5 -ss 'http://www.stateair.net/web/rss/1/1.xml' | xmlstarlet sel -t -v '/rss/channel/item[1]/description' > $FILE
# convert newline to unix format
TIME="$(awk -F';' '{print $1}' $FILE | awk '{print $2}')"
AQI="$(awk -F';' '{print $4}' $FILE | awk '{print $1}')"
INFO="$(awk -F';' '{print $5}' $FILE | awk '{print $1}')"

if [[ "$AQI" -le "50" ]]; then
    COLOR=$Green
elif [[ $AQI -gt 50 && $AQI -le 100 ]]; then
    COLOR=$Cyan
elif (( $AQI > 100 && $AQI <= 150 )); then
    COLOR=$Blue
elif (( $AQI > 150 && $AQI <= 200 )); then
    COLOR=$Yellow
elif (( $AQI > 200 && $AQI <= 300 )); then
    COLOR=$Purple
elif (( $AQI > 300 && $AQI <= 500 )); then
    COLOR=$Red
else
    COLOR=$BRed
fi

printf "$TIME\t$COLOR$AQI\t$INFO$Color_Off\n"

# printf "$(awk 'NR == 3 {print; exit}' $FILE)\t$(awk 'NR == 4 {print; exit}' $FILE)\t$(awk 'NR == 2 {print; exit}' $FILE)\n"
# rm -f $FILE
