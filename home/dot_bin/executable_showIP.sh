#!/usr/bin/env bash
getIP() {
    curl -s http://myip.ipip.net | perl -pe 's/.*?([0-9]{1,3}.*[0-9]{1,3}?).*/\1/g'
    # curl -s http://ifconfig.me/ip
}
echo "Your old ip address is $(no_proxy=myip.ipip.net getIP)"
echo "Your new ip address is $(http_proxy='socks5://127.0.0.1:1081' getIP)"
