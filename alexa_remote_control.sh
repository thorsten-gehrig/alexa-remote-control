#!/bin/sh
#
# Amazon Alexa Remote Control
#  alex(at)loetzimmer.de
#
# 2017-10-10: v0.1 initial release
# 2017-10-11: v0.2 TuneIn Station Search
# 2017-10-11: v0.2a commands on special device "ALL" are executed on all ECHO+WHA
# 2017-10-16: v0.3 added playback of library tracks
#
###
#
# (no BASHisms were used, should run with any shell)
# - requires cURL for web communication
# - sed and awk for extraction
# - jq as command line JSON parser (optional for the fancy bits)
#
##########################################

EMAIL="amazon_account@email.address"
PASSWORD="Very_Secret_Amazon_Account_Password"

###########################################
# nothing to configure below here
#
COOKIE="/tmp/.alexa.cookie"
DEVLIST="/tmp/.alexa.devicelist.json"
TMP="/tmp/"

GUIVERSION=1.24.2698.0

OPTIND=1
LIST=""
LOGOFF=""
COMMAND=""
STATIONID=""
SONG=""
while getopts "h?lad:e:r:s:" opt; do
        case "$opt" in
                s)
                        SONG=$OPTARG
                        ;;
                e)
                        COMMAND=$OPTARG
                        ;;
                r)
                        STATIONID=$OPTARG
                        # stationIDs are "s1234" or "s12345"
                        if [ -n "${STATIONID##s[0-9][0-9][0-9][0-9]}" -a -n "${STATIONID##s[0-9][0-9][0-9][0-9][0-9]}" ] ; then
                                # search for station name
                                STATIONID=$(curl -s --data-urlencode "query=${STATIONID}" -G "https://api.tunein.com/profiles?fullTextSearch=true" | jq -r '.Items[] | select(.ContainerType == "Stations") | .Children[] | select( .Index==1 ) | .GuideId')
                                if [ -z "$STATIONID" ] ; then
                                        echo "ERROR: no Station \"$OPTARG\" found on TuneIn"
                                        exit 1
                                fi
                        fi
                        ;;
                d)
                        DEVICE=$OPTARG
                        ;;
                l)
                        LOGOFF="true"
                        ;;
                a)
                        LIST="true"
                        ;;
                *)
                        echo "$0 [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|vol:<0-100>> | -r <\"station name\"|stationid> | -s <trackID> | -a | -l | -h"
                        echo "   -e : run command"
                        echo "   -r : play tunein radio"
                        echo "   -s : play library track"
                        echo "   -a : list available devices"
                        echo "   -l : logoff"
                        echo "   -h : help"
                        exit 0
                        ;;
        esac
done

case "$COMMAND" in
        pause)
                        COMMAND='{"type":"PauseCommand"}'
                        ;;
        play)
                        COMMAND='{"type":"PlayCommand"}'
                        ;;
        next)
                        COMMAND='{"type":"NextCommand"}'
                        ;;
        prev)
                        COMMAND='{"type":"PreviousCommand"}'
                        ;;
        fwd)
                        COMMAND='{"type":"ForwardCommand"}'
                        ;;
        rwd)
                        COMMAND='{"type":"RewindCommand"}'
                        ;;
        shuffle)
                        COMMAND='{"type":"ShuffleCommand","shuffle":"true"}'
                        ;;
        vol:*)
                        VOL=${COMMAND##*:}
                        # volume as integer!
                        if [ $VOL -le 100 -a $VOL -ge 0 ] ; then
                                COMMAND='{"type":"VolumeLevelCommand","volumeLevel":'${VOL}'}'
                        else
                                echo "ERROR: volume should be an integer between 0 and 100"
                                exit 1
                        fi
                        ;;
        "")
                        ;;
        *)
                        echo "ERROR: unknown command \"${COMMAND}\"!"
                        echo " valid commands are pause|play|next|prev|fwd|rwd|shuffle|vol:<0-100>"
                        exit 1
                        ;;
esac

#
# Amazon Login
#
log_in()
{
################################################################
#
# following headers are required:
#       Accept-Language (possibly for determining login region)
#       User-Agent      (CURL wouldn't store cookies without)
#
################################################################

rm -f ${DEVLIST}
rm -f ${COOKIE}

#
# get first cookie and write redirection target into referer
#
curl -s -D "${TMP}.alexa.header" -c ${COOKIE} -b ${COOKIE} -A "Mozilla/5.0" -H "Accept-Language: de,en" --compressed -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" -L\
 https://alexa.amazon.de | grep "hidden" | sed 's/hidden/\n/g' | grep "value=\"" | sed -E 's/^.*name="([^"]+)".*value="([^"]+)".*/\1=\2\&/g' > "${TMP}.alexa.postdata"

#
# login empty to generate sessiion
#
curl -s -c ${COOKIE} -b ${COOKIE} -A "Mozilla/5.0" -H "Accept-Language: de,en" --compressed -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" -L\
 -H "$(grep 'Location: ' ${TMP}.alexa.header | sed 's/Location: /Referer: /')" -d "@${TMP}.alexa.postdata" https://www.amazon.de/ap/signin | grep "hidden" | sed 's/hidden/\n/g' | grep "value=\"" | sed -E 's/^.*name="([^"]+)".*value="([^"]+)".*/\1=\2\&/g' > "${TMP}.alexa.postdata2"

#
# login with filled out form
#  !!! referer now contains session in URL
#
curl -s -c ${COOKIE} -b ${COOKIE} -A "Mozilla/5.0" -H "Accept-Language: de,en" --compressed -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" -L\
 -H "Referer: https://www.amazon.de/ap/signin/$(awk '$0 ~/.amazon.de.*session-id[\s\t]/ {print $7}' ${COOKIE})" --data-urlencode "email=${EMAIL}" --data-urlencode "password=${PASSWORD}" -d "@${TMP}.alexa.postdata2" https://www.amazon.de/ap/signin > /dev/null

#
# get CSRF
#
curl -s -c ${COOKIE} -b ${COOKIE} -A "Mozilla/5.0" --compressed -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Referer: https://alexa.amazon.de/spa/index.html" -H "Origin: https://alexa.amazon.de"\
 https://layla.amazon.de/api/language > /dev/null

#
# get JSON device list
#
curl -s -b ${COOKIE} -A "Mozilla/5.0" --compressed -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.amazon.de/spa/index.html" -H "Origin: https://alexa.amazon.de"\
 -H "csrf: $(awk '$0 ~/.amazon.de.*csrf[\s\t]/ {print $7}' ${COOKIE})"\
 https://layla.amazon.de/api/devices-v2/device > ${DEVLIST}

rm -f "${TMP}.alexa.header"
rm -f "${TMP}.alexa.postdata"
rm -f "${TMP}.alexa.postdata2"
}

check_status()
{
#
# bootstrap with GUI-Version writes GUI version to cookie
#  returns among other the current authentication state
#
        AUTHSTATUS=$(curl -s -c ${COOKIE} -b ${COOKIE} -A "Mozilla/5.0" --compressed -H "DNT: 1" -H "Connection: keep-alive" -L https://layla.amazon.de/api/bootstrap?version=${GUIVERSION} | sed -E 's/^.*"authenticated":([^,]+),.*$/\1/g')

        if [ "$AUTHSTATUS" = "true" ] ; then
                return 1
        fi

        return 0
}

#
# set device specific variables from JSON device list
#
set_var()
{
        if [ -z "${DEVICE}" ] ; then
                # if no device was supplied, use the first Echo(dot) in device list
                echo "setting default device to:"
                DEVICE=$(jq -r '[ .devices[] | select(.deviceFamily == "ECHO" ) | .accountName] | .[0]' ${DEVLIST})
                echo ${DEVICE}
        fi

        DEVICETYPE=$(jq --arg device ${DEVICE} -r '.devices[] | select(.accountName == $device) | .deviceType' ${DEVLIST})
        DEVICESERIALNUMBER=$(jq --arg device ${DEVICE} -r '.devices[] | select(.accountName == $device) | .serialNumber' ${DEVLIST})
        MEDIAOWNERCUSTOMERID=$(jq --arg device ${DEVICE} -r '.devices[] | select(.accountName == $device) | .deviceOwnerCustomerId' ${DEVLIST})

        if [ -z "${DEVICESERIALNUMBER}" ] ; then
                echo "ERROR: unkown device dev:${DEVICE}"
                exit 1
        fi
}

#
# list available devices from JSON device list
#
list_devices()
{
        jq -r '.devices[].accountName' ${DEVLIST}
}

#
# execute command
#
run_cmd()
{
curl -s -b ${COOKIE} -A "Mozilla/5.0" --compressed -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.amazon.de/spa/index.html" -H "Origin: https://alexa.amazon.de"\
 -H "csrf: $(awk '$0 ~/.amazon.de.*csrf[\s\t]/ {print $7}' ${COOKIE})" -X POST -d ${COMMAND}\
 "https://layla.amazon.de/api/np/command?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}" > /dev/null
}

#
# play TuneIn radio station
#
play_radio()
{
curl -s -b ${COOKIE} -A "Mozilla/5.0" --compressed -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.amazon.de/spa/index.html" -H "Origin: https://alexa.amazon.de"\
 -H "csrf: $(awk '$0 ~/.amazon.de.*csrf[\s\t]/ {print $7}' ${COOKIE})" -X POST\
 "https://layla.amazon.de/api/tunein/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&guideId=${STATIONID}&contentType=station&callSign=&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}" > /dev/null
}

#
# play library track
#
play_song()
{
curl -s -b ${COOKIE} -A "Mozilla/5.0" --compressed -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.amazon.de/spa/index.html" -H "Origin: https://alexa.amazon.de"\
 -H "csrf: $(awk '$0 ~/.amazon.de.*csrf[\s\t]/ {print $7}' ${COOKIE})" -X POST -d "{\"trackId\":\"${SONG}\",\"isoTimestamp\":\"$(date --utc +%FT%T.%3NZ)\",\"playQueuePrime\":false}"\
 "https://layla.amazon.de/api/cloudplayer/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&guideId=${STATIONID}&contentType=station&callSign=&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}&shuffle=false" > /dev/null
}




#
# logout
#
log_off()
{
curl -s -c ${COOKIE} -b ${COOKIE} -A "Mozilla/5.0" --compressed -H "DNT: 1" -H "Connection: keep-alive" -L\
 https://layla.amazon.de/logout > /dev/null

rm -f ${DEVLIST}
rm -f ${COOKIE}
}

if [ -z "$LIST" -a -z "$COMMAND" -a -z "$STATIONID" -a -z "$SONG" -a -n "$LOGOFF" ] ; then
        echo "only logout option present, logging off ..."
        log_off
        exit 0
fi

if [ ! -f ${DEVLIST} -o ! -f ${COOKIE} ] ; then
        echo "files do not exist. logging in ..."
        log_in
fi

check_status
if [ $? -eq 0 ] ; then
        echo "cookie expired, logging in again ..."
        log_in
fi

if [ -n "$COMMAND" ] ; then
        if [ "${DEVICE}" = "ALL" ] ; then
                for DEVICE in $(jq -r '.devices[] | select( .deviceFamily == "ECHO" or .deviceFamily == "WHA") | .accountName' ${DEVLIST}) ; do
                        set_var
                        echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
                        run_cmd
                done
        else
                set_var
                echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
                run_cmd
        fi
elif [ -n "$STATIONID" ] ; then
        set_var
        echo "playing stationID:${STATIONID} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
        play_radio
elif [ -n "$SONG" ] ; then
        set_var
        echo "playing library track:${SONG} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
        play_song
elif [ -n "$LIST" ] ; then
        echo "the following devices exist in your account:"
        list_devices
else
        echo "no alexa command received"
fi

if [ -n "$LOGOFF" ] ; then
        echo "logout option present, logging off ..."
        log_off
fi
