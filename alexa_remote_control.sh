#!/bin/sh
#
# Amazon Alexa Remote Control
#  alex(at)loetzimmer.de
#
# 2017-10-10: v0.1 initial release
# 2017-10-11: v0.2 TuneIn Station Search
# 2017-10-11: v0.2a commands on special device "ALL" are executed on all ECHO+WHA
# 2017-10-16: v0.3 added playback of library tracks
# 2017-10-24: v0.4 added playback information
# 2017-11-21: v0.5 added Prime station and playlist
# 2017-11-22: v0.6 added Prime historical queue and replaced getopts
# 2017-11-25: v0.6a cURL is now configurable
# 2017-11-25: v0.7 added multiroom create/delete, playback of library playlist
# 2017-11-30: v0.7a added US config, fixed device names containing spaces
# 2017-12-07: v0.7b added Bluetooth connect/disconnect
# 2017-12-18: v0.7c fixed US version
# 2017-12-19: v0.7d fixed AWK csrf extraction on some systems
# 2017-12-20: v0.7e moved get_devlist after check_status
# 2018-01-08: v0.7f added echo-show to ALL group, TuneIn station can now be up to 6 digits
# 2018-01-08: v0.8 added bluetooth list function
# 2018-01-10: v0.8a abort when login was unsuccessful
# 2018-01-25: v0.8b added echo-spot to ALL group
# 2018-01-28: v0.8c added configurable browser string
# 2018-02-17: v0.8d no need to write the cookie file on every "check_status"
# 2018-02-27: v0.8e added "lastalexa" option for HA-Bridge to send its command to a specific device
#               (Markus Wennesheimer: https://wennez.wordpress.com/light-on-with-alexa-for-each-room/)
# 2018-02-27: v0.9 unsuccessful logins will now give a short info how to debug the login
# 2018-03-09: v0.9a workaround for login problem, force curl to use http1.1
# 2018-05-17: v0.9b update browser string and accept language
# 2018-05-23: v0.9c update accept language (again)
# 2018-06-12: v0.10 introducing TTS and more
#               (thanks to Michael Geramb and his openHAB2 Amazon Echo Control binding)
#               https://github.com/openhab/openhab2-addons/tree/master/addons/binding/org.openhab.binding.amazonechocontrol
#               (thanks to Ralf Otto for implementing this feature in this script)
# 2018-06-13: v0.10a added album play of imported library
# 2018-06-18: v0.10b added Alexa routine execution
# 2019-01-22: v0.11 added repeat command, added environment variable parsing
# 2019-02-03: v0.11a fixed string escape for automation and speak commands
# 2019-02-10: v0.12 added "-d ALL" to the plain version, lastalexa now checks for SUCCESS activityStatus
# 2019-02-14: v0.12a reduced the number of replaced characters for TTS and automation
# 2019-06-18: v0.12b fixed CSRF
# 2019-06-28: v0.12c properly fixed CSRF
# 2019-07-08: v0.13 added support for Multi-Factor Authentication
#               (thanks to rich-gepp https://github.com/rich-gepp)
# 2019-08-05: v0.14 added Volume setting via routine, and $SPEAKVOL
# 2019-11-18: v0.14a download 200 routines instead of only the first 20
# 2019-12-06: v0.15 support iHeartRadio station ids
#
###
#
# (no BASHisms were used, should run with any shell)
# - requires cURL for web communication
# - (GNU) sed and awk for extraction
# - jq as command line JSON parser (optional for the fancy bits)
# - oathtool as OATH one-time password tool (optional for two-factor authentication)
#
##########################################

SET_EMAIL='amazon_account@email.address'
SET_PASSWORD='Very_Secret_Amazon_Account_Password'
SET_MFA_SECRET=''
# something like:
#  1234 5678 9ABC DEFG HIJK LMNO PQRS TUVW XYZ0 1234 5678 9ABC DEFG

SET_LANGUAGE='de,en-US;q=0.7,en;q=0.3'
#SET_LANGUAGE='en-US'

SET_TTS_LOCALE='de-DE'

SET_AMAZON='amazon.de'
#SET_AMAZON='amazon.com'

SET_ALEXA='alexa.amazon.de'
#SET_ALEXA='pitangui.amazon.com'

# cURL binary
SET_CURL='/usr/bin/curl'

# cURL options
#  -k : if your cURL cannot verify CA certificates, you'll have to trust any
#  --compressed : if your cURL was compiled with libz you may use compression
#  --http1.1 : cURL defaults to HTTP/2 on HTTPS connections if available
SET_OPTS='--compressed --http1.1'
#SET_OPTS='-k --compressed --http1.1'

# browser identity
SET_BROWSER='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:1.0) bash-script/1.0'
#SET_BROWSER='Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:65.0) Gecko/20100101 Firefox/65.0'

# oathtool command line tool
SET_OATHTOOL='/usr/bin/oathtool'

# tmp path
SET_TMP="/tmp"

# Volume for speak commands
SET_SPEAKVOL="30"
# if no current playing volume can be determined, fall back to normal volume
SET_NORMALVOL="10"

###########################################
# nothing to configure below here
#

# retrieving environment variables if any are set
EMAIL=${EMAIL:-$SET_EMAIL}
PASSWORD=${PASSWORD:-$SET_PASSWORD}
MFA_SECRET=${MFA_SECRET:-$SET_MFA_SECRET}
AMAZON=${AMAZON:-$SET_AMAZON}
ALEXA=${ALEXA:-$SET_ALEXA}
LANGUAGE=${LANGUAGE:-$SET_LANGUAGE}
BROWSER=${BROWSER:-$SET_BROWSER}
CURL=${CURL:-$SET_CURL}
OPTS=${OPTS:-$SET_OPTS}
TTS_LOCALE=${TTS_LOCALE:-$SET_TTS_LOCALE}
TMP=${TMP:-$SET_TMP}
OATHTOOL=${OATHTOOL:-$SET_OATHTOOL}
SPEAKVOL=${SPEAKVOL:-$SET_SPEAKVOL}
NORMALVOL=${NORMALVOL:-$SET_NORMALVOL}

COOKIE="${TMP}/.alexa.cookie"
DEVLIST="${TMP}/.alexa.devicelist.json"

GUIVERSION=0

LIST=""
LOGOFF=""
COMMAND=""
TTS=""
UTTERANCE=""
SEQUENCECMD=""
SEQUENCEVAL=""
STATIONID=""
IHEARTID=""
QUEUE=""
SONG=""
ALBUM=""
ARTIST=""
TYPE=""
ASIN=""
SEEDID=""
HIST=""
LEMUR=""
CHILD=""
PLIST=""
BLUETOOTH=""
LASTALEXA=""

usage()
{
	echo "$0 [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|repeat|vol:<0-100>> |"
	echo "          -b [list|<\"AA:BB:CC:DD:EE:FF\">] | -q | -r <\"station name\"|stationid> |  -c <iHeart stationid> |"
	echo "          -s <trackID|'Artist' 'Album'> | -t <ASIN> | -u <seedID> | -v <queueID> | -w <playlistId> |"
	echo "          -i | -p | -P | -S | -a | -m <multiroom_device> [device_1 .. device_X] | -lastalexa | -l | -h"
	echo
	echo "   -e : run command, additional SEQUENCECMDs:"
	echo "        weather,traffic,flashbriefing,goodmorning,singasong,tellstory,speak:'<text>',automation:'<routine name>'"
	echo "   -b : connect/disconnect/list bluetooth device"
	echo "   -q : query queue"
	echo "   -n : query notifications"
	echo "   -r : play tunein radio"
	echo "   -c : play iHeartRadio station"
	echo "   -s : play library track/library album"
	echo "   -t : play Prime playlist"
	echo "   -u : play Prime station"
	echo "   -v : play Prime historical queue"
	echo "   -w : play library playlist"
	echo "   -i : list imported library tracks"
	echo "   -p : list purchased library tracks"
	echo "   -P : list Prime playlists"
	echo "   -S : list Prime stations"
	echo "   -a : list available devices"
	echo "   -m : delete multiroom and/or create new multiroom containing devices"
	echo "   -lastalexa : print device that received the last voice command"
	echo "   -l : logoff"
	echo "   -h : help"
}

while [ "$#" -gt 0 ] ; do
	case "$1" in
		-d)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			DEVICE=$2
			shift
			;;
		-e)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			COMMAND=$2
			shift
			;;
		-b)
			if [ "${2#-}" = "${2}" -a -n "$2" ] ; then
				BLUETOOTH=$2
				shift
			else
				BLUETOOTH="null"
			fi
			;;
		-m)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			LEMUR=$2
			shift
			while [ "${2#-}" = "${2}" -a -n "$2" ] ; do
				CHILD="${CHILD} ${2}"
				shift
			done
			;;
		-r)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			STATIONID=$2
			shift
			# stationIDs are "s1234" or "s12345"
			if [ -n "${STATIONID##s[0-9][0-9][0-9][0-9]}" -a -n "${STATIONID##s[0-9][0-9][0-9][0-9][0-9]}" -a -n "${STATIONID##s[0-9][0-9][0-9][0-9][0-9][0-9]}" ] ; then
				# search for station name
				STATIONID=$(${CURL} ${OPTS} -s --data-urlencode "query=${STATIONID}" -G "https://api.tunein.com/profiles?fullTextSearch=true" | jq -r '.Items[] | select(.ContainerType == "Stations") | .Children[] | select( .Index==1 ) | .GuideId')
				if [ -z "$STATIONID" ] ; then
					echo "ERROR: no Station \"$2\" found on TuneIn"
					exit 1
				fi
			fi
			;;
		-c)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			IHEARTID=$2
			shift
			;;
		-s)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			SONG=$2
			shift
			if [ "${2#-}" = "${2}" -a -n "$2" ] ; then
				ALBUM=$2
				ARTIST=$SONG
				shift
			fi
			;;
		-t)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			ASIN=$2
			shift
			;;
		-u)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			SEEDID=$2
			shift
			;;
		-v)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			HIST=$2
			shift
			;;
		-w)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			PLIST=$2
			shift
			;;
		-l)
			LOGOFF="true"
			;;
		-a)
			LIST="true"
			;;
		-i)
			TYPE="IMPORTED"
			;;
		-p)
			TYPE="PURCHASES"
			;;
		-P)
			PRIME="prime-playlist-browse-nodes"
			;;
		-S)
			PRIME="prime-sections"
			;;
		-q)
			QUEUE="true"
			;;
		-n)
			NOTIFICATIONS="true"
			;;
		-lastalexa)
			LASTALEXA="true"
			;;
		-h|-\?|--help)
			usage
			exit 0
			;;
		*)
			echo "ERROR: unknown option ${1}"
			usage
			exit 1
			;;
	esac
	shift
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
	repeat)
			COMMAND='{"type":"RepeatCommand","repeat":true}'
			;;
	vol:*)
			VOL=${COMMAND##*:}
			# volume as integer!
			if [ $VOL -le 100 -a $VOL -ge 0 ] ; then
#				COMMAND='{"type":"VolumeLevelCommand","volumeLevel":'${VOL}'}'
				SEQUENCECMD='Alexa.DeviceControls.Volume'
				SEQUENCEVAL=',\"value\":\"'${VOL}'\"'
			else
				echo "ERROR: volume should be an integer between 0 and 100"
				usage
				exit 1
			fi
			;;
	speak:*)
			SEQUENCECMD='Alexa.Speak'
			TTS=$(echo ${COMMAND##*:} | sed -r 's/["\\]/ /g')
			TTS=',\"textToSpeak\":\"'${TTS}'\"'
			;;
	automation:*)
			SEQUENCECMD='automation'
			UTTERANCE=$(echo ${COMMAND##*:} | sed -r 's/["\\]/ /g')
			;;
	weather)
			SEQUENCECMD='Alexa.Weather.Play'
			;;
	traffic)
			SEQUENCECMD='Alexa.Traffic.Play'
			;;
	flashbriefing)
			SEQUENCECMD='Alexa.FlashBriefing.Play'
			;;
	goodmorning)
			SEQUENCECMD='Alexa.GoodMorning.Play'
			;;
	singasong)
			SEQUENCECMD='Alexa.SingASong.Play'
			;;
	tellstory)
			SEQUENCECMD='Alexa.TellStory.Play'
			;;
	"")
			;;
	*)
			echo "ERROR: unknown command \"${COMMAND}\"!"
			usage
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
#	Accept-Language	(possibly for determining login region)
#	User-Agent	(cURL wouldn't store cookies without)
#
################################################################

rm -f ${DEVLIST}
rm -f ${COOKIE}
rm -f ${TMP}/.alexa.*.list

#
# get first cookie and write redirection target into referer
#
${CURL} ${OPTS} -s -D "${TMP}/.alexa.header" -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "Accept-Language: ${LANGUAGE}" -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" -L\
 https://alexa.${AMAZON} | grep "hidden" | sed 's/hidden/\n/g' | grep "value=\"" | sed -r 's/^.*name="([^"]+)".*value="([^"]+)".*/\1=\2\&/g' > "${TMP}/.alexa.postdata"

#
# login empty to generate session
#
${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "Accept-Language: ${LANGUAGE}" -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" -L\
 -H "$(grep 'Location: ' ${TMP}/.alexa.header | sed 's/Location: /Referer: /')" -d "@${TMP}/.alexa.postdata" https://www.${AMAZON}/ap/signin | grep "hidden" | sed 's/hidden/\n/g' | grep "value=\"" | sed -r 's/^.*name="([^"]+)".*value="([^"]+)".*/\1=\2\&/g' > "${TMP}/.alexa.postdata2"

#
# add OTP if using MFA
#
if [ -n "${MFA_SECRET}" ] ; then
	OTP=$(${OATHTOOL} -b --totp "${MFA_SECRET}")
	PASSWORD="${PASSWORD}${OTP}"
fi

#
# login with filled out form
#  !!! referer now contains session in URL
#
${CURL} ${OPTS} -s -D "${TMP}/.alexa.header2" -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "Accept-Language: ${LANGUAGE}" -H "DNT: 1" -H "Connection: keep-alive" -H "Upgrade-Insecure-Requests: 1" -L\
 -H "Referer: https://www.${AMAZON}/ap/signin/$(awk "\$0 ~/.${AMAZON}.*session-id[ \\s\\t]+/ {print \$7}" ${COOKIE})" --data-urlencode "email=${EMAIL}" --data-urlencode "password=${PASSWORD}" -d "@${TMP}/.alexa.postdata2" https://www.${AMAZON}/ap/signin > "${TMP}/.alexa.login"

# check whether the login has been successful or exit otherwise
if [ -z "$(grep 'Location: https://alexa.*html' ${TMP}/.alexa.header2)" ] ; then
	echo "ERROR: Amazon Login was unsuccessful. Possibly you get a captcha login screen."
	echo " Try logging in to https://alexa.${AMAZON} with your browser. In your browser"
	echo " make sure to have all Amazon related cookies deleted and Javascript disabled!"
	echo
	echo " (For more information have a look at ${TMP}/.alexa.login)"
	echo
	echo " To avoid issues with captcha, try using Multi-Factor Authentication."
	echo " To do so, first set up Two-Step Verification on your Amazon account, then"
	echo " configure this script (or the environment) with your MFA secret."
	echo " Support for Multi-Factor Authentication requires 'oathtool' to be installed."

	rm -f ${COOKIE}
	rm -f "${TMP}/.alexa.header"
	rm -f "${TMP}/.alexa.header2"
	rm -f "${TMP}/.alexa.postdata"
	rm -f "${TMP}/.alexa.postdata2"
	exit 1
fi

#
# get CSRF
#
${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 https://${ALEXA}/api/language > /dev/null

if [ -z "$(grep ".${AMAZON}.*csrf" ${COOKIE})" ] ; then
	echo "trying to get CSRF from handlebars"
	${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 https://${ALEXA}/templates/oobe/d-device-pick.handlebars > /dev/null
fi

if [ -z "$(grep ".${AMAZON}.*csrf" ${COOKIE})" ] ; then
	echo "trying to get CSRF from devices-v2"
	${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 https://${ALEXA}/api/devices-v2/device?cached=false > /dev/null
fi

rm -f "${TMP}/.alexa.login"
rm -f "${TMP}/.alexa.header"
rm -f "${TMP}/.alexa.header2"
rm -f "${TMP}/.alexa.postdata"
rm -f "${TMP}/.alexa.postdata2"

if [ -z "$(grep ".${AMAZON}.*csrf" ${COOKIE})" ] ; then
	echo "ERROR: no CSRF cookie received"
	exit 1
fi
}

#
# get JSON device list
#
get_devlist()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})"\
 "https://${ALEXA}/api/devices-v2/device?cached=false" > ${DEVLIST}
}

check_status()
{
#
# bootstrap with GUI-Version writes GUI version to cookie
#  returns among other the current authentication state
#
	AUTHSTATUS=$(${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L https://${ALEXA}/api/bootstrap?version=${GUIVERSION})
	MEDIAOWNERCUSTOMERID=$(echo $AUTHSTATUS | sed -r 's/^.*"customerId":"([^,]+)",.*$/\1/g')
	AUTHSTATUS=$(echo $AUTHSTATUS | sed -r 's/^.*"authenticated":([^,]+),.*$/\1/g')

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
	DEVICE=$(echo ${DEVICE} | sed -r 's/%20/ /g')

	if [ -z "${DEVICE}" ] ; then
		# if no device was supplied, use the first Echo(dot) in device list
		echo "setting default device to:"
		DEVICE=$(jq -r '[ .devices[] | select(.deviceFamily == "ECHO" or .deviceFamily == "KNIGHT" or .deviceFamily == "ROOK" ) | .accountName] | .[0]' ${DEVLIST})
		echo ${DEVICE}
	fi

	DEVICETYPE=$(jq --arg device "${DEVICE}" -r '.devices[] | select(.accountName == $device) | .deviceType' ${DEVLIST})
	DEVICESERIALNUMBER=$(jq --arg device "${DEVICE}" -r '.devices[] | select(.accountName == $device) | .serialNumber' ${DEVLIST})

	# customerId is now retrieved from the logged in user
	# the customerId in the device list is always from the user registering the device initially
	# MEDIAOWNERCUSTOMERID=$(jq --arg device "${DEVICE}" -r '.devices[] | select(.accountName == $device) | .deviceOwnerCustomerId' ${DEVLIST})

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
# (SequenceCommands by Michael Geramb and Ralf Otto)
#
run_cmd()
{
if [ -n "${SEQUENCECMD}" ] ; then
	if [ "${SEQUENCECMD}" = 'automation' ] ; then

		${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
		 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
		 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
		 "https://${ALEXA}/api/behaviors/automations?limit=200" > "${TMP}/.alexa.automation"

		AUTOMATION=$(jq --arg utterance "${UTTERANCE}" -r '.[] | select( .triggers[].payload.utterance == $utterance) | .automationId' "${TMP}/.alexa.automation")
		if [ -z "${AUTOMATION}" ] ; then
			echo "ERROR: no such utterance '${UTTERANCE}' in Alexa routines"
			rm -f "${TMP}/.alexa.automation"
			exit 1
		fi
		SEQUENCE=$(jq --arg utterance "${UTTERANCE}" -r -c '.[] | select( .triggers[].payload.utterance == $utterance) | .sequence' "${TMP}/.alexa.automation" | sed 's/"/\\"/g' | sed "s/ALEXA_CURRENT_DEVICE_TYPE/${DEVICETYPE}/g" | sed "s/ALEXA_CURRENT_DSN/${DEVICESERIALNUMBER}/g" | sed "s/ALEXA_CUSTOMER_ID/${MEDIAOWNERCUSTOMERID}/g")
		rm -f "${TMP}/.alexa.automation"

		ALEXACMD='{"behaviorId":"'${AUTOMATION}'","sequenceJson":"'${SEQUENCE}'","status":"ENABLED"}'
	else
		# the speak command is treated differently in that the wolume gets set to $SPEAKVOL
		if [ -n "${TTS}" ] ; then 

			# try to retrieve the "currently playing" volume
			VOL=$(${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
			 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
			 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
			 "https://${ALEXA}/api/media/state?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}" | grep 'volume' | sed -r 's/^.*"volume":\s*([0-9]+)[^0-9]*$/\1/g')

			if [ -z "${VOL}" ] ; then VOL=$NORMALVOL ; fi

			ALEXACMD='{"behaviorId":"PREVIEW","sequenceJson":"{\"@type\":\"com.amazon.alexa.behaviors.model.Sequence\",\"startNode\":{\"@type\":\"com.amazon.alexa.behaviors.model.SerialNode\",\"nodesToExecute\":[{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"Alexa.DeviceControls.Volume\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\",\"value\":\"'${SPEAKVOL}'\"}},{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"'${SEQUENCECMD}'\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\"'${TTS}'}},{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"Alexa.DeviceControls.Volume\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\",\"value\":\"'${VOL}'\"}}]}}","status":"ENABLED"}'
		else
			ALEXACMD='{"behaviorId":"PREVIEW","sequenceJson":"{\"@type\":\"com.amazon.alexa.behaviors.model.Sequence\",\"startNode\":{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"'${SEQUENCECMD}'\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\"'${SEQUENCEVAL}'}}}","status":"ENABLED"}'
		fi
	fi

	# Due to some weird shell-escape-behavior the command has to be written to a file before POSTing it
	echo $ALEXACMD > "${TMP}/.alexa.cmd"

	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d @"${TMP}/.alexa.cmd" \
	 "https://${ALEXA}/api/behaviors/preview"

	rm -f "${TMP}/.alexa.cmd"

else
	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d ${COMMAND}\
	 "https://${ALEXA}/api/np/command?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
fi
}

#
# play TuneIn radio station
#
play_radio()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST\
 "https://${ALEXA}/api/tunein/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&guideId=${STATIONID}&contentType=station&callSign=&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}"
}

#
# play iHeart radio station
#
play_iheart()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST\
 "https://${ALEXA}/api/iheartradio/queue-and-play-live-station" -d '{"deviceSerialNumber": "'${DEVICESERIALNUMBER}'", "deviceType": "'${DEVICETYPE}'", "stationId": "'${IHEARTID}'", "mediaOwnerCustomerId": "'${MEDIAOWNERCUSTOMERID}'"}'
}

#
# play library track
#
play_song()
{
	if [ -z "${ALBUM}" ] ; then
		JSON="{\"trackId\":\"${SONG}\",\"playQueuePrime\":true}"
	else
		JSON="{\"albumArtistName\":\"${ARTIST}\",\"albumName\":\"${ALBUM}\"}"
	fi

${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "${JSON}"\
 "https://${ALEXA}/api/cloudplayer/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}&shuffle=false"
}

#
# play library playlist
#
play_playlist()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"playlistId\":\"${PLIST}\",\"playQueuePrime\":true}"\
 "https://${ALEXA}/api/cloudplayer/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}&shuffle=false"
}

#
# play PRIME playlist
#
play_prime_playlist()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"asin\":\"${ASIN}\"}"\
 "https://${ALEXA}/api/prime/prime-playlist-queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}"
}

#
# play PRIME station
#
play_prime_station()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"seed\":\"{\\\"type\\\":\\\"KEY\\\",\\\"seedId\\\":\\\"${SEEDID}\\\"}\",\"stationName\":\"none\",\"seedType\":\"KEY\"}"\
 "https://${ALEXA}/api/gotham/queue-and-play?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}"
}

#
# play PRIME historical queue
#
play_prime_hist_queue()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"deviceType\":\"${DEVICETYPE}\",\"deviceSerialNumber\":\"${DEVICESERIALNUMBER}\",\"mediaOwnerCustomerId\":\"${MEDIAOWNERCUSTOMERID}\",\"queueId\":\"${HIST}\",\"service\":null,\"trackSource\":\"TRACK\"}"\
 "https://${ALEXA}/api/media/play-historical-queue"
}

#
# show library tracks
#
show_library()
{
	OFFSET="";
	SIZE=50;
	TOTAL=0;
	FILE=${TMP}/.alexa.${TYPE}.list

	if [ ! -f ${FILE} ] ; then
		echo -n '{"playlist":{"entryList":[' > ${FILE}

		while [ 50 -le ${SIZE} ] ; do

${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/cloudplayer/playlists/${TYPE}-V0-OBJECTID?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&size=${SIZE}&offset=${OFFSET}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}" > ${FILE}.tmp

			OFFSET=$(jq -r '.nextResultsToken' ${FILE}.tmp)
			SIZE=$(jq -r '.playlist | .trackCount' ${FILE}.tmp)
			jq -r -c '.playlist | .entryList' ${FILE}.tmp >> ${FILE}
			echo "," >> ${FILE}
			TOTAL=$((TOTAL+SIZE))
		done
		echo "[]],\"trackCount\":\"${TOTAL}\"}}" >> ${FILE}
		rm -f ${FILE}.tmp
	fi
	jq -r '.playlist.trackCount' ${FILE}
	jq '.playlist.entryList[] | .[]' ${FILE}
}

#
# show Prime stations and playlists
#
show_prime()
{
	FILE=${TMP}/.alexa.${PRIME}.list

	if [ ! -f ${FILE} ] ; then
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/prime/{$PRIME}?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}" > ${FILE}

		if [ "$PRIME" = "prime-playlist-browse-nodes" ] ; then
			for I in $(jq -r '.primePlaylistBrowseNodeList[].subNodes[].nodeId' ${FILE} 2>/dev/null) ; do
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/prime/prime-playlists-by-browse-node?browseNodeId=${I}&deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}&mediaOwnerCustomerId=${MEDIAOWNERCUSTOMERID}" >> ${FILE}
			done
		fi
	fi
	jq '.' ${FILE}
}

#
# current queue
#
show_queue()
{
	PARENT=""
	PARENTID=$(jq --arg device "${DEVICE}" -r '.devices[] | select(.accountName == $device) | .parentClusters[0]' ${DEVLIST})
	if [ "$PARENTID" != "null" ] ; then
		PARENTDEVICE=$(jq --arg serial ${PARENTID} -r '.devices[] | select(.serialNumber == $serial) | .deviceType' ${DEVLIST})
		PARENT="&lemurId=${PARENTID}&lemurDeviceType=${PARENTDEVICE}"
	fi
	
 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
  -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
  -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
  "https://${ALEXA}/api/np/player?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}${PARENT}" | jq '.'

 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
  -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
  -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
  "https://${ALEXA}/api/media/state?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}" | jq '.'

 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
  -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
  -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
  "https://${ALEXA}/api/np/queue?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}" | jq '.'
}

#
# show notifications and alarms
#
show_notifications()
{
	echo "/api/notifications"
 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/notifications?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
	echo
}

#
# deletes a multiroom device
#
delete_multiroom()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X DELETE \
 "https://${ALEXA}/api/lemur/tail/${DEVICESERIALNUMBER}"
}

#
# creates a multiroom device
#
create_multiroom()
{
	JSON="{\"id\":null,\"name\":\"${LEMUR}\",\"members\":["
	for DEVICE in $CHILD ; do
		set_var
		JSON="${JSON}{\"dsn\":\"${DEVICESERIALNUMBER}\",\"deviceType\":\"${DEVICETYPE}\"},"
	done
	JSON="${JSON%,}]}"

${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "${JSON}" \
 "https://${ALEXA}/api/lemur/tail"
}

#
# list bluetooth devices
#
list_bluetooth()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/bluetooth?cached=false" | jq --arg serial "${DEVICESERIALNUMBER}" -r '.bluetoothStates[] | select(.deviceSerialNumber == $serial) | "\(.pairedDeviceList[]?.address) \(.pairedDeviceList[]?.friendlyName)"'
}

#
# connect bluetooth device
#
connect_bluetooth()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d "{\"bluetoothDeviceAddress\":\"${BLUETOOTH}\"}"\
 "https://${ALEXA}/api/bluetooth/pair-sink/${DEVICETYPE}/${DEVICESERIALNUMBER}"
}

#
# disconnect bluetooth device
#
disconnect_bluetooth()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST \
 "https://${ALEXA}/api/bluetooth/disconnect-sink/${DEVICETYPE}/${DEVICESERIALNUMBER}"
}

#
# device that sent the last command
# (by Markus Wennesheimer)
#
last_alexa()
{
${CURL} ${OPTS} -s -b ${COOKIE} -A "Mozilla/5.0" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/activities?startTime=&size=10&offset=1" | jq -r '[.activities[] | select( .activityStatus == "SUCCESS" )][0] | .sourceDeviceIds[0].serialNumber' | xargs -i jq -r --arg device {} '.devices[] | select( .serialNumber == $device) | .accountName' ${DEVLIST}
# Serial number: | jq -r '[.activities[] | select( .activityStatus == "SUCCESS" )][0] | .sourceDeviceIds[0].serialNumber'
# Device name:   | jq -r '[.activities[] | select( .activityStatus == "SUCCESS" )][0] | .sourceDeviceIds[0].serialNumber' | xargs -i jq -r --arg device {} '.devices[] | select( .serialNumber == $device) | .accountName' ${DEVLIST}
 }

#
# logout
#
log_off()
{
${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 https://${ALEXA}/logout > /dev/null

rm -f ${DEVLIST}
rm -f ${COOKIE}
rm -f ${TMP}/.alexa.*.list
}

if [ -z "$LASTALEXA" -a -z "$BLUETOOTH" -a -z "$LEMUR" -a -z "$PLIST" -a -z "$HIST" -a -z "$SEEDID" -a -z "$ASIN" -a -z "$PRIME" -a -z "$TYPE" -a -z "$QUEUE" -a -z "$NOTIFICATIONS" -a -z "$LIST" -a -z "$COMMAND" -a -z "$STATIONID" -a -z "$IHEARTID" -a -z "$SONG" -a -n "$LOGOFF" ] ; then
	echo "only logout option present, logging off ..."
	log_off
	exit 0
fi

if [ ! -f ${COOKIE} ] ; then
	echo "cookie does not exist. logging in ..."
	log_in
fi

check_status
if [ $? -eq 0 ] ; then
	echo "cookie expired, logging in again ..."
	log_in
	check_status
	if [ $? -eq 0 ] ; then
		echo "log in failed, aborting"
		exit 1
	fi
fi

if [ ! -f ${DEVLIST} ] ; then
	echo "device list does not exist. downloading ..."
	get_devlist
	if [ ! -f ${DEVLIST} ] ; then
		echo "failed to download device list, aborting"
		exit 1
	fi
fi

if [ -n "$COMMAND" -o -n "$QUEUE" ] ; then
	if [ "${DEVICE}" = "ALL" ] ; then
		for DEVICE in $(jq -r '.devices[] | select( .deviceFamily == "ECHO" or .deviceFamily == "KNIGHT" or .deviceFamily == "ROOK" or .deviceFamily == "WHA") | .accountName' ${DEVLIST} | sed -r 's/ /%20/g') ; do
			set_var
			if [ -n "$COMMAND" ] ; then
				echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
				run_cmd
				# in order to prevent a "Rate exceeded" we need to delay the command
				sleep 1
				echo
			else
				echo "queue info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
				show_queue
				echo
			fi
		done
	else
		set_var
		if [ -n "$COMMAND" ] ; then
			echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
			run_cmd
			echo
		else
			echo "queue info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
			show_queue
			echo
		fi
	fi
elif [ -n "$COMMAND" -o -n "$NOTIFICATIONS" ] ; then
	if [ "${DEVICE}" = "ALL" ] ; then
		while IFS= read -r DEVICE ; do
			set_var
			if [ -n "$COMMAND" ] ; then
				echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
				run_cmd
				# in order to prevent a "Rate exceeded" we need to delay the command
				sleep 1
				echo
			else
				echo "notifications info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
				show_notifications
				echo
			fi
		done < ${DEVALL}
	else
		set_var
		if [ -n "$COMMAND" ] ; then
			echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
			run_cmd
			echo
		else
			echo "notifications info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
			show_notifications
			echo
		fi
	fi
elif [ -n "$LEMUR" ] ; then
	DEVICESERIALNUMBER=$(jq --arg device "${LEMUR}" -r '.devices[] | select(.accountName == $device and .deviceFamily == "WHA") | .serialNumber' ${DEVLIST})
	if [ -n "$DEVICESERIALNUMBER" ] ; then
		delete_multiroom
	else
		if [ -z "$CHILD" ] ; then
			echo "ERROR: ${LEMUR} is no multiroom device. Cannot delete ${LEMUR}".
			exit 1
		fi
	fi
	if [ -z "$CHILD" ] ; then
		echo "Deleted multi room dev:${LEMUR} serial:${DEVICESERIALNUMBER}"
	else
		echo "Creating multi room dev:${LEMUR} member_dev(s):${CHILD}"
		create_multiroom
		echo
	fi
	rm -f ${DEVLIST}
	get_devlist
elif [ -n "$BLUETOOTH" ] ; then
	if [ "$BLUETOOTH" = "list" -o "$BLUETOOTH" = "List" -o "$BLUETOOTH" = "LIST" ] ; then
		if [ "${DEVICE}" = "ALL" ] ; then
			for DEVICE in $(jq -r '.devices[] | select( .deviceFamily == "ECHO" or .deviceFamily == "KNIGHT" or .deviceFamily == "ROOK" or .deviceFamily == "WHA") | .accountName' ${DEVLIST} | sed -r 's/ /%20/g') ; do
				set_var
				echo "bluetooth devices for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}:"
				list_bluetooth
				echo
			done
		else
			set_var
			echo "bluetooth devices for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}:"
			list_bluetooth
			echo
		fi
	elif [ "$BLUETOOTH" = "null" ] ; then
		set_var
		echo "disconnecting dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} from bluetooth"
		disconnect_bluetooth
		echo
	else
		set_var
		echo "connecting dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} to bluetooth device:${BLUETOOTH}"
		connect_bluetooth
		echo
	fi
elif [ -n "$STATIONID" ] ; then
	set_var
	echo "playing stationID:${STATIONID} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_radio
elif [ -n "$IHEARTID" ] ; then
	set_var
	echo "playing stationID:${STATIONID} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_iheart
elif [ -n "$SONG" ] ; then
	set_var
	echo "playing library track:${SONG} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_song
elif [ -n "$PLIST" ] ; then
	set_var
	echo "playing library playlist:${PLIST} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_playlist
elif [ -n "$LIST" ] ; then
	echo "the following devices exist in your account:"
	list_devices
elif [ -n "$TYPE" ] ; then
	set_var
	echo -n "the following songs exist in your ${TYPE} library: "
	show_library
elif [ -n "$PRIME" ] ; then
	set_var
	echo "the following songs exist in your PRIME ${PRIME}:"
	show_prime
elif [ -n "$ASIN" ] ; then
	set_var
	echo "playing PRIME playlist ${ASIN}"
	play_prime_playlist
elif [ -n "$SEEDID" ] ; then
	set_var
	echo "playing PRIME station ${SEEDID}"
	play_prime_station
elif [ -n "$HIST" ] ; then
	set_var
	echo "playing PRIME historical queue ${HIST}"
	play_prime_hist_queue
elif [ -n "$LASTALEXA" ] ; then
	last_alexa
else
	echo "no alexa command received"
fi

if [ -n "$LOGOFF" ] ; then
	echo "logout option present, logging off ..."
	log_off
fi
