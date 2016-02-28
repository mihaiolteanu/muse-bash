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

youtube="https://www.youtube.com/"
youtube_search=$youtube"results?search_query="

echo_underline () { echo -ne "\e[4m$@\e[0m"; }
echo_bold () { echo -ne "\e[1m$@\e[0m"; }
tags_info () { echo "Feature not implemented yet."; }

artist_toptracks_get () {
    lastfm_resp=$(curl --silent $lastfm_toptracks_req${artist})
    # save toptracks as an array
    oldIFS=$IFS; IFS=$'\n'
    toptracks=($(echo $lastfm_resp | jq -r '.toptracks.track | .[] | .name'))
    IFS=$oldIFS
}

# get all the info from last.fm for the artist given as $1 parameter
artist_info_get () {
    artist_raw=$1                                            # artist name, as given by the user
    artist=$(echo $artist_raw | tr ' ' '+')                  # artist name, suitable for last.fm query
    lastfm_resp=$(curl --silent $lastfm_artist_req${artist}) # get json response from last.fm
    summary=$(echo $lastfm_resp | jq -r '.artist.bio.summary')
    # build arrays for both similar artists and for tags entries
    oldIFS=$IFS; IFS=$'\n'
    similar=($(echo $lastfm_resp | jq -r '.artist.similar.artist | .[] | .name'))
    tags=($(echo $lastfm_resp | jq -r '.artist.tags.tag | .[] | .name'))
    IFS=$oldIFS
}

artist_info_display () {
    # display the common artist info. this info doesn't change when the
    # selection menu changes
    clear
    echo_bold $artist_raw": "
    echo ${summary%%<a href*}; echo # remove link at the end of summary
    echo_bold "Tags: "
    for entry in "${tags[@]}"; do
        echo -n "$entry, "
    done
    echo
    echo_bold "Similar artists: "
    for entry in "${similar[@]}"; do
        echo -n "$entry, "
    done
    echo; echo

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
                        artist_info_display "Tags" ;;
                    "Top Tracks")
                        artist_toptracks_get "$artist_raw"
                        artist_info_display "Top Tracks" ;;
                esac
                exit 0
            done ;;
        "Similar artists")
            PS3="Pick an artist: "
            select choice in "${similar[@]}" "Go Back" "Quit"; do
                case $choice in
                    "Quit") exit 0;;
                    "Go Back")
                        artist_info_display "Explore" ;;
                    *)
                        artist_info_get "$choice"
                        artist_info_display "Explore" ;;
                esac
            done ;;
        "Tags")
            PS3="Pick a tag: "
            select choice in "${tags[@]}" "Go Back" "Quit"; do
                case $choice in
                    "Quit") exit 0;;
                    "Go Back")
                        artist_info_display "Explore" ;;
                    *)
                        tags_info "$choice" ;;
                esac
            done ;;
        "Top Tracks")
            echo_bold "Top Tracks: "; echo
            PS3="Listen to: "
            select choice in "${toptracks[@]}" "Listen To All" "Go Back" "Quit"; do
                case $choice in
                    "Quit") exit 0;;
                    "Go Back")
                        artist_info_display "Explore" ;;
                    "Listen To All")
                        # listen to all tracks displayed, as mp3
                        mkdir $MUSE_DWN_PATH/$artist
                        cd $MUSE_DWN_PATH/$artist
                        for track in $toptracks; do
                            track=$(echo $track | tr ' ' '+')
                            youtube-dl --extract-audio --audio-format mp3 $youtube$(curl -s $youtube_search${artist}+${track} | grep -o 'watch?v=[^"]*"[^>]*title="[^"]*' | head -n 1 | awk '{print $1;}' | sed 's/*//')
                        done
                        cmus-remote -q *.mp3 ;;
                    *)
                        # watch the video
                        song=$(echo $choice | tr ' ' '+')
                        youtube-dl 2>/dev/null -o - $youtube$(curl -s $youtube_search${artist}+${song} | grep -o 'watch?v=[^"]*"[^>]*title="[^"]*' | head -n 1 | awk '{print $1;}' | sed 's/*//') | vlc >/dev/null 2>&1 - &
                        ;;
                esac
            done
    esac
}

artist_info_get "$1"
artist_info_display "Explore"
