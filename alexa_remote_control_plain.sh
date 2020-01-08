#!/bin/sh
#
# Amazon Alexa Remote Control (PLAIN shell)
#  alex(at)loetzimmer.de
#
# 2020-01-08: v0.15b (for updates see http://blog.loetzimmer.de/2017/10/amazon-alexa-hort-auf-die-shell-echo.html)
#
###
#
# (no BASHisms were used, should run with any shell)
# - requires cURL for web communication
# - (GNU) sed and awk for extraction
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

# Device specific volumes (overriding the above)
SET_DEVICEVOLNAME="EchoDot2ndGen  Echo1stGen"
SET_DEVICEVOLSPEAK="100 30"
SET_DEVICEVOLNORMAL="100 20"

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
DEVICEVOLNAME=${DEVICEVOLNAME:-$SET_DEVICEVOLNAME}
DEVICEVOLSPEAK=${DEVICEVOLSPEAK:-$SET_DEVICEVOLSPEAK}
DEVICEVOLNORMAL=${DEVICEVOLNORMAL:-$SET_DEVICEVOLNORMAL}

COOKIE="${TMP}/.alexa.cookie"
DEVLIST="${TMP}/.alexa.devicelist.json"
DEVTXT="${TMP}/.alexa.devicelist.txt"
DEVALL="${TMP}/.alexa.devicelist.all"

GUIVERSION=0

LIST=""
LOGOFF=""
COMMAND=""
TTS=""
SEQUENCECMD=""
SEQUENCEVAL=""
STATIONID=""
QUEUE=""
SONG=""
ALBUM=""
ARTIST=""
ASIN=""
SEEDID=""
HIST=""
LEMUR=""
CHILD=""
PLIST=""
BLUETOOTH=""
LASTALEXA=""
NOTIFICATIONS=""

usage()
{
	echo "$0 [-d <device>|ALL] -e <pause|play|next|prev|fwd|rwd|shuffle|repeat|vol:<0-100>> |"
	echo "          -b [list|<\"AA:BB:CC:DD:EE:FF\">] | -q | -n | -r <\"station name\"|stationid> |"
	echo "          -s <trackID|'Artist' 'Album'> | -t <ASIN> | -u <seedID> | -v <queueID> | -w <playlistId> |"
	echo "          -a | -m <multiroom_device> [device_1 .. device_X] | -lastalexa | -l | -h"
	echo
	echo "   -e : run command, additional SEQUENCECMDs:"
	echo "        weather,traffic,flashbriefing,goodmorning,singasong,tellstory,speak:'<text>'"
	echo "   -b : connect/disconnect/list bluetooth device"
	echo "   -q : query queue"
	echo "   -n : query notifications"
	echo "   -r : play tunein radio"
	echo "   -s : play library track/library album"
	echo "   -t : play Prime playlist"
	echo "   -u : play Prime station"
	echo "   -v : play Prime historical queue"
	echo "   -w : play library playlist"
	echo "   -a : list available devices"
	echo "   -m : delete multiroom and/or create new multiroom containing devices"
	echo "   -lastalexa : print serial number that received the last voice command"
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
		-d)
			if [ "${2#-}" != "${2}" -o -z "$2" ] ; then
				echo "ERROR: missing argument for ${1}"
				usage
				exit 1
			fi
			DEVICE=$2
			shift
			;;
		-l)
			LOGOFF="true"
			;;
		-a)
			LIST="true"
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
			TTS=",\\\"textToSpeak\\\":\\\"${TTS}\\\""
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
#	User-Agent	(CURL wouldn't store cookies without)
#
################################################################

rm -f ${DEVLIST}
rm -f ${DEVTXT}
rm -f ${DEVALL}
rm -f ${COOKIE}

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
 
	if [ ! -f ${DEVTXT} ] ; then
		cat ${DEVLIST}| sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' > ${DEVTXT}
	fi
	
	# create a file that contains valid device names for the "ALL" device
	ATTR="accountName"
	NAME=$(grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g')

	ATTR="deviceFamily"
	FAMILY=$(grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g')

	IDX=0
	for N in $NAME ; do
		C=0
		for F in $FAMILY ; do
			if [ $C -eq $IDX ] ; then
				if [ "$F" = "WHA" -o "$F" = "ECHO" -o "$F" = "KNIGHT" -o "$F" = "ROOK" ] ; then
					echo ${N} >> ${DEVALL}
				fi
				break
			fi
			C=$((C+1))
		done
		IDX=$((IDX+1))
	done
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
	ATTR="accountName"
	NAME=$(grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g')

	ATTR="deviceType"
	TYPE=$(grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g')

	ATTR="serialNumber"
	SERIAL=$(grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g')

#	ATTR="deviceOwnerCustomerId"
#	MEDIAID=`grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g')

	ATTR="deviceFamily"
	FAMILY=$(grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g')

	ATTR="online"
	ONLINE=$(grep ${ATTR}\: ${DEVTXT} | sed "s/^.*${ATTR}://")

	if [ -z "${DEVICE}" ] ; then
		# if no device was supplied, use the first Echo(dot) in device list
        IDX=0
		for F in $FAMILY ; do
			if [ "$F" = "ECHO" -o "$F" = "KNIGHT" -o "$F" = "ROOK" ] ; then
				break;
			fi
			IDX=$((IDX+1))
		done

		C=0
		for N in $NAME ; do
			if [ $C -eq $IDX ] ; then
				DEVICE=$N
				break
			fi
			C=$((C+1))
		done
		echo "setting default device to:"
		echo ${DEVICE}
	else
		DEVICE=`echo $DEVICE | sed 's/ /_/g'`
		IDX=0
		for N in $NAME ; do
			if [ "$N" = "$DEVICE" ] ; then
				break;
			fi
			IDX=$((IDX+1))
		done
	fi

# customerId is now retrieved from the logged in user
# the customerId in the device list is always from the user registering the device initially
#	C=0
#	for I in $MEDIAID ; do
#		if [ $C -eq $IDX ] ; then
#			MEDIAOWNERCUSTOMERID=$I
#			break
#		fi
#		C=$((C+1))
#	done

	C=0
	for T in $TYPE ; do
		if [ $C -eq $IDX ] ; then
			DEVICETYPE=$T
			break
		fi
		C=$((C+1))
	done

	C=0
	for S in $SERIAL ; do
		if [ $C -eq $IDX ] ; then
			DEVICESERIALNUMBER=$S
			break
		fi
		C=$((C+1))
	done

	C=0
	for F in $FAMILY ; do
		if [ $C -eq $IDX ] ; then
			DEVICEFAMILY=$F
			break
		fi
		C=$((C+1))
	done

	C=0
	for O in $ONLINE ; do
		if [ $C -eq $IDX ] ; then
			DEVICESTATE=$O
			break
		fi
		C=$((C+1))
	done

	if [ -z "${DEVICESERIALNUMBER}" ] ; then
		echo "ERROR: unkown device dev:${DEVICE}"
		exit 1
	fi
}

#
# execute command
# (SequenceCommands by Michael Geramb and Ralf Otto)
#
run_cmd()
{
if [ -n "${SEQUENCECMD}" ] ; then
	# the speak command is treated differently in that the wolume gets set to $SPEAKVOL
	if [ -n "${TTS}" ] ; then 
		if [ "${DEVICEFAMILY}" = "WHA" ] ; then
			echo "Skipping unsupported command: ${COMMAND} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} family:${DEVICEFAMILY}"
			return
		fi
		SVOL=$SPEAKVOL

		# Not using arrays here in order to be compatible with non-Bash
		# Get the list position of the current device type
		IDX=0
		for D in $DEVICEVOLNAME ; do
			if [ "${D}" = "${DEVICE}" ] ; then
				break;
			fi
			IDX=$((IDX+1))
		done

		# get the speak volume at that position
		C=0
		for D in $DEVICEVOLSPEAK ; do
			if [ $C -eq $IDX ] ; then
				if [ -n "${D}" ] ; then SVOL=$D ; fi 
				break
			fi
			C=$((C+1))
		done

		# try to retrieve the "currently playing" volume
		VOL=$(${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
		 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
		 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
		 "https://${ALEXA}/api/media/state?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}" | grep 'volume' | sed -r 's/^.*"volume":\s*([0-9]+)[^0-9]*$/\1/g')

		# in order to prevent a "Rate exceeded" we need to delay the command
		sleep 1

		if [ -z "${VOL}" ] ; then
			# get the normal volume of the current device type
			C=0
			for D in $DEVICEVOLNORMAL; do
				if [ $C -eq $IDX ] ; then
					VOL=$D
					break
				fi
				C=$((C+1))
			done
			# if the volume is still undefined, use $NORMALVOL
			if [ -z "${VOL}" ] ; then
				VOL=$NORMALVOL
			fi
		fi

		ALEXACMD='{"behaviorId":"PREVIEW","sequenceJson":"{\"@type\":\"com.amazon.alexa.behaviors.model.Sequence\",\"startNode\":{\"@type\":\"com.amazon.alexa.behaviors.model.SerialNode\",\"nodesToExecute\":[{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"Alexa.DeviceControls.Volume\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\",\"value\":\"'${SVOL}'\"}},{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"'${SEQUENCECMD}'\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\"'${TTS}'}},{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"Alexa.DeviceControls.Volume\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\",\"value\":\"'${VOL}'\"}}]}}","status":"ENABLED"}'
	else
		ALEXACMD='{"behaviorId":"PREVIEW","sequenceJson":"{\"@type\":\"com.amazon.alexa.behaviors.model.Sequence\",\"startNode\":{\"@type\":\"com.amazon.alexa.behaviors.model.OpaquePayloadOperationNode\",\"type\":\"'${SEQUENCECMD}'\",\"operationPayload\":{\"deviceType\":\"'${DEVICETYPE}'\",\"deviceSerialNumber\":\"'${DEVICESERIALNUMBER}'\",\"customerId\":\"'${MEDIAOWNERCUSTOMERID}'\",\"locale\":\"'${TTS_LOCALE}'\"'${SEQUENCEVAL}'}}}","status":"ENABLED"}'
	fi

	# Due to some weird shell-escape-behavior the command has to be written to a file before POSTing it
	echo $ALEXACMD > "${TMP}/.alexa.cmd"

	${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
	 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
	 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X POST -d @"${TMP}/.alexa.cmd"\
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
# current queue
#
show_queue()
{
	echo "/api/np/player"
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/np/player?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
	echo
	echo "/api/np/queue"
${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/np/queue?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
	echo
	echo "/api/media/state"
 ${CURL} ${OPTS} -s -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 -H "Content-Type: application/json; charset=UTF-8" -H "Referer: https://alexa.${AMAZON}/spa/index.html" -H "Origin: https://alexa.${AMAZON}"\
 -H "csrf: $(awk "\$0 ~/.${AMAZON}.*csrf[ \\s\\t]+/ {print \$7}" ${COOKIE})" -X GET \
 "https://${ALEXA}/api/media/state?deviceSerialNumber=${DEVICESERIALNUMBER}&deviceType=${DEVICETYPE}"
	echo
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
 "https://${ALEXA}/api/bluetooth?cached=false"
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
 "https://${ALEXA}/api/activities?startTime=&size=1&offset=1" | sed -r 's/^.*serialNumber":"([^"]+)".*$/\1/'
 }

#
# logout
#
log_off()
{
${CURL} ${OPTS} -s -c ${COOKIE} -b ${COOKIE} -A "${BROWSER}" -H "DNT: 1" -H "Connection: keep-alive" -L\
 https://${ALEXA}/logout > /dev/null

rm -f ${DEVLIST}
rm -f ${DEVTXT}
rm -f ${DEVALL}
rm -f ${COOKIE}
}

if [ -z "$LASTALEXA" -a -z "$BLUETOOTH" -a -z "$LEMUR" -a -z "$PLIST" -a -z "$HIST" -a -z "$SEEDID" -a -z "$ASIN" -a -z "$QUEUE" -a -z "$NOTIFICATIONS" -a -z "$COMMAND" -a -z "$STATIONID" -a -z "$SONG" -a -n "$LOGOFF" ] ; then
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

if [ ! -f ${DEVTXT} -o ! -f ${DEVALL} ] ; then
	echo "device list does not exist. downloading ..."
	get_devlist
	if [ ! -f ${DEVTXT} ] ; then
		echo "failed to download device list, aborting"
		exit 1
	fi
fi

if [ -n "$COMMAND" -o -n "$QUEUE" -o -n "$NOTIFICATIONS" ] ; then
	if [ "${DEVICE}" = "ALL" ] ; then
		while IFS= read -r DEVICE ; do
			set_var
			if [ "$DEVICESTATE" = "true" ] ; then
				if [ -n "$COMMAND" ] ; then
					echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
					run_cmd
					# in order to prevent a "Rate exceeded" we need to delay the command
					sleep 1
					echo
				elif [ -n "$NOTIFICATIONS" ] ; then
					echo "notifications info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
					show_notifications
				else
					echo "queue info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
					show_queue
					echo
				fi
			fi
		done < ${DEVALL}
	else
		set_var
		if [ -n "$COMMAND" ] ; then
			echo "sending cmd:${COMMAND} to dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} customerid:${MEDIAOWNERCUSTOMERID}"
			run_cmd
			echo
		elif [ -n "$NOTIFICATIONS" ] ; then
			echo "notifications info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
			show_notifications
		else
			echo "queue info for dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER}"
			show_queue
			echo
		fi
	fi
elif [ -n "$LEMUR" ] ; then
	DEVICE="${LEMUR}"
	set_var
	if [ -n "$DEVICESERIALNUMBER" ] ; then
		delete_multiroom
	fi
	if [ -z "$CHILD" ] ; then
		echo "Deleted multi room dev:${LEMUR} serial:${DEVICESERIALNUMBER}"
	else
		echo "Creating multi room dev:${LEMUR} member_dev(s):${CHILD}"
		create_multiroom
		echo
	fi
	rm -f ${DEVLIST}
	rm -f ${DEVALL}
	rm -f ${DEVTXT}
	get_devlist
elif [ -n "$BLUETOOTH" ] ; then
	if [ "$BLUETOOTH" = "list" -o "$BLUETOOTH" = "List" -o "$BLUETOOTH" = "LIST" ] ; then
		if [ "${DEVICE}" = "ALL" ] ; then
			while IFS= read -r DEVICE ; do
				set_var
				echo "bluetooth api list:"
				list_bluetooth
				echo
			done < ${DEVALL}
		else
			set_var
			echo "bluetooth api list:"
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
elif [ -n "$SONG" ] ; then
	set_var
	echo "playing library track:${SONG} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_song
elif [ -n "$PLIST" ] ; then
	set_var
	echo "playing library playlist:${PLIST} on dev:${DEVICE} type:${DEVICETYPE} serial:${DEVICESERIALNUMBER} mediaownerid:${MEDIAOWNERCUSTOMERID}"
	play_playlist
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
elif [ -n "$LIST" ] ; then
	ATTR="accountName"
	echo "the following devices exist in your account:"
	grep ${ATTR}\| ${DEVTXT} | sed "s/^.*${ATTR}|//" | sed 's/ /_/g'
elif [ -n "$LASTALEXA" ] ; then
	last_alexa
else
	echo "no alexa command received"
fi

if [ -n "$LOGOFF" ] ; then
	echo "logout option present, logging off ..."
	log_off
fi
