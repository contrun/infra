#!/usr/bin/env bash
set -euo pipefail

old() {
        radioStations="$(
                cat <<EOF
http://streaming.lxcluster.at:8000/live128.m3u
http://www.listenlive.eu/streams/belgium/be_vrtklara.m3u
http://www.listenlive.eu/streams/belgium/be_vrtklaracontinuo.m3u
http://www.listenlive.eu/streams/belgium/be_rtbfmusiq3mp3.m3u
http://www.listenlive.eu/streams/belgium/be_rtbfmusiq3aac.m3u
http://live.btvradio.bg/classic-fm.mp3.m3u
http://sc.brtk.net:8006/listen.pls
http://www.play.cz/radio/croddur192.asx
http://radio.cesnet.cz/cgi-bin/cro-d-dur-256-ogg.pls
http://icecast8.play.cz/classic128.mp3.m3u
http://live-icy.gss.dr.dk:8000/A/A04H.mp3.m3u
http://onair.100fmlive.dk/klassisk_live.mp3.m3u
http://icecast.err.ee/klassikaraadio.mp3.m3u
mms://mediau.yle.fi/liveklassinen256
http://stream.iradio.fi:8000/klasu-hi.mp3.m3u
http://stream.iradio.fi:8000/klasupro-hi.mp3.m3u
http://www.listenlive.eu/vivaclassica.m3u
http://players.creacast.com/creacast/accent4/playlist.pls
http://broadcast.infomaniak.ch/radioclassique-high.mp3.m3u
http://www.m2radio.fr/pls/m2classic.m3u
http://streams.br.de/br-klassik_2.m3u
http://tuner.classical102.com/listen.pls
http://metafiles.gl-systemhaus.de/hr/hr2_2.m3u
http://edge.live.mp3.mdn.newmedia.nacamar.net/klassikradio128/livestream.mp3.m3u
http://edge.live.mp3.mdn.newmedia.nacamar.net/klassikradiopurebach128/livestream.mp3.m3u
http://avw.mdr.de/streams/284310-0_aac_high.m3u
http://avw.mdr.de/streams/284311-0_aac_high.m3u
http://avw.mdr.de/streams/284350-0_aac_high.m3u
http://www.ndr.de/resources/metadaten/audio/m3u/ndrkultur.m3u
http://www.kulturradio.de/live.m3u
http://streaming01.sr-online.de/sr2_2.m3u
http://www.wdr.de/wdrlive/media/mp3/wdr3_hq.m3u
http://mp3-live.swr.de/swr2_m.m3u
http://rs3.stream24.org:8220/listen.pls
http://www.listenlive.eu/mr3.m3u
http://online.klasszikradio.hu/klasszik.mp3.m3u
http://server6.reliastream.com/tunein.php/ncarroll/tunein.pls
http://www.listenlive.eu/rtelyric.m3u
http://www.listenlive.eu/rai5.m3u
http://players.creacast.com/creacast/class_radioclassica/playlist.m3u
http://radio.gruppoeditorialebresciana.it/radioclassica
mms://stream.radiomarconi.info/marconi2
mms://streaming.intoscana.it/wmtencoder/rtc.wma
http://www.radioonda.it/live2/128.pls
mms://lr1w.latvijasradio.lv/pplr3
mms://82.135.234.194/Klasika
http://icecast.omroep.nl/radio4-bb-aac.m3u
http://provisioning.streamtheworld.com/pls/classicfmaac.pls
http://icecast.omroep.nl/radio4-klassieken-bb-mp3.m3u
http://icecast.omroep.nl/radio4-baroque-bb-mp3.m3u
http://icecast.omroep.nl/radio4-film-bb-mp3.m3u
http://streams.greenhost.nl:8080/live.m3u
http://streams.greenhost.nl:8080/nieuwemuziek.m3u
http://streams.greenhost.nl:8080/oudemuziek.m3u
http://streams.greenhost.nl:8080/klassiek.m3u
http://streams.greenhost.nl:8080/gehoordestilte.m3u
http://streams.greenhost.nl:8080/novembermusic.m3u
http://streams.greenhost.nl:8080/gregoriaans.m3u
http://streams.greenhost.nl:8080/raakvlakken.m3u
http://streams.greenhost.nl:8080/youngprofessionals.m3u
http://lyd.nrk.no/nrk_radio_klassisk_aac_h.m3u
http://zetcla-01.cdn.eurozet.pl:8412/listen.pls
http://zetcho-02.cdn.eurozet.pl:8410/listen.pls
http://www.miastomuzyki.pl/n/rmfclassic.pls
mms://195.245.168.21/antena2
http://stream2.srr.ro:8022/listen.pls
http://livestream.rfn.ru:8080/kulturafm/aac_64kbps.m3u
http://livestream.rfn.ru:8080/orfeyfm/aac_64kbps.m3u
http://live.slovakradio.sk:8000/Devin_256.ogg.m3u
http://live.slovakradio.sk:8000/Klasika_256.ogg.m3u
http://www.listenlive.eu/rneradioclasica.m3u
http://www.listenlive.eu/es_catalunyamusica.m3u
http://www.listenlive.eu/es_catclassica.m3u
http://sverigesradio.se/topsy/direkt/2562-hi-aac.pls
http://sverigesradio.se/topsy/direkt/1603-hi-aac.pls
http://www.radioswissclassic.ch/live/aacp.m3u
http://stream.srg-ssr.ch/rsc_fr/mp3_128.m3u
http://www.radiosvizzeraclassica.ch/live/aacp.m3u
http://www.swissradio.ch/streams/6034.m3u
http://www.swissradio.ch/streams/6060.m3u
http://radyo.itu.edu.tr/ITU_Radio_Classical.pls
http://myradio.com.ua/alias/Classica128.m3u
http://open.live.bbc.co.uk/mediaselector/5/select/version/2.0/mediaset/http-icy-aac-lc-a/format/pls/vpid/bbc_radio_three.pls
http://media-ice.musicradio.com/ClassicFM.m3u
EOF
        )"
        while true; do
                r="$(shuf -n1 <<<"$radioStations")"
                noti -t "classic radio" -m "station: $r"
                cvlc --play-and-exit "$r"
        done
}

download_tag() {
        tag="$1"
        filename="$2"
        if [[ -f "$filename" ]] && [[ $(find "$filename" -mtime -7 -print) ]]; then
                return 0
        fi
        local -a mirrors=("https://de1.api.radio-browser.info" "https://fr1.api.radio-browser.info")
        for mirror in "${mirrors[@]}"; do
                url="${mirror}/json/stations/bytagexact/$tag"
                if ! curl -s -L --create-dirs -o "$filename" "$url"; then
                        echo "Downloading $url to $filename failed"
                else
                        return 0
                fi
        done
        return 1
}

download_radio_browser_data() {
        dir="$HOME/.customized/radio_stations"
        pyradio_file="$HOME/.config/pyradio/stations.csv"
        declare -a tags=("classical")

        for tag in "${tags[@]}"; do
                download_tag "$tag" "$dir/$tag.json"
        done

        jq -s 'add' "$dir"/* | jq -r 'unique | sort_by(.votes | tonumber) | reverse | .[] | [.name, .url] | @csv' >"$pyradio_file"
}

my_pyradio() {
        download_radio_browser_data
        # pyradio "$@"
}

my_pyradio "$@"
