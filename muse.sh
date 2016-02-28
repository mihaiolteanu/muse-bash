#!/bin/bash

# check if the given application exists
check_dept () {
    hash $1 2>/dev/null || { echo >&2 "$1 missing.. aborting"; exit 1; }
}

# check for dependencies
for dept in jq youtube-dl; do
    check_dept $dept
done

# source the config file if it exists, abort otherwise
[[ -f ~/.muserc ]] || { echo >&2 "~/.muserc does not exist"; exit 1; }
source ~/.muserc

lastfm_base_req="https://ws.audioscrobbler.com/2.0/?format=json&api_key=${LASTFM_API_KEY}"
lastfm_artist_req=$lastfm_base_req"&method=artist.getInfo&artist="     # ${artist} to be added
lastfm_toptracks_req=$lastfm_base_req"&method=artist.getTopTracks&limit=${LASTFM_TOP_TRACKS_NO}&artist=" # ${artist} to be added

echo_underline () { echo -ne "\e[4m$@\e[0m"; }
echo_bold () { echo -ne "\e[1m$@\e[0m"; }
tags_info () { echo "Not implemented yet. Exiting.."; exit 0; }

artist_top_tracks () {
    declare artist=`echo $1 | tr ' ' '+'`
    declare lastfm_resp=`curl --silent $lastfm_toptracks_req${artist}`
    declare toptracks=`echo $lastfm_resp | jq -r '.toptracks.track | .[] | .name' | tr '\n' ','`

    echo_bold "Top tracks: "; echo
    oldIFS=$IFS; IFS=$','
    PS3="Listen to: "
    select entry in $toptracks "Quit"; do
        [[ $entry = "Quit" ]] && exit 0
        declare song=`echo $entry | tr ' ' '+'`
        youtube-dl -o - www.youtube.com/$(curl -s https://www.youtube.com/results\?search_query\=${artist}+${song} | grep -o 'watch?v=[^"]*"[^>]*title="[^"]*' | head -n 1 | awk '{print $1;}' | sed 's/*//') | vlc - &
        exit 0
    done
}

artist_info () {
    # replace "lacuna coil" with "lacuna+coil", for example
    declare artist=`echo $1 | tr ' ' '+'`
    # get json response from last.fm
    declare lastfm_resp=`curl --silent $lastfm_artist_req${artist}`
    # filter the json response with jq
    declare similar=`echo $lastfm_resp | jq -r '.artist.similar.artist | .[] | .name' | tr '\n' ','`
    declare summary=`echo $lastfm_resp | jq -r '.artist.bio.summary'; echo`
    declare tags=`echo $lastfm_resp | jq -r '.artist.tags.tag | .[] | .name' | tr '\n' ','`

    # display the filtered response
    clear
    echo_bold $1": "; echo $summary; echo
    echo_bold "Tags: "; echo $tags; echo
    echo_bold "Similar artists: "; echo $similar; echo

    # select the next step to go from here
    PS3="Explore: "
    select entry in "Similar artists" "Tags" "Top Tracks" "Albums" "Quit"; do
        [[ $entry = "Quit" ]] && exit 0
        oldIFS=$IFS; IFS=$','
        if [[ $entry = "Similar artists" ]]; then
            select entry in $similar "Quit"; do
                [[ $entry = "Quit" ]] && exit 0
                IFS=$oldIFS
                artist_info "$entry"
            done
        fi
        if [[ $entry = "Tags" ]]; then
            select entry in $tags "Quit"; do
                [[ $entry = "Quit" ]] && exit 0
                IFS=$oldIFS
                tags_info "$entry"
            done
        fi
        if [[ $entry = "Top Tracks" ]]; then
            IFS=$oldIFS
            artist_top_tracks "$1"
        fi
        exit 0
    done
}

artist_info "lacuna coil"
