#!/bin/bash

help() {
echo usage: $0
echo
echo "Follow instructions to connect to Roku device(s) on your current network."
echo
echo Input when prompted:
echo
echo Keypresses are typed as-is, and include:
echo "Home" "Rev" "Fwd" "Play" "Select" "Left" "Right" "Down" "Up" "Back" "InstantReplay" "Info" "Backspace" "Search" "Enter" "VolumeDown" "VolumeUp" "VolumeMute" "PowerOff" "PowerOn" "ChannelUp" "ChannelDown" "InputTuner" "InputHDMI1" "InputHDMI2" "InputHDMI3" "InputHDMI4" "InputAV1"
echo
echo * Keypresses can be repeated quickly by appending a number, ie `left 5`
echo Use "launch" to launch or install an app either by name or by APP_ID.  Names are taken from "Roku Apps.txt" in the same folder.  ie. `launch youtube`
echo
echo Inputs that are not keypresses or apps will be automatically detected as text, and typed — ie, for a streaming service\'s search engine.
}

while getopts ":h help" option; do
   case $option in
      h | --help ) help; exit;;
   esac
done

set -- $(ifconfig | grep 192.168)
addresses=$(nmap -sL $2/24 | grep Roku | sed -r 's/^.*\((.+)\).*$/\1/g')

if [ ${#addresses[@]} -eq 1 ]; then
    echo "Found" ${#addresses[@]} "device.";
    else echo "Found" ${#addresses[@]} "devices.";
fi
count=0

while [ ${#addresses[@]} -gt $count ]; do
    echo $count - $(nmap -sL ${addresses[$count]} | grep Roku | cut -d " " -f5,6);
    count=$((count+1));
done
echo " "
read -r -a input -p "Type individual numbers, or 'all': "

if [ "$input" = "all" ]; then
    device=$addresses;
    else count=0
    while [ ${#input[@]} -gt $count ]; do
        device=($device ${addresses[${input[$count]}]})
        count=$((count+1))
    done
fi

re='^[0-9]+$'
keypresses=("Home" "Rev" "Fwd" "Play" "Select" "Left" "Right" "Down" "Up" "Back" "InstantReplay" "Info" "Backspace" "Search" "Enter" "VolumeDown" "VolumeUp" "VolumeMute" "PowerOff" "PowerOn" "ChannelUp" "ChannelDown" "InputTuner" "InputHDMI1" "InputHDMI2" "InputHDMI3" "InputHDMI4" "InputAV1")
echo "Connected to $device, now accepting inputs!"

post() {
if [ "${input[0]}" = "launch" ]; then
echo launching
    if ! [[ ${input[1]} =~ $re} ]]; then
        launch=$(curl "http://$1:8060/query/apps" | grep -i ${input[1]} | sed -r 's/^[^0-9]+([0-9]+).*$/\1/g')
        echo $launch
        if [-z $launch ]; then
            if [ -z $(grep -i $input[1] Roku\ Apps.txt) ]; then
                echo "APP_ID of $input[1] not found in Roku Apps.txt."
                else curl -d '' "http://$1:8060/install/$(grep -i ${input[1]} Roku\ Apps.txt | cut -d " " -f1)"
            fi
            else curl -d '' http://$1:8060/launch/$launch
        fi
    else curl -d '' http://$1:8060/install/$1
    fi

elif [[ " ${keypresses[*],,} " =~ " ${input,,} " ]]; then
echo keypress
    curl -d '' http://$1:8060/keypress/$input
    if [ ${#input[@]} -gt 1 ]; then
        while [ ${input[1]} -gt 0 ]; do
            curl -d '' http://$1:8060/keypress/$input
            input[1]=$((${input[1]}-1))
        done
    fi

else
echo typing
    count=0
    fullinput=${input[*]}
    while [ $(echo ${input[*]} | wc -c) -gt $count ]; do
        if [ "${fullinput:$count:1}" = " " ]; then
            curl -d '' "http://$1:8060/keypress/Lit_%20"
            else curl -d '' "http://$1:8060/keypress/Lit_${fullinput:$count:1}"
        fi
        count=$((count+1))
    done
fi
}

while true; do
    read -r -a input
    count=0
    while [[ ${#device[@]} -gt $count ]]; do
        post ${device[$count]}
        count=$((count+1))
    done
done
