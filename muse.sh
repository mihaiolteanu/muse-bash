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

bold=$(tput bold)
normal=$(tput sgr0)
underline=$(tput smul)

tags_info () { echo "Feature not implemented yet."; }

artist_toptracks_get () {
    lastfm_resp=$(curl --silent $lastfm_toptracks_req${artist})
    # create an array, where each element is separated by the IFS; jq returns each
    # entry (toptrack in this case) on a new line. I can then walk the array with
    # the <for entry in "${similar[@]}"> construct or a similar select construct.
    # Plus, I can print all the elements, separated by IFS with the <echo "${tags[*]}"> construct
    oldIFS=$IFS; IFS=$'\n'
    toptracks=($(echo $lastfm_resp | jq -r '.toptracks.track | .[] | .name'))
    IFS=$oldIFS
}

# get all the info from last.fm for the artist given as $1 parameter
# as this is the first function to be called for a new artist, this is the place
# where both $artist and $artist_raw should be set
artist_info_get () {
    artist_raw=$1                                            # artist name, as given by the user
    artist=${artist_raw// /+}                                # artist name, suitable for last.fm query
    lastfm_resp=$(curl --silent $lastfm_artist_req${artist}) # get json response from last.fm
    summary=$(echo $lastfm_resp | jq -r '.artist.bio.summary')
    # build arrays for both similar artists and for tags entries
    oldIFS=$IFS; IFS=$'\n'
    similar=($(echo $lastfm_resp | jq -r '.artist.similar.artist | .[] | .name'))
    tags=($(echo $lastfm_resp | jq -r '.artist.tags.tag | .[] | .name'))
    IFS=$oldIFS
}

# get all the albums of the artist that is in effect
artist_albums_get () {
    req=$lastfm_base_req"&method=artist.getTopAlbums&artist="$artist"&limit="$LASTFM_ALBUMS_NO
    resp=$(curl --silent $req)
    oldIFS=$IFS; IFS=$'\n'
    albums=($(echo $resp | jq -r '.topalbums.album | .[] | .name'))
    IFS=$oldIFS
}

# get additional info for the album given as $1 for the artist that is in effect
artist_album_info () {
    album_raw=$1
    album=${album_raw// /+}                                  # album name, suitable for last.fm query
    req=$lastfm_base_req"&method=album.getInfo&artist="$artist"&album="$album
    resp=$(curl --silent $req)
    album_published=$(echo $resp | jq -r '.album.wiki.published')
    album_summary=$(echo $resp | jq -r '.album.wiki.summary')
    oldIFS=$IFS; IFS=$'\n'
    album_tracks=($(echo $resp | jq -r '.album.tracks.track | .[] | .name'))
    IFS=$oldIFS
}

video_watch () {
    link=$youtube$(curl -s $youtube_search${1}+${2} | grep -o 'watch?v=[^"]*"[^>]*title="[^"]*' | head -n 1 | awk '{print $1;}' | sed 's/*//')
    youtube-dl 2>/dev/null -o - $link | vlc --play-and-exit --input-title-format "${1//+/ } - ${2//+/ }" &>/dev/null - &
}

header_display () {
    # display the common artist info. this info doesn't change when the
    # selection menu changes
    clear
    echo "${underline}${bold}"$artist_raw"${normal}"
    # remove link at the end of summary
    echo ${summary%%<a href*} | fold --spaces ; echo

    # [*] prints all entries in the array, separated by the IFS
    # If I would want to iterate over all the entries with a for, I would use [@] instead
    # I can also add a space to that, for prettiness
    oldIFS=$IFS; IFS=$','
    echo "${underline}${bold}Tags${normal}"
    echo "${tags[*]}" | sed 's/,/, /g' | fold --spaces
    echo
    echo "${underline}${bold}Similar artists${normal}"
    echo "${similar[*]}" | sed 's/,/, /g' | fold --spaces
    IFS=$oldIFS
    echo
}

artist_info_display () {
    next=$1
    # decide what to display next. I want to clear the old selection menu
    # and display a new one, based on the old selection, keeping the artist info
    # stuff that is already displayed in the console intact
    while [[ $next != "Quit" ]]; do
        COLUMNS=1
        header_display
        case $next in
            "Explore")
                PS3="Explore: "
                select choice in "( Quit )" "Similar artists" "Tags" "Top Tracks" "Albums"; do
                    case $choice in
                        "( Quit )")
                            next="Quit"
                            break ;;
                        "Similar artists")
                            next="Similar artists"
                            break ;;
                        "Tags")
                            next="Tags"
                            break ;;
                        "Top Tracks")
                            artist_toptracks_get
                            next="Top Tracks"
                            break ;;
                        "Albums")
                            artist_albums_get
                            next="Albums"
                            break ;;
                    esac
                done ;;
            "Similar artists")
                PS3="Pick an artist: "
                select choice in "( Quit )" "( Go Back )" "${similar[@]}"; do
                    case $choice in
                        "( Quit )")
                            next="Quit"
                            break ;;
                        "( Go Back )")
                            next="Explore"
                            break ;;
                        *)
                            artist_info_get "$choice"
                            next="Explore"
                            break ;;
                    esac
                done ;;
            "Tags")
                PS3="Pick a tag: "
                select choice in "( Quit )" "( Go Back )" "${tags[@]}"; do
                    case $choice in
                        "( Quit )")
                            next="Quit"
                            break ;;
                        "( Go Back )")
                            next="Explore"
                            break ;;
                        *)
                            tags_info "$choice" ;;
                    esac
                done ;;
            "Top Tracks")
                echo "${bold}Top Tracks${normal} "
                PS3="Listen to: "
                select choice in "( Quit )" "( Go Back )" "${toptracks[@]}" "Listen To All"; do
                    case $choice in
                        "( Quit )")
                            next="Quit"
                            break ;;
                        "( Go Back )")
                            next="Explore"
                            break ;;
                        "Listen To All")
                            for track in "${toptracks[@]}"; do
                                video_watch $artist ${track// /+}
                                wait
                            done ;;
                        *)
                            video_watch $artist ${choice// /+}
                            ;;
                    esac
                done ;;
            "Albums")
                echo "${bold}Albums${normal}"
                PS3="Explore album: "
                select choice in "( Quit )" "( Go Back )" "${albums[@]}"; do
                    case $choice in
                        "( Quit )")
                            next="Quit"
                            break ;;
                        "( Go Back )")
                            next="Explore"
                            break ;;
                        *)
                            artist_album_info $choice
                            next="Album Info"
                            break ;;
                    esac
                done ;;
            "Album Info")
                echo "${bold}Album${normal} "$choice
                echo "${bold}Published${normal} "$album_published
                echo $album_summary
                echo "${bold}Playlist${normal}"
                PS3="Listen to: "
                select choice in "( Quit )" "( Go Back )" "${album_tracks[@]}" "Listen To All"; do
                    case $choice in
                        "( Quit )")
                            next="Quit"
                            break ;;
                        "( Go Back )")
                            next="Albums"
                            break ;;
                        "Listen To All")
                            for track in "${album_tracks[@]}"; do
                                video_watch $artist ${track// /+}
                                wait
                            done ;;
                        *)
                            video_watch $artist ${choice// /+}
                            ;;

                    esac
                done ;;
        esac
    done
}

artist_info_get "$1"
artist_info_display "Explore"
