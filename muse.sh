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

# get all the info from last.fm for the artist given as $1 parameter
artist_info_get () {
    artist_raw=$1                                            # artist name, as given by the user
    artist=`echo $artist_raw | tr ' ' '+'`                   # artist name, suitable for last.fm query
    lastfm_resp=`curl --silent $lastfm_artist_req${artist}`  # get json response from last.fm
    similar=`echo $lastfm_resp | jq -r '.artist.similar.artist | .[] | .name' | tr '\n' ','`
    summary=`echo $lastfm_resp | jq -r '.artist.bio.summary'; echo`
    tags=`echo $lastfm_resp | jq -r '.artist.tags.tag | .[] | .name' | tr '\n' ','`
}

artist_info_display () {
    # display the common artist info. this info doesn't change when the
    # selection menu changes
    clear
    echo_bold $artist_raw": "; echo $summary; echo
    echo_bold "Tags: "; echo $tags; echo
    echo_bold "Similar artists: "; echo $similar; echo

    # decide what to display next. I want to clear the old selection menu
    # and display a new one, based on the old selection, keeping the artist info
    # stuff that is already displayed in the console intact
    case $1 in
        "Explore")
            PS3="Explore: "
            select choice in "Similar artists" "Tags" "Top Tracks" "Albums" "Quit"; do
                case $choice in
                    "Quit") exit 0;;
                    "Similar artists")
                        artist_info_display "Similar artists" ;;
                    "Tags")
                        select choice in $tags "Quit"; do
                            [[ $choice = "Quit" ]] && exit 0
                            tags_info "$choice"
                        done ;;
                    "Top Tracks")
                        artist_top_tracks "$artist_raw" ;;
                esac
                exit 0
            done ;;
        "Similar artists")
            PS3="Pick an artist: "
            oldIFS=$IFS; IFS=$','
            select choice in $similar "Quit"; do
                [[ $choice = "Quit" ]] && exit 0
                IFS=$oldIFS
                artist_info_get "$choice"
                artist_info_display "Explore"
            done ;;
    esac
}

artist_info_get "lacuna coil"
artist_info_display "Explore"
